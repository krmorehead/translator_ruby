# frozen_string_literal: true

# Service for managing approval gates in worker executions.
# Handles creating approval requests and waiting for approval/rejection.
#
# IMPORTANT: Approvals wait FOREVER until resolved by the user.
# There are NO TIMEOUTS. The system does not auto-resolve approvals.
# This prevents masking real issues and ensures human oversight.
#
# This service can be used by any worker that supports approval modes.
# It integrates with ApprovalRequestStore and ExecutionProgressBroadcaster.
class ApprovalGateService
  def initialize(approval_store: nil, broadcaster: nil)
    @approval_store = approval_store || ApprovalRequestStore.new
    @broadcaster = broadcaster || ExecutionProgressBroadcaster.new
  end

  # Request approval for a step
  #
  # @param execution_id [String] The execution identifier
  # @param step [Planning::Step] The step requiring approval
  # @param planned_actions [Array<Hash>] Array of planned tool calls
  # @param estimated_changes [Hash] Estimated file changes
  # @return [Execution::ApprovalRequest] The approval request
  def request_step_approval(execution_id:, step:, planned_actions: [], estimated_changes: {})
    request = Execution::ApprovalRequest.new(
      id: SecureRandom.uuid,
      execution_id: execution_id,
      type: :step,
      status: :pending,
      subject_id: step.id,
      subject_title: step.title,
      planned_actions: planned_actions,
      estimated_changes: estimated_changes,
      created_at: Time.now.utc.iso8601
    )

    # Save the request
    @approval_store.save(request)

    # Broadcast approval required event
    @broadcaster.broadcast(
      execution_id: execution_id,
      event_type: :approval_required,
      data: {
        approval_id: request.id,
        type: :step,
        subject_title: step.title,
        planned_actions: planned_actions,
        estimated_changes: estimated_changes
      }
    )

    request
  end

  # Request approval for a milestone
  #
  # @param execution_id [String] The execution identifier
  # @param milestone [Planning::Milestone] The milestone requiring approval
  # @param planned_actions [Array<Hash>] Array of planned actions
  # @param estimated_changes [Hash] Estimated file changes
  # @return [Execution::ApprovalRequest] The approval request
  def request_milestone_approval(execution_id:, milestone:, planned_actions: [], estimated_changes: {})
    request = Execution::ApprovalRequest.new(
      id: SecureRandom.uuid,
      execution_id: execution_id,
      type: :milestone,
      status: :pending,
      subject_id: milestone.id,
      subject_title: milestone.title,
      planned_actions: planned_actions,
      estimated_changes: estimated_changes,
      created_at: Time.now.utc.iso8601
    )

    # Save the request
    @approval_store.save(request)

    # Broadcast approval required event
    @broadcaster.broadcast(
      execution_id: execution_id,
      event_type: :approval_required,
      data: {
        approval_id: request.id,
        type: :milestone,
        subject_title: milestone.title,
        planned_actions: planned_actions,
        estimated_changes: estimated_changes
      }
    )

    request
  end

  # Wait for approval and return the result
  # IMPORTANT: This waits FOREVER until the user resolves the approval.
  # There are NO TIMEOUTS. The only outcomes are :approved or :rejected.
  #
  # @param request_id [String] The approval request identifier
  # @return [Symbol] :approved or :rejected (never :timeout)
  def wait_for_approval(request_id)
    resolved_request = @approval_store.wait_for_resolution(request_id)

    # Request was deleted (execution cancelled, etc.)
    # Treat as rejection since user action was not "approve"
    return :rejected if resolved_request.nil?

    return :rejected if resolved_request.rejected?
    return :approved if resolved_request.approved?

    # Should never happen - all resolved requests are either approved or rejected
    :rejected
  end

  # Check if approval is required based on config and type
  #
  # @param approval_mode [Symbol] The approval mode (:autonomous, :step, :milestone)
  # @param type [Symbol] The type being checked (:step, :milestone)
  # @return [Boolean] true if approval is required
  def approval_required?(approval_mode:, type:)
    case approval_mode
    when :autonomous
      false
    when :step
      type == :step
    when :milestone
      type == :milestone
    else
      false
    end
  end

  # Request and wait for approval (convenience method)
  # IMPORTANT: This waits FOREVER until the user resolves the approval.
  #
  # @param execution_id [String] The execution identifier
  # @param type [Symbol] Type of approval (:step, :milestone)
  # @param subject [Planning::Step, Planning::Milestone] The subject requiring approval
  # @param planned_actions [Array<Hash>] Planned actions
  # @param estimated_changes [Hash] Estimated changes
  # @return [Symbol] :approved or :rejected (never :timeout)
  def request_and_wait(execution_id:, type:, subject:, planned_actions: [], estimated_changes: {})
    # Create the request based on type
    request = case type
    when :step
      request_step_approval(
        execution_id: execution_id,
        step: subject,
        planned_actions: planned_actions,
        estimated_changes: estimated_changes
      )
    when :milestone
      request_milestone_approval(
        execution_id: execution_id,
        milestone: subject,
        planned_actions: planned_actions,
        estimated_changes: estimated_changes
      )
    else
      raise ArgumentError, "Invalid approval type: #{type}"
    end

    # Wait for resolution (waits forever)
    result = wait_for_approval(request.id)

    # Broadcast result
    @broadcaster.broadcast(
      execution_id: execution_id,
      event_type: "approval_#{result}".to_sym,
      data: {
        approval_id: request.id,
        type: type,
        subject_title: subject.title,
        result: result
      }
    )

    result
  end
end
