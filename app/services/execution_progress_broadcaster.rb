# frozen_string_literal: true

# Service for broadcasting worker execution progress events.
# Uses in-memory pub/sub to enable real-time updates to connected clients.
#
# This is a general-purpose broadcaster that can be used by any worker
# (SisyphusWorker, DaedalusWorker, ProjectPlannerWorker, etc.) to publish
# progress events, which are then consumed by SSE (Server-Sent Events)
# endpoints in controllers.
#
# Follows OOP patterns with strict validation.
class ExecutionProgressBroadcaster
  # Channel prefix for execution events
  CHANNEL_PREFIX = "worker:progress:"

  # Event types
  # NOTE: There is NO approval_timeout event - approvals wait forever
  EVENT_TYPES = %i[
    started
    milestone_started
    milestone_completed
    step_started
    step_completed
    step_failed
    file_changed
    checkpoint_created
    completed
    failed
    cancelled
    approval_required
    approval_approved
    approval_rejected
  ].freeze

  # In-memory subscribers (class-level for sharing across instances)
  @subscribers = {}
  @mutex = Mutex.new

  class << self
    attr_reader :subscribers, :mutex

    def add_subscriber(channel, callback)
      @mutex.synchronize do
        @subscribers[channel] ||= []
        @subscribers[channel] << callback
      end
    end

    def remove_subscriber(channel, callback)
      @mutex.synchronize do
        @subscribers[channel]&.delete(callback)
      end
    end

    def publish(channel, message)
      callbacks = @mutex.synchronize { @subscribers[channel]&.dup || [] }
      callbacks.each { |cb| cb.call(message) }
      callbacks.size
    end

    def clear_subscribers
      @mutex.synchronize { @subscribers.clear }
    end
  end

  def initialize
    # No external dependencies needed
  end

  # Broadcast a progress event
  #
  # @param execution_id [String] The execution identifier
  # @param event_type [Symbol] Type of event (see EVENT_TYPES)
  # @param data [Hash] Event-specific data
  # @return [Integer] Number of subscribers that received the message
  def broadcast(execution_id:, event_type:, data: {})
    validate_params!(execution_id, event_type)

    channel = channel_name(execution_id)

    event = {
      execution_id: execution_id,
      event_type: event_type,
      timestamp: Time.now.utc.iso8601,
      data: data
    }

    serialized = event.to_json

    # Publish to channel
    self.class.publish(channel, serialized)
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast progress event: #{e.message}"
    0
  end

  # Subscribe to progress events for a specific execution
  # Yields each event to the provided block
  #
  # @param execution_id [String] The execution identifier
  # @yield [Hash] Each progress event as it arrives
  # @return [void]
  def subscribe(execution_id:, &block)
    validate_execution_id!(execution_id)

    channel = channel_name(execution_id)

    callback = lambda do |message|
      event = JSON.parse(message).deep_symbolize_keys
      block.call(event)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse progress event: #{e.message}"
    end

    self.class.add_subscriber(channel, callback)

    # Return the callback so it can be removed later
    callback
  end

  # Unsubscribe from progress events
  #
  # @param execution_id [String] The execution identifier
  # @param callback [Proc] The callback that was returned from subscribe
  def unsubscribe(execution_id:, callback:)
    channel = channel_name(execution_id)
    self.class.remove_subscriber(channel, callback)
  end

  # Broadcast execution started event
  #
  # @param execution_id [String] The execution identifier
  # @param plan_path [String] Path to the plan file
  # @param project_path [String] Path to the project
  # @return [Integer] Number of subscribers
  def broadcast_started(execution_id:, plan_path:, project_path:)
    broadcast(
      execution_id: execution_id,
      event_type: :started,
      data: {
        plan_path: plan_path,
        project_path: project_path
      }
    )
  end

  # Broadcast milestone started event
  #
  # @param execution_id [String] The execution identifier
  # @param milestone_number [Integer] Milestone number
  # @param milestone_title [String] Milestone title
  # @return [Integer] Number of subscribers
  def broadcast_milestone_started(execution_id:, milestone_number:, milestone_title:)
    broadcast(
      execution_id: execution_id,
      event_type: :milestone_started,
      data: {
        milestone_number: milestone_number,
        milestone_title: milestone_title
      }
    )
  end

  # Broadcast milestone completed event
  #
  # @param execution_id [String] The execution identifier
  # @param milestone_number [Integer] Milestone number
  # @param checkpoint_id [String, nil] Associated checkpoint ID
  # @return [Integer] Number of subscribers
  def broadcast_milestone_completed(execution_id:, milestone_number:, checkpoint_id: nil)
    broadcast(
      execution_id: execution_id,
      event_type: :milestone_completed,
      data: {
        milestone_number: milestone_number,
        checkpoint_id: checkpoint_id
      }
    )
  end

  # Broadcast step started event
  #
  # @param execution_id [String] The execution identifier
  # @param step_number [Integer] Step number
  # @param step_title [String] Step title
  # @return [Integer] Number of subscribers
  def broadcast_step_started(execution_id:, step_number:, step_title:)
    broadcast(
      execution_id: execution_id,
      event_type: :step_started,
      data: {
        step_number: step_number,
        step_title: step_title
      }
    )
  end

  # Broadcast step completed event
  #
  # @param execution_id [String] The execution identifier
  # @param step_number [Integer] Step number
  # @param files_changed [Array<String>] List of changed files
  # @param progress_percentage [Float] Overall progress percentage
  # @return [Integer] Number of subscribers
  def broadcast_step_completed(execution_id:, step_number:, files_changed: [], progress_percentage: 0.0)
    broadcast(
      execution_id: execution_id,
      event_type: :step_completed,
      data: {
        step_number: step_number,
        files_changed: files_changed,
        progress_percentage: progress_percentage
      }
    )
  end

  # Broadcast step failed event
  #
  # @param execution_id [String] The execution identifier
  # @param step_number [Integer] Step number
  # @param error_message [String] Error message
  # @return [Integer] Number of subscribers
  def broadcast_step_failed(execution_id:, step_number:, error_message:)
    broadcast(
      execution_id: execution_id,
      event_type: :step_failed,
      data: {
        step_number: step_number,
        error_message: error_message
      }
    )
  end

  # Broadcast file changed event
  #
  # @param execution_id [String] The execution identifier
  # @param file_path [String] Path to the changed file
  # @param change_type [Symbol] Type of change (:created, :modified, :deleted)
  # @return [Integer] Number of subscribers
  def broadcast_file_changed(execution_id:, file_path:, change_type:)
    broadcast(
      execution_id: execution_id,
      event_type: :file_changed,
      data: {
        file_path: file_path,
        change_type: change_type
      }
    )
  end

  # Broadcast checkpoint created event
  #
  # @param execution_id [String] The execution identifier
  # @param checkpoint_id [String] The checkpoint identifier
  # @param message [String] Checkpoint message
  # @return [Integer] Number of subscribers
  def broadcast_checkpoint_created(execution_id:, checkpoint_id:, message:)
    broadcast(
      execution_id: execution_id,
      event_type: :checkpoint_created,
      data: {
        checkpoint_id: checkpoint_id,
        message: message
      }
    )
  end

  # Broadcast execution completed event
  #
  # @param execution_id [String] The execution identifier
  # @param total_files_changed [Integer] Total files changed
  # @param total_steps [Integer] Total steps completed
  # @return [Integer] Number of subscribers
  def broadcast_completed(execution_id:, total_files_changed: 0, total_steps: 0)
    broadcast(
      execution_id: execution_id,
      event_type: :completed,
      data: {
        total_files_changed: total_files_changed,
        total_steps: total_steps
      }
    )
  end

  # Broadcast execution failed event
  #
  # @param execution_id [String] The execution identifier
  # @param error_message [String] Error message
  # @return [Integer] Number of subscribers
  def broadcast_failed(execution_id:, error_message:)
    broadcast(
      execution_id: execution_id,
      event_type: :failed,
      data: {
        error_message: error_message
      }
    )
  end

  # Broadcast execution cancelled event
  #
  # @param execution_id [String] The execution identifier
  # @return [Integer] Number of subscribers
  def broadcast_cancelled(execution_id:)
    broadcast(
      execution_id: execution_id,
      event_type: :cancelled,
      data: {}
    )
  end

  private

  def channel_name(execution_id)
    "#{CHANNEL_PREFIX}#{execution_id}"
  end

  def validate_params!(execution_id, event_type)
    validate_execution_id!(execution_id)
    validate_event_type!(event_type)
  end

  def validate_execution_id!(execution_id)
    raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
    raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?
  end

  def validate_event_type!(event_type)
    raise ArgumentError, "event_type must be a Symbol" unless event_type.is_a?(Symbol)
    unless EVENT_TYPES.include?(event_type)
      raise ArgumentError, "Invalid event_type: #{event_type}. Must be one of: #{EVENT_TYPES.join(', ')}"
    end
  end
end
