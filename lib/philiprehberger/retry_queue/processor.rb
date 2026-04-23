# frozen_string_literal: true

module Philiprehberger
  module RetryQueue
    # Processes items with per-item retry, backoff, and dead letter collection.
    class Processor
      # Default backoff strategy: exponential with base 0.1s.
      DEFAULT_BACKOFF = ->(attempt) { 0.1 * (2**attempt) }

      # @param max_retries [Integer] maximum retry attempts per item. `max_retries: 0` means
      #   one attempt with no retries (not zero attempts).
      # @param concurrency [Integer] number of concurrent workers (reserved for future use)
      # @param backoff [Proc, nil] proc receiving attempt number, returns sleep duration
      # @param retry_on [Array<Class>, nil] exception classes to retry on; nil means retry all
      # @param on_retry [Array<Proc>, Proc, nil] callbacks fired before each retry attempt
      # @param on_failure [Proc, nil] callable invoked with `(item, error)` once per item that
      #   exhausts retries and moves to the dead-letter list; exceptions raised by the hook are
      #   swallowed so a faulty hook cannot break the queue
      # @param jitter [Numeric] fraction in `0.0..1.0` applied to the computed backoff delay as
      #   `delay * (1 + rand * jitter)`. Defaults to `0.0` (no jitter).
      def initialize(max_retries: 3, concurrency: 1, backoff: nil, retry_on: nil, on_retry: nil, on_failure: nil,
                     jitter: 0.0)
        raise Error, 'max_retries must be non-negative' unless max_retries.is_a?(Integer) && max_retries >= 0
        raise ArgumentError, 'jitter must be a Numeric in 0.0..1.0' unless valid_jitter?(jitter)

        @max_retries = max_retries
        @concurrency = concurrency
        @backoff = backoff || DEFAULT_BACKOFF
        @retry_on = retry_on
        @on_retry_hooks = Array(on_retry)
        @on_failure = on_failure
        @jitter = jitter.to_f
      end

      # Process a collection of items with retry logic.
      #
      # @param items [Array] items to process
      # @yield [item] block that processes a single item; raise to signal failure
      # @return [Result] processing result with succeeded, failed, and stats
      def call(items, &block)
        raise Error, 'a processing block is required' unless block

        succeeded = []
        failed = []
        start_time = now

        items.each do |item|
          process_item(item, succeeded, failed, &block)
        end

        Result.new(succeeded: succeeded, failed: failed, elapsed: now - start_time)
      end

      private

      def process_item(item, succeeded, failed, &block)
        attempts = 0

        loop do
          attempts += 1
          block.call(item)
          succeeded << item
          return
        rescue StandardError => e
          if !retryable?(e) || attempts > @max_retries
            failed << { item: item, error: e, attempts: attempts }
            fire_on_failure_hook(item, e)
            return
          end

          fire_on_retry_hooks(item, e, attempts)

          sleep_duration = apply_jitter(@backoff.call(attempts - 1))
          sleep(sleep_duration) if sleep_duration.positive?
        end
      end

      def apply_jitter(delay)
        return delay if @jitter.zero?

        delay * (1 + (rand * @jitter))
      end

      def valid_jitter?(jitter)
        jitter.is_a?(Numeric) && jitter >= 0.0 && jitter <= 1.0
      end

      def retryable?(error)
        return true if @retry_on.nil?

        @retry_on.any? { |klass| error.is_a?(klass) }
      end

      def fire_on_retry_hooks(item, error, attempt)
        @on_retry_hooks.each { |hook| hook.call(item, error, attempt) }
      end

      def fire_on_failure_hook(item, error)
        return if @on_failure.nil?

        @on_failure.call(item, error)
      rescue StandardError
        # Swallow hook errors — this is a best-effort notification and must never
        # break the queue. Intentionally silent; users can log inside their hook.
        nil
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
