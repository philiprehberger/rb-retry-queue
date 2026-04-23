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
    # @param max_retries [Integer] maximum retry attempts per item. Note: `max_retries: 0`
    #   means one attempt with no retries (not zero attempts); the item is processed once
    #   and moves straight to the dead-letter list on failure.
    # @param concurrency [Integer] number of concurrent workers
    # @param backoff [Proc, nil] custom backoff strategy
    # @param retry_on [Array<Class>, nil] exception classes to retry on; others go straight to failed
    # @param on_retry [Array<Proc>, nil] callbacks fired before each retry attempt
    # @param on_failure [Proc, nil] callable invoked with `(item, error)` once per item that
    #   exhausts retries and moves to the dead-letter list; exceptions raised by the hook are
    #   swallowed so a faulty hook cannot break the queue
    # @param jitter [Numeric] fraction in `0.0..1.0` applied to the computed backoff delay as
    #   `delay * (1 + rand * jitter)` to reduce thundering-herd risk. Defaults to `0.0` (no jitter).
    # @yield [item] block that processes a single item
    # @return [Result] processing result
    def self.process(items, max_retries: 3, concurrency: 1, backoff: nil, retry_on: nil, on_retry: nil,
                     on_failure: nil, jitter: 0.0, &block)
      processor = Processor.new(
        max_retries: max_retries,
        concurrency: concurrency,
        backoff: backoff,
        retry_on: retry_on,
        on_retry: on_retry,
        on_failure: on_failure,
        jitter: jitter
      )
      processor.call(items, &block)
    end
  end
end
