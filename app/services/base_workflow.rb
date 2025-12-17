# frozen_string_literal: true

# Minimal contract for workflows used by the orchestrator.
# Includes StateMachine for enforced state transitions and
# WorkflowMemoryStore for maintaining workflow-specific memory.
class BaseWorkflow
  include StateMachine

  # Define base workflow states
  initial_state :pending

  state :pending,  description: "Workflow created, not yet started"
  state :running,  description: "Workflow is executing"
  state :complete, description: "Workflow finished successfully"
  state :failed,   description: "Workflow encountered an error"

  # Define valid transitions
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :complete, on: :finish
  transition from: [:pending, :running], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # Auto-record state transitions to memory
  on_transition do |from, to, event, payload|
    record_state_to_memory(from, to, event, payload) if respond_to?(:workflow_memory, true)
  end

  attr_reader :prompt, :conversation, :sandbox_path, :result, :error,
              :workflow_id, :owner_id, :workflow_memory, :parent_memory

  def self.workflow_name
    name.demodulize.underscore
  end

  # @param owner_id [String, nil] Parent worker's owner ID for memory isolation
  # @param parent_memory [#get_section, nil] Parent memory store for context queries
  def initialize(owner_id: nil, parent_memory: nil)
    initialize_state_machine
    @workflow_id = SecureRandom.uuid
    @owner_id = owner_id || SecureRandom.uuid
    @parent_memory = parent_memory
    @result = nil
    @error = nil
    @workflow_memory = nil
  end

  # Stores incoming context; returns self for chaining.
  def setup(prompt: nil, conversation: nil, sandbox_path: nil)
    @prompt = prompt
    @conversation = conversation
    @sandbox_path = sandbox_path

    # Initialize workflow memory if we have an owner_id
    initialize_workflow_memory if @owner_id

    self
  end

  # Must be implemented by subclasses.
  def execute
    raise NotImplementedError, "#{self.class.name} must implement #execute"
  end

  # State query helper methods
  def pending?
    current_state == :pending
  end

  def running?
    current_state == :running
  end

  def complete?
    current_state == :complete
  end

  def failed?
    current_state == :failed
  end

  # Query parent memory for specific sections
  # @param section_names [Array<Symbol>] Sections to retrieve
  # @return [Hash] Section data from parent
  def query_parent_memory(*section_names)
    return {} unless workflow_memory

    workflow_memory.query_parent(*section_names)
  end

  # Get compressed context from parent memory
  # @return [Hash] Summary of parent context
  def parent_context
    return {} unless workflow_memory

    workflow_memory.query_parent_context
  end

  # Record a decision to workflow memory
  def record_decision(decision:, rationale:, context: {})
    return unless workflow_memory

    workflow_memory.record_decision(
      decision: decision,
      rationale: rationale,
      context: context
    )
  end

  # Get the workflow's state history
  def state_history
    return super unless workflow_memory

    workflow_memory.state_history
  end

  # Get workflow memory summary
  def memory_summary
    return {} unless workflow_memory

    workflow_memory.summarize
  end

  protected

  def mark_running
    trigger(:start)
  end

  def mark_complete(result)
    @result = result

    # Record output to memory
    workflow_memory&.record_output(result) if result.is_a?(Hash)

    trigger(:finish)

    # Merge outputs back to parent
    workflow_memory&.merge_to_parent(:outputs)
  end

  def mark_failed(message)
    @error = message
    workflow_memory&.record_error(message, state: current_state)
    trigger(:fail)
  end

  private

  def initialize_workflow_memory
    @workflow_memory = WorkflowMemoryStore.new(
      owner_id: @owner_id,
      workflow_id: @workflow_id,
      workflow_name: self.class.workflow_name,
      parent_memory: @parent_memory,
      path: workflow_memory_path
    )
  end

  def workflow_memory_path
    return nil unless sandbox_path

    base = ENV["AGENT_STATE_PATH"] || File.join(sandbox_path, ".agents", "state")
    File.join(base, @owner_id, "workflows", "#{self.class.workflow_name}_#{@workflow_id}.json")
  end

  def record_state_to_memory(from, to, event, payload)
    return unless @workflow_memory

    @workflow_memory.record_state_transition(
      from: from,
      to: to,
      event: event,
      payload: payload
    )
  end
end
