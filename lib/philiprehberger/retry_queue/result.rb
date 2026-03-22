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
    end
  end
end
