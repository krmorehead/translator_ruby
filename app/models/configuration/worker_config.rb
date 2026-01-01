# frozen_string_literal: true

module Configuration
  # Base configuration for all workers
  # Provides common configuration options that all workers need
  class WorkerConfig
    attr_reader :max_retries, :stream_progress, :error_mode, :dry_run

    def initialize(max_retries:, stream_progress:, error_mode:, dry_run:)
      raise ArgumentError, "max_retries must be positive" unless max_retries.positive?
      raise ArgumentError, "error_mode must be :lenient or :strict" unless [:lenient, :strict].include?(error_mode)

      @max_retries = max_retries
      @stream_progress = stream_progress
      @error_mode = error_mode
      @dry_run = dry_run
      freeze
    end

    def to_h
      {
        max_retries: @max_retries,
        stream_progress: @stream_progress,
        error_mode: @error_mode,
        dry_run: @dry_run
      }
    end
  end
end

