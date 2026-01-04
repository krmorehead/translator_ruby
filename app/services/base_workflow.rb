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

  attr_reader :prompt, :conversation, :result, :error,
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
  def setup(prompt: nil, conversation: nil)
    @prompt = prompt
    @conversation = conversation
    initialize_workflow_memory
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

  # Find relevant context using vector search
  # @param query_text [String] Text to search for
  # @param context_type [Symbol] Type of context (:goal, :decision, :output, etc)
  # @param limit [Integer] Maximum results to return (default: 10)
  # @return [Array] Array of context entries with scores
  def find_relevant_context(query_text:, context_type: :memory, limit: 10)
    workflow_memory.query_context(
      context_type: context_type,
      query_text: query_text,
      threshold: 0.7
    ).first(limit)
  end

  # Record a decision to workflow memory
  def record_decision(decision:, rationale:, context: {})
    workflow_memory.record_decision(
      decision: decision,
      rationale: rationale,
      context: context
    )
  end

  # Get the workflow's state history
  def state_history
    workflow_memory.state_history
  end

  # Get workflow memory summary
  def memory_summary
    workflow_memory.summarize
  end

  
  def mark_running
    trigger(:start)
  end

  def mark_complete(result)
    @result = result

    # Do all potentially-failing work BEFORE transitioning state
    workflow_memory.record_output(result)
    workflow_memory.merge_to_parent(:outputs)

    # Only transition after all work is done
    trigger(:finish)
  end

  def mark_failed(message)
    @error = message
    workflow_memory.record_error(message, state: current_state)
    trigger(:fail)
  end

  
  def initialize_workflow_memory
    parent_id = @parent_memory ? @parent_memory.id : @owner_id
    
    # Create path under AgentConfig.data_path
    memory_path = File.join(
      AgentConfig.data_path,
      @owner_id,
      "workflows",
      "workflow_#{@workflow_id}_memory.json"
    )
    
    @workflow_memory = WorkflowMemoryStore.new(
      workflow_id: @workflow_id,
      workflow_name: self.class.workflow_name,
      parent_id: parent_id,
      owner_id: @owner_id,
      path: memory_path
    )
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
