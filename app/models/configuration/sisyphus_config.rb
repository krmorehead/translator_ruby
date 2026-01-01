# frozen_string_literal: true

module Configuration
  # Configuration specific to SisyphusWorker
  # Extends WorkerConfig with approval mode settings
  class SisyphusConfig < WorkerConfig
    attr_reader :approval_mode

    # Approval modes for Sisyphus execution
    APPROVAL_MODES = [
      AUTONOMOUS = :autonomous,    # No approvals required (default)
      STEP = :step,               # Approve each step
      MILESTONE = :milestone      # Approve each milestone
    ].freeze

    def initialize(approval_mode:, max_retries:, stream_progress:, error_mode:, dry_run:)
      raise ArgumentError, "approval_mode must be one of #{APPROVAL_MODES}" unless APPROVAL_MODES.include?(approval_mode)
      
      @approval_mode = approval_mode
      
      super(
        max_retries: max_retries,
        stream_progress: stream_progress,
        error_mode: error_mode,
        dry_run: dry_run
      )
    end

    def to_h
      {
        **super,
        approval_mode: @approval_mode
      }
    end
  end
end

