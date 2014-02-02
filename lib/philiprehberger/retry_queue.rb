# frozen_string_literal: true

require_relative 'retry_queue/version'
require_relative 'retry_queue/result'
require_relative 'retry_queue/processor'

module Philiprehberger
  module RetryQueue
    class Error < StandardError; end

    # Process items with per-item retry, backoff, and dead letter collection.
    #
    # @param items [Array] items to process
    # @param max_retries [Integer] maximum retry attempts per item
    # @param concurrency [Integer] number of concurrent workers
    # @param backoff [Proc, nil] custom backoff strategy
    # @yield [item] block that processes a single item
    # @return [Result] processing result
    def self.process(items, max_retries: 3, concurrency: 1, backoff: nil, &block)
      processor = Processor.new(max_retries: max_retries, concurrency: concurrency, backoff: backoff)
      processor.call(items, &block)
    end
  end
end
