# frozen_string_literal: true

module Philiprehberger
  module RetryQueue
    # Processes items with per-item retry, backoff, and dead letter collection.
    class Processor
      # Default backoff strategy: exponential with base 0.1s.
      DEFAULT_BACKOFF = ->(attempt) { 0.1 * (2**attempt) }

      # @param max_retries [Integer] maximum retry attempts per item
      # @param concurrency [Integer] number of concurrent workers (reserved for future use)
      # @param backoff [Proc, nil] proc receiving attempt number, returns sleep duration
      def initialize(max_retries: 3, concurrency: 1, backoff: nil)
        raise Error, 'max_retries must be non-negative' unless max_retries.is_a?(Integer) && max_retries >= 0

        @max_retries = max_retries
        @concurrency = concurrency
        @backoff = backoff || DEFAULT_BACKOFF
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
          if attempts > @max_retries
            failed << { item: item, error: e, attempts: attempts }
            return
          end

          sleep_duration = @backoff.call(attempts - 1)
          sleep(sleep_duration) if sleep_duration.positive?
        end
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
