# frozen_string_literal: true

# Memory store for workflows that maintains its own memory sections
# while providing access to query the parent worker's memory for context.
#
# Each workflow instance gets its own isolated memory, identified by:
#   - owner_id (from parent worker)
#   - workflow_id (unique to this workflow instance)
#
# @example
#   store = WorkflowMemoryStore.new(
#     owner_id: worker.owner_id,
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
  DEFAULT_SECTIONS = {
    state_transitions: [],
    workflow_context: [],
    decisions: [],
    errors: [],
    outputs: [],
    checkpoints: []
  }.freeze

  attr_reader :owner_id, :workflow_id, :workflow_name, :parent_memory, :path

  # @param owner_id [String] The parent worker's owner ID
  # @param workflow_id [String] Unique ID for this workflow instance
  # @param workflow_name [String] Name of the workflow class
  # @param parent_memory [#get_section, nil] Parent memory store to query for context
  # @param path [String] Path for persistence (REQUIRED for checkpoint tracking)
  def initialize(owner_id:, workflow_id:, workflow_name:, path:, parent_memory: nil)

    @owner_id = owner_id
    @workflow_id = workflow_id
    @workflow_name = workflow_name
    @parent_memory = parent_memory
    @path = path
    @sections = load_sections
    @started_at = Time.now.utc
    @last_transition_at = Time.now.utc  # Always initialized, never nil
  end

  # Query the parent memory for specific sections
  # @param section_names [Array<Symbol>] Section names to retrieve
  # @return [Hash] Hash of section_name => section_data
  def query_parent(*section_names)
    return {} unless parent_memory

    result = {}
    section_names.each do |name|
      begin
        data = parent_memory.get_section(name)
        result[name] = data if data
      rescue StandardError
        # Section doesn't exist in parent, skip
      end
    end
    result
  end

  # Query parent for a compressed context summary
  # @param sections [Array<Symbol>] Optional specific sections to summarize
  # @return [Hash] Summary of parent context
  def query_parent_context(sections: nil)
    return {} unless parent_memory

    if parent_memory.respond_to?(:summarize_findings)
      parent_memory.summarize_findings
    elsif sections
      query_parent(*sections)
    else
      # Try to get common context sections
      query_parent(:research_goal, :sub_questions, :context_chain, :findings)
    end
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

  # Query for similar memories using vector similarity
  # @param query_text [String] Text to search for similar memories
  # @param threshold [Float] Minimum similarity threshold (0.0-1.0)
  # @param limit [Integer, nil] Maximum number of results to return
  # @return [Array<Hash>] Array of {memory:, similarity:} hashes, sorted by similarity
  def query_similar_memories(query_text:, threshold: VectorizationService::DEFAULT_SIMILARITY_THRESHOLD, limit: nil)
    raise ArgumentError, "query_text cannot be empty" if query_text.nil? || query_text.empty?
    
    service = VectorizationService.new
    query_embedding = service.vectorize(text: query_text)
    
    results = service.find_similar(
      query_embedding: query_embedding,
      memories: all_memories,
      threshold: threshold
    )
    
    limit ? results.first(limit) : results
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
    last_transition ? last_transition.to : :pending
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
      owner_id: owner_id,
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      started_at: @started_at.iso8601,
      last_transition_at: @last_transition_at.iso8601,
      sections: serialize_sections
    }
  end

  # Merge this workflow's findings back to parent memory
  # @param sections [Array<Symbol>] Sections to merge (default: [:outputs])
  def merge_to_parent(*sections)
    return false unless parent_memory
    return false unless parent_memory.respond_to?(:update_section)

    sections = [:outputs] if sections.empty?

    # Map workflow section names to parent section names
    section_mapping = {
      outputs: :workflow_outputs
    }

    sections.each do |section|
      data = @sections[section]
      next unless data&.any?

      parent_section = section_mapping[section] || section

      data.each do |entry|
        # Convert domain object to hash for merging
        entry_hash = entry.respond_to?(:to_h) ? entry.to_h : entry
        parent_memory.update_section(
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
    repo_path = extract_repo_path
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
      checkpoints: @sections[:checkpoints]  # Keep as hashes
    }
  end

  def load_sections
    return deep_dup(DEFAULT_SECTIONS) unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true)
    sections = data[:sections] || {}
    @started_at = Time.parse(data[:started_at]) if data[:started_at]
    @last_transition_at = Time.parse(data[:last_transition_at]) if data[:last_transition_at]

    {
      state_transitions: deserialize_array(sections[:state_transitions], WorkflowMemories::StateTransition),
      workflow_context: deserialize_array(sections[:workflow_context], WorkflowMemories::Context),
      decisions: deserialize_array(sections[:decisions], WorkflowMemories::Decision),
      errors: deserialize_array(sections[:errors], WorkflowMemories::Error),
      outputs: deserialize_array(sections[:outputs], WorkflowMemories::Output),
      checkpoints: sections[:checkpoints] || []
    }
  rescue JSON::ParserError
    deep_dup(DEFAULT_SECTIONS)
  end

  # Deserialize array of hashes to objects
  # @param data [Array<Hash>] Array of serialized objects
  # @param klass [Class] Class to deserialize to (must have from_h method)
  # @return [Array] Array of deserialized objects
  # @raise [TypeError, ArgumentError] If deserialization fails
  def deserialize_array(data, klass)
    data.map { |hash| klass.from_h(hash) }
  end

  def save!
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(to_h))
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def calculate_duration
    # @last_transition_at is always initialized, no nil check needed
    Time.now.utc - @last_transition_at
  end

  # Extract the repository path from the workflow path
  # The workflow path is typically .agents/state/owner_id/workflows/...
  # We need to find the parent Git repository
  # @return [String] The repository root path
  # @raise [RuntimeError] If no Git repository found
  def extract_repo_path
    current = File.expand_path(@path)
    while current != "/"
      return current if File.directory?(File.join(current, ".git"))
      current = File.dirname(current)
    end
    raise "No Git repository found for path: #{@path}"
  end
end

