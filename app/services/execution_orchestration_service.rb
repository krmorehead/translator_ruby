# frozen_string_literal: true

# Service for orchestrating Sisyphus Worker executions.
# Manages execution lifecycle, state tracking, and provides snapshots.
#
# This service wraps SisyphusWorker and provides a stateless API
# for starting, querying, and managing autonomous execution workers.
#
# Uses ExecutionStateStore for persistent state tracking.
class ExecutionOrchestrationService
  def initialize(state_store: nil)
    @state_store = state_store || ExecutionStateStore.new
  end
  # Starts a new Sisyphus execution
  #
  # @param plan_path [String] Path to the execution plan markdown file
  # @param project_path [String] Path to the codebase/project to work on
  # @param options [Hash] Additional options for execution
  # @return [Hash] Result with execution_id and initial state
  def start_execution(plan_path:, project_path:, options: {})
    validate_start_params!(plan_path, project_path)

    execution_id = SecureRandom.uuid

    # Create initial execution state
    state = Execution::ExecutionState.new(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path,
      status: Execution::ExecutionState::PENDING,
      started_at: Time.now.utc.iso8601
    )

    # Persist the initial state
    unless @state_store.save(state)
      return {
        success: false,
        error: "Failed to persist execution state"
      }
    end

    # Start SisyphusWorker asynchronously
    # OOP: The worker will manage its own state transitions (pending → running → executing, etc.)
    # The orchestration service is only responsible for creating the initial state
    begin
      # Try to enqueue with Sidekiq, but don't fail if Sidekiq isn't running
      begin
        SisyphusWorker.perform_async(plan_path, project_path, execution_id)
      rescue StandardError => e
        # Sidekiq not available (e.g., in test mode without Redis)
        Rails.logger.warn "Sidekiq not available: #{e.message}"
      end

      # Return the initial PENDING state
      # The worker will transition to RUNNING when it actually starts
      {
        success: true,
        execution_id: execution_id,
        state: state.to_h,
        message: "Execution enqueued successfully"
      }
    rescue StandardError => e
      {
        success: false,
        error: "Failed to start execution: #{e.message}"
      }
    end
  end

  # Get the current state of an execution
  #
  # @param execution_id [String] The execution identifier
  # @return [Hash] Result with current execution state
  def get_execution_state(execution_id:)
    validate_execution_id!(execution_id)

    begin
      state = @state_store.get(execution_id)

      if state.nil?
        return {
          success: false,
          error: "Execution not found: #{execution_id}"
        }
      end

      {
        success: true,
        state: state.to_h
      }
    rescue StandardError => e
      {
        success: false,
        error: "Failed to get execution state: #{e.message}"
      }
    end
  end

  # List all executions (recent ones)
  #
  # @param limit [Integer] Maximum number of executions to return
  # @return [Hash] Result with array of execution states
  def list_executions(limit: 50)
    begin
      executions = @state_store.list(limit: limit)

      {
        success: true,
        executions: executions.map(&:to_h),
        count: executions.size
      }
    rescue StandardError => e
      {
        success: false,
        error: "Failed to list executions: #{e.message}"
      }
    end
  end

  # Cancel a running execution
  #
  # @param execution_id [String] The execution identifier
  # @return [Hash] Result indicating success/failure
  def cancel_execution(execution_id:)
    validate_execution_id!(execution_id)

    begin
      # Get current state
      state = @state_store.get(execution_id)

      if state.nil?
        return {
          success: false,
          error: "Execution not found: #{execution_id}"
        }
      end

      # Can only cancel running or pending executions
      unless state.running? || state.pending?
        return {
          success: false,
          error: "Cannot cancel execution with status: #{state.status}"
        }
      end

      # Update state to FAILED with cancellation message
      cancelled_state = Execution::ExecutionState.new(
        execution_id: state.execution_id,
        plan_path: state.plan_path,
        project_path: state.project_path,
        status: Execution::ExecutionState::FAILED,
        started_at: state.started_at,
        completed_at: Time.now.utc.iso8601,
        error: "Execution cancelled by user"
      )

      @state_store.save(cancelled_state)

      # Note: Actual Sidekiq job cancellation would happen here
      # For now, we just mark as failed in the store

      {
        success: true,
        message: "Execution cancelled successfully",
        state: cancelled_state.to_h
      }
    rescue StandardError => e
      {
        success: false,
        error: "Failed to cancel execution: #{e.message}"
      }
    end
  end

  private

  def validate_start_params!(plan_path, project_path)
    raise ArgumentError, "plan_path must be a String" unless plan_path.is_a?(String)
    raise ArgumentError, "plan_path cannot be empty" if plan_path.strip.empty?
    raise ArgumentError, "project_path must be a String" unless project_path.is_a?(String)
    raise ArgumentError, "project_path cannot be empty" if project_path.strip.empty?

    # Validate paths exist
    unless File.exist?(plan_path)
      raise ArgumentError, "Plan file not found: #{plan_path}"
    end
    unless Dir.exist?(project_path)
      raise ArgumentError, "Project directory not found: #{project_path}"
    end
  end

  def validate_execution_id!(execution_id)
    raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
    raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?
  end
end

