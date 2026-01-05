# frozen_string_literal: true

# Memory store for workflows that maintains its own memory sections
# while providing access to query the parent worker's memory for context.
#
# Each workflow instance gets its own isolated memory, identified by:
#   - workflow_id (unique to this workflow instance)
#
# @example
#   store = WorkflowMemoryStore.new(
#     workflow_id: SecureRandom.uuid,
#     workflow_name: "research_workflow",
#     parent_memory: worker.memory_store
#   )
#
#   # Query parent for context
#   context = store.query_parent(:research_goal, :sub_questions)
#
#   # Add to workflow's own memory
#   store.record_state_transition(from: :pending, to: :running, event: :start)
#
class WorkflowMemoryStore
  include GraphNode
  
  DEFAULT_SECTIONS = {
    state_transitions: [],
    workflow_context: [],
    decisions: [],
    errors: [],
    outputs: [],
    checkpoints: []
  }

  attr_reader :workflow_id, :workflow_name, :parent_id, :path, :owner_id, :id

  # @param workflow_id [String] Unique ID for this workflow instance
  # @param workflow_name [String] Name of the workflow class
  # @param parent_id [String] ID of parent workflow or worker
  # @param path [String] Path for persistence (REQUIRED for checkpoint tracking)
  # @param owner_id [String] Owner ID for isolation
  def initialize(workflow_id:, workflow_name:, parent_id:, owner_id:)
    raise ArgumentError, "workflow_id is required" if workflow_id.nil? || workflow_id.to_s.empty?
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?
    raise ArgumentError, "parent_id is required" if parent_id.nil? || parent_id.to_s.empty?
    raise ArgumentError, "workflow_name is required" if workflow_name.nil? || workflow_name.to_s.empty?

    @workflow_id = workflow_id
    @workflow_name = workflow_name
    @parent_id = parent_id.to_s
    @owner_id = owner_id.to_s
    @id = @workflow_id # Set @id for GraphNode
    
    # Calculate path automatically - NOT configurable
    @path = calculate_memory_path
    
    # Initialize default workflow sections
    # Child classes set @sections BEFORE calling super
    @sections ||= {}
    @sections[:state_transitions] = []
    @sections[:workflow_context] = []
    @sections[:decisions] = []
    @sections[:errors] = []
    @sections[:outputs] = []
    @sections[:checkpoints] = []
    
    @started_at = Time.now.utc
    @last_transition_at = Time.now.utc
    
    save! # Save initial state
  end
  
  # Calculate the deterministic path for this memory store
  # Based on ENV configuration + workflow structure
  # NOT configurable - internal mechanism
  def calculate_memory_path
    File.join(
      AgentConfig.data_path,
      @owner_id,
      "workflows",
      "#{@workflow_name}_#{@workflow_id}_memory.json"
    )
  end
  
  # Load WorkflowMemoryStore from disk
  # @param workflow_id [String] Workflow ID to load
  # @param owner_id [String] Owner ID
  # @return [WorkflowMemoryStore] Loaded memory store
  def self.load_from_disk(workflow_id:, workflow_name:, owner_id:)
    raise ArgumentError, "workflow_id is required" if workflow_id.nil? || workflow_id.to_s.empty?
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?
    raise ArgumentError, "workflow_name is required" if workflow_name.nil? || workflow_name.to_s.empty?
    
    # Calculate deterministic path
    path = File.join(
      AgentConfig.data_path,
      owner_id.to_s,
      "workflows",
      "#{workflow_name}_#{workflow_id}_memory.json"
    )
    
    raise Errno::ENOENT, "File not found: #{path}" unless File.exist?(path)
    
    data = JSON.parse(File.read(path), symbolize_names: true)
    from_h(data)
  end
  
  # Reconstruct WorkflowMemoryStore from hash
  # @param hash [Hash] Serialized data
  # @return [WorkflowMemoryStore] Reconstructed memory store
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
    raise ArgumentError, "workflow_id is required" unless hash[:workflow_id]
    raise ArgumentError, "sections is required" unless hash[:sections]
    
    store = allocate
    store.instance_variable_set(:@workflow_id, hash[:workflow_id])
    store.instance_variable_set(:@workflow_name, hash[:workflow_name])
    store.instance_variable_set(:@parent_id, hash[:parent_id].to_s)
    store.instance_variable_set(:@owner_id, hash[:owner_id].to_s)
    store.instance_variable_set(:@id, hash[:workflow_id])
    
    # Calculate path automatically
    path = File.join(
      AgentConfig.data_path,
      hash[:owner_id].to_s,
      "workflows",
      "#{hash[:workflow_name]}_#{hash[:workflow_id]}_memory.json"
    )
    store.instance_variable_set(:@path, path)
    
    store.instance_variable_set(:@started_at, Time.parse(hash[:started_at]))
    store.instance_variable_set(:@last_transition_at, Time.parse(hash[:last_transition_at]))
    
    # Deserialize sections using from_h on each memory class
    sections = hash[:sections]
    store.instance_variable_set(:@sections, {
      state_transitions: sections[:state_transitions].map { |h| WorkflowMemories::StateTransition.from_h(h) },
      workflow_context: sections[:workflow_context].map { |h| WorkflowMemories::Context.from_h(h) },
      decisions: sections[:decisions].map { |h| WorkflowMemories::Decision.from_h(h) },
      errors: sections[:errors].map { |h| WorkflowMemories::Error.from_h(h) },
      outputs: sections[:outputs].map { |h| WorkflowMemories::Output.from_h(h) },
      checkpoints: sections[:checkpoints]
    })
    
    store
  end

  # Query for context using the graph service
  # The service automatically traverses edges to find relevant context
  # @param context_type [Symbol] Type of context to query (:goal, :decision, etc)
  # @param query_text [String] Text to search for
  # @param threshold [Float] Similarity threshold (default: 0.7)
  # @return [Array<Hash>] Relevant context entries with similarity scores
  def query_context(context_type:, query_text:, threshold: 0.7)
    raise TypeError, "query_text must be a String, got #{query_text.class}" unless query_text.is_a?(String)
    
    service = ContextGraphService.instance
    query_embedding = VectorizationService.new.vectorize(text: query_text)
    
    service.query(
      id: @id,
      context_type: context_type,
      query_embedding: query_embedding,
      threshold: threshold
    )
  end

  # Record a state transition to memory
  # @param from [Symbol] Source state
  # @param to [Symbol] Target state
  # @param event [Symbol] Event that triggered transition
  # @param payload [Hash] Additional data
  # @return [WorkflowMemories::StateTransition] The created memory object
  def record_state_transition(from:, to:, event:, source: nil, payload: {})
    memory = WorkflowMemories::StateTransition.new(
      from: from,
      to: to,
      event: event,
      source: source || @workflow_name,
      payload: payload,
      duration: calculate_duration,
      checkpoint_id: current_checkpoint_id,
      state: to  # New state after transition
    )
    @sections[:state_transitions] << memory
    @last_transition_at = Time.now.utc
    save!
    memory
  end

  # Record a decision made during workflow execution
  # @param decision [String] Description of the decision
  # @param rationale [String] Why this decision was made
  # @param context [Hash] Context that informed the decision
  # @return [WorkflowMemories::Decision] The created memory object
  def record_decision(decision:, rationale:, context: {})
    memory = WorkflowMemories::Decision.new(
      decision: decision,
      rationale: rationale,
      context: context,
      checkpoint_id: current_checkpoint_id,
      state: current_state
    )
    @sections[:decisions] << memory
    save!
    memory
  end

  # Record workflow context/notes
  # @param context [Hash] Context information
  # @return [WorkflowMemories::Context] The created memory object
  def record_context(context)
    memory = WorkflowMemories::Context.new(
      context_data: context,
      checkpoint_id: current_checkpoint_id,
      state: current_state
    )
    @sections[:workflow_context] << memory
    save!
    memory
  end

  # Record an error
  # @param error [String, StandardError] Error message or exception
  # @param state [Symbol] State when error occurred
  # @return [WorkflowMemories::Error] The created memory object
  def record_error(error, state: nil)
    error_message = error.is_a?(StandardError) ? error.message : error.to_s
    error_class = error.is_a?(StandardError) ? error.class.name : "Error"
    
    memory = WorkflowMemories::Error.new(
      error_message: error_message,
      error_class: error_class,
      checkpoint_id: current_checkpoint_id,
      state: state || current_state
    )
    @sections[:errors] << memory
    save!
    memory
  end

  # Record workflow output
  # @param output [Hash] Output data
  # @return [WorkflowMemories::Output] The created memory object
  def record_output(output)
    memory = WorkflowMemories::Output.new(
      output_data: output,
      checkpoint_id: current_checkpoint_id,
      state: current_state
    )
    @sections[:outputs] << memory
    save!
    memory
  end

  # Get all memory objects across all sections
  # @return [Array<WorkflowMemories::BaseMemory>] All workflow memories
  def all_memories
    [
      *@sections[:decisions],
      *@sections[:state_transitions],
      *@sections[:workflow_context],
      *@sections[:errors],
      *@sections[:outputs]
    ]
  end

  # Record checkpoint creation
  # @param checkpoint [Checkpoint] Checkpoint object to record
  # @raise [TypeError] If checkpoint is not a Checkpoint object
  def record_checkpoint(checkpoint)
    raise TypeError, "checkpoint must be a Checkpoint, got #{checkpoint.class}" unless checkpoint.is_a?(Checkpoint)
    
    entry = {
      checkpoint_id: checkpoint.id,
      message: checkpoint.message,
      created_at: checkpoint.created_at.iso8601,
      state: current_state,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:checkpoints] << entry
    save!
    entry
  end

  # Get a section
  def get_section(name)
    @sections[name.to_sym]
  end

  # List all sections
  def list_sections
    @sections.keys
  end

  # Get the current state from state transitions
  def current_state
    last_transition = @sections[:state_transitions].last
    return :pending unless last_transition
    
    raise TypeError, "Expected WorkflowMemories::StateTransition, got #{last_transition.class}" unless last_transition.is_a?(WorkflowMemories::StateTransition)
    last_transition.to
  end

  # Get full state history
  def state_history
    @sections[:state_transitions]
  end

  # Query checkpoints
  
  # Get all checkpoints
  # @return [Array<Hash>] Array of checkpoint entries
  def checkpoints
    @sections[:checkpoints]
  end

  # Find checkpoints for a milestone
  # @param milestone_id [String] Milestone ID to filter by
  # @return [Array<Hash>] Checkpoints for the milestone
  def checkpoints_for_milestone(milestone_id)
    @sections[:checkpoints].select { |cp| cp[:milestone_id] == milestone_id }
  end

  # Get latest checkpoint
  # @return [Hash, nil] Latest checkpoint entry or nil
  def latest_checkpoint
    @sections[:checkpoints].last
  end

  # Count of checkpoints
  # @return [Integer] Number of checkpoints
  def checkpoint_count
    @sections[:checkpoints].size
  end

  # Get checkpoint by ID
  # @param checkpoint_id [String] Checkpoint ID to find
  # @return [Hash, nil] Checkpoint entry or nil
  def get_checkpoint(checkpoint_id)
    @sections[:checkpoints].find { |cp| cp[:checkpoint_id] == checkpoint_id }
  end

  # Get all backup checkpoints
  # @return [Array<Hash>] Backup checkpoint entries
  def backup_checkpoints
    @sections[:checkpoints].select { |cp| cp[:is_backup] }
  end

  # Summarize the workflow memory
  # @return [Hash] Summary of workflow execution
  def summarize
    transitions = @sections[:state_transitions]
    checkpoints = @sections[:checkpoints]
    
    {
      workflow_name: workflow_name,
      workflow_id: workflow_id,
      owner_id: owner_id,
      started_at: @started_at.iso8601,
      current_state: current_state,
      transition_count: transitions.size,
      decision_count: @sections[:decisions].size,
      error_count: @sections[:errors].size,
      checkpoint_count: checkpoints.size,
      states_visited: transitions.map(&:to).uniq,
      total_duration: Time.now.utc - @started_at
    }
  end

  # Convert to hash for serialization
  def to_h
    {
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      owner_id: owner_id,
      started_at: @started_at.iso8601,
      last_transition_at: @last_transition_at.iso8601,
      sections: serialize_sections
    }
  end

  # Merge this workflow's findings back to parent memory
  # Uses ContextGraphService to find parent via edges
  # @param sections [Array<Symbol>] Sections to merge (default: [:outputs])
  def merge_to_parent(*sections)
    # Use the graph service to find parent
    service = ContextGraphService.instance
    parent_node = service.find_by_id(@parent_id)
    return false unless parent_node
    
    parent_store = parent_node.memory_store

    sections = [:outputs] if sections.empty?

    # Map workflow section names to parent section names
    section_mapping = {
      outputs: :workflow_outputs,
      decisions: :workflow_decisions,
      errors: :workflow_errors
    }

    sections.each do |section|
      data = @sections[section]
      next unless data&.any?

      parent_section = section_mapping[section] || section

      data.each do |entry|
        # Convert domain object to hash for merging
        entry_hash = entry.respond_to?(:to_h) ? entry.to_h : entry
        parent_store.update_section(
          name: parent_section,
          content: entry_hash.merge(source_workflow: workflow_name, source_workflow_id: workflow_id),
          append: true
        )
      end
    end

    true
  end

  # Get the current checkpoint ID for the codebase at this path
  # This automatically creates a checkpoint if the codebase has changed
  # @return [String] The checkpoint ID
  # @raise [RuntimeError] If checkpoint tracking fails or no Git repository found
  def current_checkpoint_id
    repo_path = git_workspace_path
    CheckpointTracker.instance.current_id(path: repo_path)
  end

  private

  def serialize_sections
    {
      state_transitions: @sections[:state_transitions].map(&:to_h),
      workflow_context: @sections[:workflow_context].map(&:to_h),
      decisions: @sections[:decisions].map(&:to_h),
      errors: @sections[:errors].map(&:to_h),
      outputs: @sections[:outputs].map(&:to_h),
      checkpoints: @sections[:checkpoints]
    }
  end

  def save!
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    File.write(path, JSON.pretty_generate(to_h))
  rescue Errno::ENOENT
    # Race condition: directory was deleted between mkdir_p and write
    # Retry once after recreating directory
    FileUtils.mkdir_p(dir)
    File.write(path, JSON.pretty_generate(to_h))
  end

  # Clean up the isolated git workspace for this workflow
  # OOP: Explicit cleanup for proper resource management in tests
  # @return [Boolean] True if workspace was cleaned up
  def cleanup_git_workspace!
    workspace_service = GitWorkspaceService.new
    workspace_service.cleanup_workspace(workspace_id: @workflow_id)
  end

  def calculate_duration
    Time.now.utc - @last_transition_at
  end

  # Extract the repository path from the workflow path
  # The workflow path is typically .agents/state/owner_id/workflows/...
  # We need to find the parent Git repository
  # @return [String] The repository root path
  # @raise [RuntimeError] If no Git repository found
  # Get or create an isolated git workspace for this workflow
  # OOP: Each workflow gets its own git repository to prevent lock contention
  # @return [String] Path to the isolated git workspace
  def git_workspace_path
    @git_workspace_path ||= begin
      # Use workflow_id to ensure each workflow has its own isolated git workspace
      workspace_service = GitWorkspaceService.new
      workspace_service.find_or_create_workspace(workspace_id: @workflow_id)
    end
  end

  def extract_repo_path
    current = File.expand_path(@path)
    while current != "/"
      return current if File.directory?(File.join(current, ".git"))
      current = File.dirname(current)
    end
    raise "No Git repository found for path: #{@path}"
  end

  # GraphNode concern implementations
  def graph_node_id
    @workflow_id
  end

  def graph_node_type
    :workflow
  end

  def define_graph_edges
    edges = []
    
    edges << {
      type: :parent_child,
      to: @parent_id,
      metadata: { relationship: :workflow_to_parent }
    }
  
    # Create edges for each memory section
    list_sections.each do |section_name|
      edges << {
        type: :memory_section,
        section: section_name,
        access_pattern: :read_write,
        metadata: {}
      }
    end
    
    edges
  end
end

