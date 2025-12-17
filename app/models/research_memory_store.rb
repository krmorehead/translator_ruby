# frozen_string_literal: true

# File-backed store for research memory broken into named sections.
# Specialized for research sessions with owner-based isolation and
# context chaining between iterations.
class ResearchMemoryStore
  DEFAULT_SECTIONS = {
    research_goal: [],
    sub_questions: [],
    discovered_files: [],
    findings: [],
    context_chain: [],
    iteration_log: [],
    state_transitions: [],
    workflow_outputs: []
  }.freeze

  attr_reader :path, :owner_id, :current_iteration

  # Find an existing research memory store by owner ID
  # @param owner_id [String] The owner ID to search for
  # @param base_path [String] Base path to search in (defaults to env or .agents/state)
  # @return [ResearchMemoryStore, nil] The store if found, nil otherwise
  def self.find_by_owner(owner_id, base_path: nil)
    base = base_path || ENV["AGENT_STATE_PATH"] || ".agents/state"
    store_path = File.join(base, owner_id, "research_memory.json")
    return nil unless File.exist?(store_path)

    new(path: store_path, owner_id: owner_id)
  end

  # List all owner IDs with existing research sessions
  # @param base_path [String] Base path to search in
  # @return [Array<String>] List of owner IDs
  def self.list_owners(base_path: nil)
    base = base_path || ENV["AGENT_STATE_PATH"] || ".agents/state"
    return [] unless File.directory?(base)

    Dir.children(base).select do |dir|
      File.exist?(File.join(base, dir, "research_memory.json"))
    end
  end

  # Initialize the research memory store
  # @param path [String] File path for persistence
  # @param owner_id [String] Required owner ID for isolation
  def initialize(path:, owner_id:)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.empty?

    @path = path
    @owner_id = owner_id
    @current_iteration = 0
    @sections = load_sections
    @context_stack = []
  end

  def list_sections
    @sections.keys
  end

  def get_section(name)
    @sections[name.to_sym]
  end

  def set_section(name, value)
    section_key = name.to_sym
    raise ArgumentError, "Unknown section: #{name}" unless @sections.key?(section_key)

    @sections[section_key] = value
    persist!
    @sections[section_key]
  end

  # Update a section. If append is true, push an entry; otherwise replace.
  def update_section(name:, content:, append: true)
    section_key = name.to_sym
    raise ArgumentError, "Unknown section: #{name}" unless @sections.key?(section_key)

    entry = normalize_entry(content)

    if append
      ensure_array_section!(section_key)
      @sections[section_key] << entry
    else
      @sections[section_key] = [entry]
    end

    persist!
    @sections[section_key]
  end

  # Push context for chaining reasoning across iterations
  # @param context [Hash] Context to push with keys: sub_question, key_insights
  def push_context(context)
    entry = {
      iteration: @current_iteration,
      sub_question: context[:sub_question],
      key_insights: context[:key_insights],
      timestamp: Time.now.utc.iso8601
    }
    @sections[:context_chain] << entry
    @context_stack << entry
    persist!
    entry
  end

  # Pop the most recent context from the chain
  # @return [Hash, nil] The context entry or nil if empty
  def pop_context
    entry = @context_stack.pop
    persist!
    entry
  end

  # Retrieve context chain for a specific sub-question
  # @param sub_question [String] The sub-question to filter by
  # @return [Array<Hash>] Relevant context entries
  def chain_for(sub_question)
    @sections[:context_chain].select do |entry|
      entry[:sub_question] == sub_question ||
        entry["sub_question"] == sub_question
    end
  end

  # Increment and return the current iteration
  # @return [Integer] The new iteration number
  def next_iteration!
    @current_iteration += 1
    log_iteration
    @current_iteration
  end

  # Record a state transition from worker or workflow
  # @param from [Symbol] Source state
  # @param to [Symbol] Target state
  # @param event [Symbol] Event that triggered transition
  # @param source [String] Name of worker/workflow
  # @param payload [Hash] Additional data
  def record_state_transition(from:, to:, event:, source: nil, payload: {})
    entry = {
      from: from,
      to: to,
      event: event,
      source: source,
      payload: payload,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:state_transitions] << entry
    persist!
    entry
  end

  # Get state history for a specific source (worker/workflow)
  # @param source [String, nil] Filter by source name
  # @return [Array<Hash>] State transitions
  def state_history(source: nil)
    transitions = @sections[:state_transitions] || []
    return transitions unless source

    transitions.select { |t| t[:source] == source }
  end

  # Summarize all findings into a compact format
  # @return [Hash] Summary with key findings
  def summarize_findings
    findings = @sections[:findings] || []
    texts = Array(findings).map { |e| e.is_a?(Hash) ? (e[:text] || e["text"]) : e }.compact

    {
      goal: (@sections[:research_goal].first&.dig(:text) ||
             @sections[:research_goal].first&.dig("text")),
      sub_question_count: @sections[:sub_questions].size,
      discovered_file_count: @sections[:discovered_files].size,
      finding_count: findings.size,
      findings_summary: texts.join("\n\n").strip,
      iterations: @current_iteration
    }
  end

  def to_h
    @sections.merge(
      owner_id: owner_id,
      current_iteration: @current_iteration
    )
  end

  private

  def load_sections
    return deep_dup(DEFAULT_SECTIONS) unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true) || {}
    @current_iteration = data.delete(:current_iteration) || 0

    DEFAULT_SECTIONS.merge(data) do |_key, default_val, loaded|
      loaded || default_val || []
    end
  rescue JSON::ParserError
    deep_dup(DEFAULT_SECTIONS)
  end

  def persist!
    FileUtils.mkdir_p(File.dirname(path))
    data = @sections.merge(current_iteration: @current_iteration)
    File.write(path, JSON.pretty_generate(data))
  end

  def normalize_entry(content)
    if content.is_a?(Hash)
      entry = content.dup
      entry[:timestamp] ||= Time.now.utc.iso8601
      entry
    else
      { text: content, timestamp: Time.now.utc.iso8601 }
    end
  end

  def ensure_array_section!(section_key)
    @sections[section_key] = [] unless @sections[section_key].is_a?(Array)
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def log_iteration
    @sections[:iteration_log] << {
      iteration: @current_iteration,
      timestamp: Time.now.utc.iso8601
    }
    persist!
  end
end

