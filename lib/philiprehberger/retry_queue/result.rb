# frozen_string_literal: true

module Philiprehberger
  module RetryQueue
    # Holds the outcome of a batch processing run.
    class Result
      # @return [Array] items that were processed successfully
      attr_reader :succeeded

      # @return [Array<Hash>] items that exhausted retries, each with :item, :error, :attempts
      attr_reader :failed

      # @param succeeded [Array] successfully processed items
      # @param failed [Array<Hash>] items that failed after all retries
      # @param elapsed [Float] total processing time in seconds
      def initialize(succeeded:, failed:, elapsed:)
        @succeeded = succeeded
        @failed = failed
        @elapsed = elapsed
      end

      # Return processing statistics.
      #
      # @return [Hash] stats including counts, success rate, and elapsed time
      def stats
        total = @succeeded.size + @failed.size
        {
          total: total,
          succeeded: @succeeded.size,
          failed: @failed.size,
          success_rate: total.zero? ? 0.0 : @succeeded.size.to_f / total,
          elapsed: @elapsed
        }
      end

      # Reprocess failed items by yielding each item and its last error to the block.
      # Returns a new Result with the reprocessing outcomes.
      #
      # @yield [item, error] block that reprocesses a failed item
      # @return [Result] new result with reprocessing outcomes
      def reprocess_failed(&block)
        raise Error, 'a reprocessing block is required' unless block

        reprocess_succeeded = []
        reprocess_failed = []
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        @failed.each do |entry|
          block.call(entry[:item], entry[:error])
          reprocess_succeeded << entry[:item]
        rescue StandardError => e
          reprocess_failed << { item: entry[:item], error: e, attempts: 1 }
        end

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        Result.new(succeeded: reprocess_succeeded, failed: reprocess_failed, elapsed: elapsed)
      end
    end
  end
end
