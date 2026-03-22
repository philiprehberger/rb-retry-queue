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

  describe Philiprehberger::RetryQueue::Processor do
    it 'raises on negative max_retries' do
      expect { described_class.new(max_retries: -1) }
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
  end
end
