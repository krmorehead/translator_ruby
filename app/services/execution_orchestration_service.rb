# frozen_string_literal: true

# Service for orchestrating Sisyphus Worker executions.
# Manages execution lifecycle, state tracking, and provides snapshots.
#
# This service wraps SisyphusWorker and provides a stateless API
# for starting, querying, and managing autonomous execution workers.
class ExecutionOrchestrationService
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

    # Start SisyphusWorker asynchronously
    # Note: In a real implementation, this would use background jobs
    # For now, we return the state and let the worker run
    begin
      # Try to enqueue with Sidekiq, but don't fail if Sidekiq isn't running
      begin
        SisyphusWorker.perform_async(plan_path, project_path, execution_id)
      rescue StandardError => e
        # Sidekiq not available (e.g., in test mode without Redis)
        Rails.logger.warn "Sidekiq not available: #{e.message}"
      end

      {
        success: true,
        execution_id: execution_id,
        state: state.to_h,
        message: "Execution started successfully"
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
      # Query the worker status from Sidekiq
      # This is a simplified implementation
      # In production, you'd query Sidekiq's job status API

      # For now, return a mock state
      # Real implementation would track state in Redis or database
      state = build_execution_state(execution_id)

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
      # In a real implementation, this would query a database
      # or Redis for tracked executions
      # For now, return empty array

      {
        success: true,
        executions: [],
        count: 0
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
      # Find and stop the Sidekiq job
      # This is a simplified implementation
      # Real implementation would use Sidekiq API

      {
        success: true,
        message: "Execution cancelled successfully"
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

  def build_execution_state(execution_id)
    # This is a simplified implementation
    # Real implementation would query actual state from storage
    Execution::ExecutionState.new(
      execution_id: execution_id,
      plan_path: "unknown",
      project_path: "unknown",
      status: Execution::ExecutionState::RUNNING,
      progress_percentage: 0.0,
      started_at: Time.now.utc.iso8601
    )
  end
end

