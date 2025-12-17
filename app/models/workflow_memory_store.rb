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
    outputs: []
  }.freeze

  attr_reader :owner_id, :workflow_id, :workflow_name, :parent_memory, :path

  # @param owner_id [String] The parent worker's owner ID
  # @param workflow_id [String] Unique ID for this workflow instance
  # @param workflow_name [String] Name of the workflow class
  # @param parent_memory [#get_section, nil] Parent memory store to query for context
  # @param path [String, nil] Optional path for persistence
  def initialize(owner_id:, workflow_id:, workflow_name:, parent_memory: nil, path: nil)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.empty?
    raise ArgumentError, "workflow_id is required" if workflow_id.nil? || workflow_id.empty?

    @owner_id = owner_id
    @workflow_id = workflow_id
    @workflow_name = workflow_name
    @parent_memory = parent_memory
    @path = path || default_path
    @sections = load_sections
    @started_at = Time.now.utc
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
  def record_state_transition(from:, to:, event:, payload: {})
    entry = {
      from: from,
      to: to,
      event: event,
      payload: payload,
      timestamp: Time.now.utc.iso8601,
      duration_in_state: calculate_duration
    }
    @sections[:state_transitions] << entry
    @last_transition_at = Time.now.utc
    persist!
    entry
  end

  # Record a decision made during workflow execution
  # @param decision [String] Description of the decision
  # @param rationale [String] Why this decision was made
  # @param context [Hash] Context that informed the decision
  def record_decision(decision:, rationale:, context: {})
    entry = {
      decision: decision,
      rationale: rationale,
      context: context,
      state: current_state,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:decisions] << entry
    persist!
    entry
  end

  # Record workflow context/notes
  # @param context [Hash] Context information
  def record_context(context)
    entry = context.merge(
      timestamp: Time.now.utc.iso8601,
      state: current_state
    )
    @sections[:workflow_context] << entry
    persist!
    entry
  end

  # Record an error
  # @param error [String, StandardError] Error message or exception
  # @param state [Symbol] State when error occurred
  def record_error(error, state: nil)
    entry = {
      error: error.is_a?(StandardError) ? error.message : error.to_s,
      error_class: error.is_a?(StandardError) ? error.class.name : nil,
      state: state || current_state,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:errors] << entry
    persist!
    entry
  end

  # Record workflow output
  # @param output [Hash] Output data
  def record_output(output)
    entry = output.merge(
      timestamp: Time.now.utc.iso8601,
      state: current_state
    )
    @sections[:outputs] << entry
    persist!
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
    last_transition ? last_transition[:to] : :pending
  end

  # Get full state history
  def state_history
    @sections[:state_transitions]
  end

  # Summarize the workflow memory
  # @return [Hash] Summary of workflow execution
  def summarize
    transitions = @sections[:state_transitions]
    {
      workflow_name: workflow_name,
      workflow_id: workflow_id,
      owner_id: owner_id,
      started_at: @started_at.iso8601,
      current_state: current_state,
      transition_count: transitions.size,
      decision_count: @sections[:decisions].size,
      error_count: @sections[:errors].size,
      states_visited: transitions.map { |t| t[:to] }.uniq,
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
      sections: @sections
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
        parent_memory.update_section(
          name: parent_section,
          content: entry.merge(source_workflow: workflow_name, source_workflow_id: workflow_id),
          append: true
        )
      end
    end

    true
  end

  private

  def default_path
    base = ENV["AGENT_STATE_PATH"] || ".agents/state"
    File.join(base, owner_id, "workflows", "#{workflow_name}_#{workflow_id}.json")
  end

  def load_sections
    return deep_dup(DEFAULT_SECTIONS) unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true)
    sections = data[:sections] || {}
    @started_at = Time.parse(data[:started_at]) if data[:started_at]

    DEFAULT_SECTIONS.merge(sections) do |_key, default_val, loaded|
      loaded || default_val || []
    end
  rescue JSON::ParserError
    deep_dup(DEFAULT_SECTIONS)
  end

  def persist!
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(to_h))
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def calculate_duration
    return 0 unless @last_transition_at
    Time.now.utc - @last_transition_at
  end
end

