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

  # Memory store class to use (override in subclasses)
  MEMORY_STORE = WorkflowMemoryStore

  attr_reader :prompt, :conversation, :result, :error,
              :workflow_id, :owner_id, :workflow_memory, :parent_id

  def self.workflow_name
    name.demodulize.underscore
  end
  
  # Lazy-load parent memory via graph lookup
  # @return [WorkflowMemoryStore, MemoryStore, nil] Parent memory store or nil if parent not found
  def parent_memory
    return nil if is_root?
    service = ContextGraphService.instance
    parent_node = service.find_by_id(@parent_id)
    # Both WorkerNode and WorkflowNode have memory_store (WorkflowNode aliases it to workflow_memory)
    parent_node&.memory_store
  end

  def is_root?
    @parent_id == @owner_id
  end

  # @param owner_id [String] Owner ID for memory isolation (required)
  # @param parent_id [String] Parent ID for memory hierarchy (required)
  def initialize(owner_id:, parent_id:)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?
    raise ArgumentError, "parent_id is required" if parent_id.nil? || parent_id.to_s.empty?
    
    initialize_state_machine
    
    # Initialize ID first (standard OOP)
    @workflow_id = SecureRandom.uuid
    @owner_id = owner_id
    @parent_id = parent_id
    @result = nil
    @error = nil

    # Initialize memory store as part of initialization (standard OOP)
    @workflow_memory = initialize_memory_store
  end

  # Stores incoming context; returns self for chaining.
  def setup(prompt: nil, conversation: nil)
    @prompt = prompt
    @conversation = conversation
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

  # Initialize memory store using the MEMORY_STORE constant
  # Subclasses can override MEMORY_STORE to use a different store class
  # Can be overridden by subclasses to add additional initialization
  def initialize_memory_store
    # Use the MEMORY_STORE constant from this class (allows inheritance)
    # Path is calculated automatically inside the memory store
    self.class::MEMORY_STORE.new(
      workflow_id: @workflow_id,
      workflow_name: self.class.workflow_name,
      parent_id: @parent_id,
      owner_id: @owner_id
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
