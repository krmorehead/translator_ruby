# frozen_string_literal: true

module Execution
  # Domain model representing the state of a Sisyphus execution.
  # Provides a snapshot of execution progress and status.
  #
  # Follows OOP patterns with strict validation.
  class ExecutionState
    STATUSES = [
      PENDING = :pending,
      RUNNING = :running,
      COMPLETE = :complete,
      FAILED = :failed
    ].freeze

    attr_reader :execution_id, :plan_path, :project_path, :status,
                :current_milestone, :current_step, :progress_percentage,
                :files_changed, :checkpoint_ids, :started_at, :completed_at,
                :error

    # Initialize an ExecutionState
    # @param execution_id [String] Unique execution identifier
    # @param plan_path [String] Path to the execution plan
    # @param project_path [String] Path to the project/codebase
    # @param status [Symbol] Current status (:pending, :running, :complete, :failed)
    # @param current_milestone [String, nil] Current milestone title
    # @param current_step [String, nil] Current step title
    # @param progress_percentage [Float] Progress (0-100)
    # @param files_changed [Array<String>] Array of changed file paths
    # @param checkpoint_ids [Array<String>] Array of git checkpoint IDs
    # @param started_at [String] ISO8601 timestamp
    # @param completed_at [String, nil] ISO8601 timestamp or nil
    # @param error [String, nil] Error message or nil
    def initialize(execution_id:, plan_path:, project_path:, status:,
                   current_milestone: nil, current_step: nil,
                   progress_percentage: 0.0, files_changed: [],
                   checkpoint_ids: [], started_at:, completed_at: nil,
                   error: nil)
      validate_params!(execution_id, plan_path, project_path, status,
                       progress_percentage, files_changed, checkpoint_ids,
                       started_at)

      @execution_id = execution_id
      @plan_path = plan_path
      @project_path = project_path
      @status = status
      @current_milestone = current_milestone
      @current_step = current_step
      @progress_percentage = progress_percentage
      @files_changed = files_changed
      @checkpoint_ids = checkpoint_ids
      @started_at = started_at
      @completed_at = completed_at
      @error = error
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

    # Check if execution is pending
    # @return [Boolean]
    def pending?
      @status == PENDING
    end

    # Serialize to hash
    # @return [Hash]
    def to_h
      {
        execution_id: @execution_id,
        plan_path: @plan_path,
        project_path: @project_path,
        status: @status,
        current_milestone: @current_milestone,
        current_step: @current_step,
        progress_percentage: @progress_percentage,
        files_changed: @files_changed,
        checkpoint_ids: @checkpoint_ids,
        started_at: @started_at,
        completed_at: @completed_at,
        error: @error
      }
    end

    # Deserialize from hash
    # @param hash [Hash]
    # @return [ExecutionState]
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash" unless hash.is_a?(Hash)

      symbolized = hash.deep_symbolize_keys

      # Convert status to symbol if string
      status = symbolized[:status]
      status = status.to_sym if status.is_a?(String)

      new(
        execution_id: symbolized[:execution_id],
        plan_path: symbolized[:plan_path],
        project_path: symbolized[:project_path],
        status: status,
        current_milestone: symbolized[:current_milestone],
        current_step: symbolized[:current_step],
        progress_percentage: symbolized[:progress_percentage] || 0.0,
        files_changed: symbolized[:files_changed] || [],
        checkpoint_ids: symbolized[:checkpoint_ids] || [],
        started_at: symbolized[:started_at],
        completed_at: symbolized[:completed_at],
        error: symbolized[:error]
      )
    end

    private

    def validate_params!(execution_id, plan_path, project_path, status,
                         progress_percentage, files_changed, checkpoint_ids,
                         started_at)
      # Validate execution_id
      raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
      raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?

      # Validate plan_path
      raise ArgumentError, "plan_path must be a String" unless plan_path.is_a?(String)
      raise ArgumentError, "plan_path cannot be empty" if plan_path.strip.empty?

      # Validate project_path
      raise ArgumentError, "project_path must be a String" unless project_path.is_a?(String)
      raise ArgumentError, "project_path cannot be empty" if project_path.strip.empty?

      # Validate status
      raise ArgumentError, "status must be a Symbol" unless status.is_a?(Symbol)
      unless STATUSES.include?(status)
        raise ArgumentError, "Invalid status: #{status}. Must be one of: #{STATUSES.join(', ')}"
      end

      # Validate progress_percentage
      unless progress_percentage.is_a?(Numeric)
        raise ArgumentError, "progress_percentage must be Numeric"
      end
      unless progress_percentage.between?(0, 100)
        raise ArgumentError, "progress_percentage must be between 0 and 100"
      end

      # Validate files_changed
      raise ArgumentError, "files_changed must be an Array" unless files_changed.is_a?(Array)

      # Validate checkpoint_ids
      raise ArgumentError, "checkpoint_ids must be an Array" unless checkpoint_ids.is_a?(Array)

      # Validate started_at
      raise ArgumentError, "started_at must be a String" unless started_at.is_a?(String)
      raise ArgumentError, "started_at cannot be empty" if started_at.strip.empty?
    end
  end
end


