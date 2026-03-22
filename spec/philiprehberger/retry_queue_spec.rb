# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::RetryQueue do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::RetryQueue::VERSION).not_to be_nil
    end
  end

  describe '.process' do
    it 'processes all items successfully' do
      results = []
      result = described_class.process([1, 2, 3]) { |item| results << item }

      expect(results).to eq([1, 2, 3])
      expect(result.succeeded).to eq([1, 2, 3])
      expect(result.failed).to be_empty
    end

    it 'retries failed items' do
      attempts = Hash.new(0)
      result = described_class.process(%w[a b], max_retries: 2, backoff: ->(_) { 0 }) do |item|
        attempts[item] += 1
        raise 'fail' if item == 'b' && attempts[item] < 2
      end

      expect(result.succeeded).to eq(%w[a b])
      expect(result.failed).to be_empty
    end

    it 'collects items that exhaust retries into failed' do
      result = described_class.process(%w[ok fail], max_retries: 1, backoff: ->(_) { 0 }) do |item|
        raise 'boom' if item == 'fail'
      end

      expect(result.succeeded).to eq(['ok'])
      expect(result.failed.size).to eq(1)
      expect(result.failed.first[:item]).to eq('fail')
      expect(result.failed.first[:error]).to be_a(RuntimeError)
      expect(result.failed.first[:attempts]).to eq(2)
    end

    it 'raises when no block is given' do
      expect { described_class.process([1, 2]) }
        .to raise_error(Philiprehberger::RetryQueue::Error, /block/)
    end

    it 'handles empty items' do
      result = described_class.process([]) { |item| item }
      expect(result.succeeded).to be_empty
      expect(result.failed).to be_empty
    end

    it 'uses custom backoff' do
      sleeps = []
      allow_any_instance_of(Philiprehberger::RetryQueue::Processor).to receive(:sleep) { |_, d| sleeps << d }

      described_class.process(['x'], max_retries: 3, backoff: ->(n) { n * 0.5 }) do |_item|
        raise 'fail'
      end

      expect(sleeps).to eq([0.5, 1.0])
    end
  end

  describe '#stats' do
    it 'returns processing statistics' do
      result = described_class.process(%w[a b c], max_retries: 0, backoff: ->(_) { 0 }) do |item|
        raise 'fail' if item == 'c'
      end

      stats = result.stats
      expect(stats[:total]).to eq(3)
      expect(stats[:succeeded]).to eq(2)
      expect(stats[:failed]).to eq(1)
      expect(stats[:success_rate]).to be_within(0.01).of(0.67)
      expect(stats[:elapsed]).to be_a(Float)
    end

    it 'handles all succeeded' do
      result = described_class.process([1, 2]) { |_| nil }
      expect(result.stats[:success_rate]).to eq(1.0)
    end

    it 'handles empty input' do
      result = described_class.process([]) { |_| nil }
      expect(result.stats[:success_rate]).to eq(0.0)
    end
  end

  describe 'edge cases' do
    it 'processes a single item successfully' do
      result = described_class.process(['only'], backoff: ->(_) { 0 }) { |_| nil }
      expect(result.succeeded).to eq(['only'])
      expect(result.failed).to be_empty
    end

    it 'handles a single item that always fails' do
      result = described_class.process(['bad'], max_retries: 2, backoff: ->(_) { 0 }) do |_|
        raise 'always fails'
      end
      expect(result.succeeded).to be_empty
      expect(result.failed.size).to eq(1)
      expect(result.failed.first[:item]).to eq('bad')
    end

    it 'succeeds all items when none raise' do
      items = (1..10).to_a
      result = described_class.process(items, backoff: ->(_) { 0 }) { |_| nil }
      expect(result.succeeded).to eq(items)
      expect(result.failed).to be_empty
      expect(result.stats[:success_rate]).to eq(1.0)
    end

    it 'fails all items when all raise' do
      items = %w[a b c]
      result = described_class.process(items, max_retries: 0, backoff: ->(_) { 0 }) do |_|
        raise 'nope'
      end
      expect(result.succeeded).to be_empty
      expect(result.failed.size).to eq(3)
      expect(result.stats[:success_rate]).to eq(0.0)
    end

    it 'records correct attempt count when max_retries is reached' do
      result = described_class.process(['x'], max_retries: 5, backoff: ->(_) { 0 }) do |_|
        raise 'fail'
      end
      expect(result.failed.first[:attempts]).to eq(6) # 1 initial + 5 retries
    end

    it 'uses default exponential backoff values' do
      sleeps = []
      allow_any_instance_of(Philiprehberger::RetryQueue::Processor).to receive(:sleep) { |_, d| sleeps << d }

      described_class.process(['x'], max_retries: 3) { |_| raise 'fail' }

      # Default backoff: 0.1 * 2^0, 0.1 * 2^1, 0.1 * 2^2
      expect(sleeps).to eq([0.1, 0.2, 0.4])
    end

    it 'handles custom error types' do
      custom_error = Class.new(StandardError)
      result = described_class.process(['x'], max_retries: 1, backoff: ->(_) { 0 }) do |_|
        raise custom_error, 'custom'
      end
      expect(result.failed.first[:error]).to be_a(custom_error)
    end

    it 'collects dead letter items with error details' do
      result = described_class.process(%w[a b], max_retries: 0, backoff: ->(_) { 0 }) do |item|
        raise "error-#{item}"
      end

      expect(result.failed.size).to eq(2)
      expect(result.failed[0][:error].message).to eq('error-a')
      expect(result.failed[1][:error].message).to eq('error-b')
    end

    it 'reports elapsed time in stats' do
      result = described_class.process([1], backoff: ->(_) { 0 }) { |_| nil }
      expect(result.stats[:elapsed]).to be_a(Float)
      expect(result.stats[:elapsed]).to be >= 0
    end

    it 'retries only failing items, not successful ones' do
      call_counts = Hash.new(0)
      result = described_class.process(%w[ok fail], max_retries: 2, backoff: ->(_) { 0 }) do |item|
        call_counts[item] += 1
        raise 'boom' if item == 'fail'
      end

      expect(call_counts['ok']).to eq(1)
      expect(call_counts['fail']).to eq(3) # 1 initial + 2 retries
      expect(result.succeeded).to eq(['ok'])
    end

    it 'succeeds on last retry attempt' do
      attempts = Hash.new(0)
      result = described_class.process(['x'], max_retries: 3, backoff: ->(_) { 0 }) do |item|
        attempts[item] += 1
        raise 'not yet' if attempts[item] <= 3
      end
      expect(result.succeeded).to eq(['x'])
      expect(result.failed).to be_empty
    end

    it 'preserves item order in succeeded list' do
      result = described_class.process(%w[c a b], backoff: ->(_) { 0 }) { |_| nil }
      expect(result.succeeded).to eq(%w[c a b])
    end

    it 'handles zero max_retries (no retries)' do
      attempts = 0
      result = described_class.process(['x'], max_retries: 0, backoff: ->(_) { 0 }) do |_|
        attempts += 1
        raise 'fail'
      end
      expect(attempts).to eq(1)
      expect(result.failed.size).to eq(1)
    end

    it 'skips backoff sleep when duration is zero' do
      sleeps = []
      allow_any_instance_of(Philiprehberger::RetryQueue::Processor).to receive(:sleep) { |_, d| sleeps << d }

      described_class.process(['x'], max_retries: 2, backoff: ->(_) { 0 }) { |_| raise 'fail' }

      expect(sleeps).to be_empty
    end

    it 'processes large batch correctly' do
      items = (1..50).to_a
      result = described_class.process(items, backoff: ->(_) { 0 }) { |_| nil }
      expect(result.succeeded.size).to eq(50)
      expect(result.stats[:total]).to eq(50)
    end

    it 'handles mixed success and failure in large batch' do
      result = described_class.process((1..10).to_a, max_retries: 0, backoff: ->(_) { 0 }) do |item|
        raise 'even fails' if item.even?
      end
      expect(result.succeeded).to eq([1, 3, 5, 7, 9])
      expect(result.failed.size).to eq(5)
    end
  end

  describe Philiprehberger::RetryQueue::Result do
    it 'returns correct stats for mixed results' do
      result = described_class.new(
        succeeded: %w[a b],
        failed: [{ item: 'c', error: RuntimeError.new, attempts: 3 }],
        elapsed: 1.5
      )
      expect(result.stats).to eq({
        total: 3,
        succeeded: 2,
        failed: 1,
        success_rate: 2.0 / 3,
        elapsed: 1.5
      })
    end
  end

  describe Philiprehberger::RetryQueue::Processor do
    it 'raises on negative max_retries' do
      expect { described_class.new(max_retries: -1) }
        .to raise_error(Philiprehberger::RetryQueue::Error)
    end

    it 'raises on non-integer max_retries' do
      expect { described_class.new(max_retries: 1.5) }
        .to raise_error(Philiprehberger::RetryQueue::Error)
    end

    it 'defaults to 3 max retries' do
      attempts = 0
      processor = described_class.new(backoff: ->(_) { 0 })
      result = processor.call(['x']) do |_|
        attempts += 1
        raise 'fail'
      end

      expect(attempts).to eq(4) # 1 initial + 3 retries
      expect(result.failed.size).to eq(1)
    end

    it 'allows zero max_retries' do
      expect { described_class.new(max_retries: 0, backoff: ->(_) { 0 }) }.not_to raise_error
    end
  end
end
