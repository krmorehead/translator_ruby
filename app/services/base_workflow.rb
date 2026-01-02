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
    register_in_context_graph
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
  # @param limit [Integer] Maximum number of results
  # @return [Array] Array of similar memory objects
  def find_relevant_context(query_text:)
    workflow_memory.query_similar_memories(
      query_text: query_text,
      limit: limit
    )
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
    workflow_memory&.record_output(result)
    workflow_memory&.merge_to_parent(:outputs)

    # Only transition after all work is done
    trigger(:finish)
  end

  def mark_failed(message)
    @error = message
    workflow_memory&.record_error(message, state: current_state)
    trigger(:fail)
  end

  
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
    base = ENV.fetch("AGENT_DATA_PATH")
    File.join(base, "workflows", @owner_id, "#{self.class.workflow_name}_#{@workflow_id}.json")
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

  # Register this workflow in the context graph for queryable context access
  def register_in_context_graph
    return unless @workflow_memory

    # Create workflow node
    node = Graph::WorkflowNode.new(
      id: @workflow_id,
      workflow_memory: @workflow_memory
    )
    ContextGraphService.instance.register_node(node)

    # Create edge to parent if exists
    if @parent_memory
      parent_id = extract_parent_id(@parent_memory)
      edge = Graph::Edges::ParentChildEdge.new(
        from_node_id: @workflow_id,
        to_node_id: parent_id,
        metadata: { relationship: :workflow_to_parent }
      )
      ContextGraphService.instance.add_edge(edge)
    end
  end

  # Extract parent ID from parent memory store
  # @param parent_memory [Object] Parent memory store (WorkflowMemoryStore, MemoryStore, etc)
  # @return [String] Parent node ID
  def extract_parent_id(parent_memory)
    # WorkflowMemoryStore has workflow_id, MemoryStore uses owner_id
    if parent_memory.respond_to?(:workflow_id)
      parent_memory.workflow_id
    elsif parent_memory.respond_to?(:owner_id)
      parent_memory.owner_id
    else
      @owner_id # Fallback to owner_id
    end
  end
end
