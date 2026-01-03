# frozen_string_literal: true

module Execution
  # Represents the complete record of a plan execution.
  # Aggregates all step results and provides execution summary.
  #
  # @example Creating an execution record
  #   record = Execution::ExecutionRecord.new(
  #     plan_id: "user_auth_plan",
  #     step_results: [result1, result2],
  #     started_at: Time.now.utc.iso8601,
  #     status: :running
  #   )
  #
  # @example With checkpoints
  #   record = Execution::ExecutionRecord.new(
  #     plan_id: "feature_plan",
  #     step_results: [],
  #     started_at: Time.now.utc.iso8601,
  #     status: :running,
  #     checkpoint_ids: ["abc123", "def456"]
  #   )
  class ExecutionRecord
    # Execution statuses
    STATUSES = [
      RUNNING = :running,
      COMPLETE = :complete,
      FAILED = :failed,
      PARTIAL = :partial
    ].freeze

    attr_reader :id, :plan_id, :step_results, :started_at, :status, :checkpoint_ids,
                :completed_at, :milestones_completed, :error, :metadata, :progress_events

    # @param plan_id [String] The execution plan identifier
    # @param step_results [Array<Execution::StepResult>] Array of step results
    # @param started_at [String] ISO8601 timestamp when execution started
    # @param status [Symbol] Current execution status (:running, :complete, :failed, :partial)
    # @param checkpoint_ids [Array<String>] Optional array of git commit hashes
    # @param completed_at [String, nil] Optional ISO8601 timestamp when execution completed
    # @param milestones_completed [Array<String>] Optional array of completed milestone IDs
    # @param error [String, nil] Optional error message if failed
    # @param metadata [Hash] Optional metadata hash
    # @param progress_events [Array<Hash>] Optional array of progress snapshots
    def initialize(plan_id:, step_results:, started_at:, status:,
                   checkpoint_ids: [], completed_at: nil, milestones_completed: [],
                   error: nil, metadata: {}, progress_events: [])
      validate_types!(plan_id, step_results, started_at, status, checkpoint_ids,
                      milestones_completed, metadata, progress_events)
      @id = SecureRandom.uuid
      @plan_id = plan_id
      @step_results = Array(step_results)
      @started_at = started_at
      @status = status
      @checkpoint_ids = Array(checkpoint_ids)
      @completed_at = completed_at
      @milestones_completed = Array(milestones_completed)
      @error = error
      @metadata = metadata
      @progress_events = Array(progress_events)
    end

    # Add a step result to the record
    # @param step_result [Execution::StepResult] The step result to add
    # @return [Execution::StepResult] The added step result
    def add_step_result(step_result)
      unless step_result.is_a?(StepResult)
        raise TypeError, "step_result must be an Execution::StepResult, got #{step_result.class}"
      end

      @step_results << step_result
      step_result
    end

    # Add a checkpoint ID
    # @param checkpoint_id [String] Git commit hash
    # @return [String] The added checkpoint ID
    def add_checkpoint(checkpoint_id)
      raise ArgumentError, "checkpoint_id must be a String" unless checkpoint_id.is_a?(String)
      raise ArgumentError, "checkpoint_id cannot be empty" if checkpoint_id.strip.empty?

      @checkpoint_ids << checkpoint_id
      checkpoint_id
    end

    # Add a progress event
    # @param event [Hash] Progress event data
    # @return [Hash] The added event
    def add_progress_event(event)
      raise ArgumentError, "event must be a Hash" unless event.is_a?(Hash)

      @progress_events << event
      event
    end

    # Mark a milestone as completed
    # @param milestone_id [String] The milestone identifier
    # @return [String] The milestone ID
    def mark_milestone_completed(milestone_id)
      raise ArgumentError, "milestone_id must be a String" unless milestone_id.is_a?(String)

      @milestones_completed << milestone_id unless @milestones_completed.include?(milestone_id)
      milestone_id
    end

    # Update the execution status
    # @param new_status [Symbol] The new status
    # @param completed_at [String, nil] Optional completion timestamp
    # @param error [String, nil] Optional error message
    def update_status(new_status, completed_at: nil, error: nil)
      unless STATUSES.include?(new_status)
        raise ArgumentError, "Invalid status: #{new_status}. Must be one of: #{STATUSES.join(', ')}"
      end

      @status = new_status
      @completed_at = completed_at if completed_at
      @error = error if error
    end

    # Get total number of steps
    # @return [Integer]
    def total_steps
      @step_results.size
    end

    # Get number of completed steps
    # @return [Integer]
    def completed_steps
      @step_results.count(&:successful?)
    end

    # Get number of failed steps
    # @return [Integer]
    def failed_steps
      @step_results.count(&:failed?)
    end

    # Get number of skipped steps (not yet implemented, returns 0)
    # @return [Integer]
    def skipped_steps
      0 # TODO: Implement when we add step skipping
    end

    # Calculate progress percentage
    # @return [Float] Progress from 0.0 to 100.0
    def progress_percentage
      return 0.0 if total_steps.zero?
      (completed_steps.to_f / total_steps * 100).round(2)
    end

    # Get milestone progress
    # @return [Hash] Map of milestone_id => completion status
    def milestone_progress
      @milestones_completed.each_with_object({}) do |milestone_id, hash|
        hash[milestone_id] = :completed
      end
    end

    # Get total number of files changed across all steps
    # @return [Integer]
    def total_files_changed
      @step_results.flat_map(&:files_changed).uniq.size
    end

    # Get all diffs aggregated from all steps
    # @return [Hash<String, Array<String>>] Map of file path to array of diffs
    def all_diffs
      result = Hash.new { |h, k| h[k] = [] }
      
      @step_results.each do |step_result|
        step_result.diffs.each do |file_path, diff|
          result[file_path] << diff
        end
      end

      result
    end

    # Calculate total execution duration
    # @return [Float, nil] Duration in seconds, or nil if not completed
    def duration
      return nil unless @completed_at

      start_time = Time.parse(@started_at)
      end_time = Time.parse(@completed_at)
      (end_time - start_time).to_f
    rescue ArgumentError
      nil
    end

    # Check if execution is running
    # @return [Boolean]
    def running?
      @status == RUNNING
    end

    # Check if execution is complete
    # @return [Boolean]
    def complete?
      @status == COMPLETE
    end

    # Check if execution failed
    # @return [Boolean]
    def failed?
      @status == FAILED
    end

    # Check if execution is partial (some steps succeeded, some failed)
    # @return [Boolean]
    def partial?
      @status == PARTIAL
    end

    # Serialize to hash (recursive with step_results)
    # @return [Hash] Hash representation
    def to_h
      {
        plan_id: @plan_id,
        step_results: @step_results.map(&:to_h),
        started_at: @started_at,
        status: @status,
        checkpoint_ids: @checkpoint_ids,
        completed_at: @completed_at,
        milestones_completed: @milestones_completed,
        error: @error,
        metadata: @metadata,
        progress_events: @progress_events
      }
    end

    # Reconstruct an ExecutionRecord from a hash
    # @param hash [Hash] Hash containing execution record data
    # @return [Execution::ExecutionRecord] Reconstructed execution record
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      # Reconstruct step results
      step_results_data = hash[:step_results] || hash["step_results"] || []
      step_results = step_results_data.map { |sr| StepResult.from_h(sr) }
      
      new(
        plan_id: hash[:plan_id] || hash["plan_id"],
        step_results: step_results,
        started_at: hash[:started_at] || hash["started_at"],
        status: (hash[:status] || hash["status"]).to_sym,
        checkpoint_ids: hash[:checkpoint_ids] || hash["checkpoint_ids"] || [],
        completed_at: hash[:completed_at] || hash["completed_at"],
        milestones_completed: hash[:milestones_completed] || hash["milestones_completed"] || [],
        error: hash[:error] || hash["error"],
        metadata: hash[:metadata] || hash["metadata"] || {},
        progress_events: hash[:progress_events] || hash["progress_events"] || []
      )
    end

    private

    def validate_types!(plan_id, step_results, started_at, status, checkpoint_ids,
                        milestones_completed, metadata, progress_events)
      raise ArgumentError, "plan_id must be a String, got #{plan_id.class}" unless plan_id.is_a?(String)
      raise ArgumentError, "plan_id cannot be empty" if plan_id.strip.empty?
      
      raise ArgumentError, "step_results must be an Array, got #{step_results.class}" unless step_results.is_a?(Array)
      
      # Validate step_results contains only StepResult instances
      if step_results.any? { |sr| !sr.is_a?(StepResult) }
        raise TypeError, "all step_results must be Execution::StepResult instances"
      end
      
      raise ArgumentError, "started_at must be a String, got #{started_at.class}" unless started_at.is_a?(String)
      raise ArgumentError, "started_at cannot be empty" if started_at.strip.empty?
      
      unless STATUSES.include?(status)
        raise ArgumentError, "Invalid status: #{status}. Must be one of: #{STATUSES.join(', ')}"
      end
      
      raise ArgumentError, "checkpoint_ids must be an Array, got #{checkpoint_ids.class}" unless checkpoint_ids.is_a?(Array)
      
      # Validate checkpoint_ids contains only strings
      if checkpoint_ids.any? { |id| !id.is_a?(String) }
        raise TypeError, "all checkpoint_ids must be Strings"
      end
      
      raise ArgumentError, "milestones_completed must be an Array, got #{milestones_completed.class}" unless milestones_completed.is_a?(Array)
      
      # Validate milestones_completed contains only strings
      if milestones_completed.any? { |id| !id.is_a?(String) }
        raise TypeError, "all milestones_completed must be Strings"
      end
      
      raise ArgumentError, "metadata must be a Hash, got #{metadata.class}" unless metadata.is_a?(Hash)
      raise ArgumentError, "progress_events must be an Array, got #{progress_events.class}" unless progress_events.is_a?(Array)
    end
  end
end


