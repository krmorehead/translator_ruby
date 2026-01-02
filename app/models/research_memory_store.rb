# frozen_string_literal: true

# File-backed store for research memory broken into named sections.
# Specialized for research sessions with owner-based isolation and
# context chaining between iterations.
class ResearchMemoryStore
  include GraphNode
  
  DEFAULT_SECTIONS = {
    research_goal: [],
    sub_questions: [],
    discovered_files: [],
    findings: [],
    context_chain: [],
    iteration_log: [],
    state_transitions: [],
    workflow_outputs: [],
    documentation_cache: [],
    action_history: []
  }.freeze

  attr_reader :path, :id, :current_iteration, :owner_id

  # Find an existing research memory store by owner ID
  # @param owner_id [String] The owner ID to search for
  # @param base_path [String] Base directory to search in
  # @return [ResearchMemoryStore, nil] The store if found, nil otherwise
  def self.find_by_owner(owner_id, base_path:)
    search_path = File.join(base_path, owner_id, "research_memory.json")
    return nil unless File.exist?(search_path)
    new(path: search_path, owner_id: owner_id)
  end

  # List all owner IDs that have research memory stores
  # @return [Array<String>] Array of owner IDs
  def self.list_owners
    base_path = ENV.fetch("AGENT_DATA_PATH")
    Dir.entries(base_path)
       .select { |entry| File.directory?(File.join(base_path, entry)) && !entry.start_with?('.') }
       .select { |entry| File.exist?(File.join(base_path, entry, "research_memory.json")) }
    end

  # Find an existing research memory store by path
  # @param path [String] The full path to the memory file
  # @return [ResearchMemoryStore, nil] The store if found, nil otherwise
  def self.find_by_path(path)
    return nil unless File.exist?(path)
    # Extract owner_id from path if possible, otherwise use a generated one
    owner_id = File.basename(File.dirname(path))
    new(path: path, owner_id: owner_id)
  end

  # Initialize the research memory store
  # @param path [String] File path for persistence
  # @param owner_id [String] Unique identifier for the owner (worker/session)
  def initialize(path:, owner_id:)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?

    @path = path
    @id = SecureRandom.uuid
    @owner_id = owner_id.to_s
    @current_iteration = 0
    @sections = load_sections
    @context_stack = []
    @section_contexts = {}  # Cache for section contexts
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
    @section_contexts.delete(section_key)  # Invalidate cached context
    save!
    @sections[section_key]
  end

  # Update a section. If append is true, push an entry; otherwise replace.
  def update_section(name:, content:, append: true)
    section_key = name.to_sym

    if append
      @sections[section_key] ||= []
      @sections[section_key] << content
    else
      @sections[section_key] = [content]
    end

    @section_contexts.delete(section_key)
    save!
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
    save!
    entry
  end

  # Get recent context entries for use in prompts
  def recent_context(limit: 5, relevant_to: nil)
    entries = @sections[:context_chain]

    if relevant_to.present?
      scored = entries.map do |entry|
        question = entry[:sub_question].to_s
        insights = entry[:key_insights].to_s

        current_keywords = extract_keywords(relevant_to)
        entry_keywords = extract_keywords("#{question} #{insights}")
        overlap = (current_keywords & entry_keywords).size

        { entry: entry, score: overlap }
      end

      relevant = scored.select { |s| s[:score] > 0 }.sort_by { |s| -s[:score] }.first(limit)
      return relevant.map { |s| s[:entry] } if relevant.any?
    end

    entries.last(limit)
  end

  # Get a compressed summary of the context chain for prompts
  def compressed_context_summary
    entries = @sections[:context_chain]
    return "" if entries.empty?

    by_question = entries.group_by { |e| e[:sub_question] }
    summaries = by_question.map do |question, question_entries|
      latest = question_entries.last
      "#{question}: #{latest[:key_insights]}"
    end

    summaries.join("\n")
  end

  # Pop the most recent context from the chain
  # @return [Hash, nil] The context entry or nil if empty
  def pop_context
    entry = @context_stack.pop
    save!
    entry
  end

  # Retrieve context chain for a specific sub-question
  def chain_for(sub_question)
    @sections[:context_chain].select { |entry| entry[:sub_question] == sub_question }
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
    save!
    entry
  end

  # Get state history for a specific source (worker/workflow)
  def state_history(source: nil)
    transitions = @sections[:state_transitions]
    return transitions unless source

    transitions.select { |t| t[:source] == source }
  end

  # Summarize all findings into a compact format
  def summarize_findings
    findings = @sections[:findings]
    texts = findings.map { |e| e[:text] }.compact

    {
      goal: @sections[:research_goal].first&.dig(:text),
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

  # Get a Context instance for a specific section.
  def context_for(section)
    section_key = section.to_sym
    return @section_contexts[section_key] if @section_contexts.key?(section_key)

    research_goal_text = @sections[:research_goal].first&.dig(:text)
    context = Contexts::ResearchContext.new(research_goal: research_goal_text)
    @section_contexts[section_key] = build_context(section_key, context)
  end

  # Get a composite ResearchContext with all findings and context.
  def full_context
    research_goal_text = @sections[:research_goal].first&.dig(:text)
    composite = Contexts::ResearchContext.new(research_goal: research_goal_text)

    @sections.each_key do |section_key|
      section_context = context_for(section_key)
      composite.add_sub_context(section_key, section_context)
    end

    composite
  end

  # Invalidate cached contexts (call after mutations)
  def invalidate_contexts!
    @section_contexts = {}
  end

  # ==========================================================================
  # Documentation Deduplication
  # ==========================================================================

  # Check if a file has already been documented for a specific goal
  def file_documented?(file_path, goal_hash)
    @sections[:documentation_cache].any? do |d|
      d[:path] == file_path && d[:goal_hash] == goal_hash
    end
  end

  # Mark a file as documented
  # @param file_path [String] The file path
  # @param goal_hash [String] Hash of the research goal
  # @param doc_id [String] ID of the generated documentation
  # @param content_hash [String] Optional hash of the file content
  # @return [Hash] The documentation cache entry
  def mark_documented(file_path, goal_hash, doc_id, content_hash: nil)
    entry = {
      id: SecureRandom.uuid,
      path: file_path,
      goal_hash: goal_hash,
      doc_id: doc_id,
      content_hash: content_hash,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:documentation_cache] ||= []
    @sections[:documentation_cache] << entry
    save!
    entry
  end

  # Get documentation ID for a file/goal combination
  def get_documentation_id(file_path, goal_hash)
    entry = @sections[:documentation_cache].find do |d|
      d[:path] == file_path && d[:goal_hash] == goal_hash
    end
    entry&.dig(:doc_id)
  end

  # Clear documentation cache (for regeneration)
  def clear_documentation_cache!(file_path: nil)
    if file_path
      @sections[:documentation_cache].delete_if { |d| d[:path] == file_path }
    else
      @sections[:documentation_cache] = []
    end
    save!
  end

  # ==========================================================================
  # Action History Tracking
  # ==========================================================================

  # Record an action execution
  # @param action [String] The action name
  # @param arguments [Hash] Action arguments
  # @param result [Hash] Action result
  # @param cached [Boolean] Whether the result was from cache
  def record_action(action:, arguments:, result:, cached: false)
    entry = {
      id: SecureRandom.uuid,
      action: action,
      arguments: arguments,
      result_success: result[:success],
      result_summary: result[:summary] || result[:error],
      cached: cached,
      timestamp: Time.now.utc.iso8601
    }
    @sections[:action_history] ||= []
    @sections[:action_history] << entry
    save!
    entry
  end

  # Get action history
  def action_history(action: nil, limit: 50)
    history = @sections[:action_history]
    history = history.select { |h| h[:action] == action } if action
    history.last(limit)
  end

  # Check if an action has been executed before with same arguments
  def find_previous_action(action, arguments)
    @sections[:action_history].reverse.find do |h|
      h[:action] == action && h[:arguments] == arguments
    end
  end

  # Compute hash for goal (for deduplication)
  # @param goal [String] The goal text
  # @return [String] SHA256 hash of the goal
  def self.goal_hash(goal)
    Digest::SHA256.hexdigest(goal.to_s.strip.downcase)
  end

  
  # Build a context instance from section data
  def build_context(section_key, context)
    section_data = @sections[section_key]

    Array(section_data).each do |entry|
      topics = [section_key.to_s]
      topics << "q:#{entry[:sub_question]}" if entry[:sub_question]

      context.add(
        content: entry[:text],
        topics: topics,
        source: section_key.to_s,
        metadata: entry
      )
    end

    context
  end

  def extract_keywords(text)
    stop_words = %w[the a an is are was were what how why when where which who this that these those it its do does did has have had been be]
    text.to_s.downcase.gsub(/[^a-z0-9\s]/, "").split.reject { |w| stop_words.include?(w) || w.length < 3 }.uniq
  end

  def load_sections
    return deep_dup(DEFAULT_SECTIONS) unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true)
    @current_iteration = data.delete(:current_iteration) || 0

    DEFAULT_SECTIONS.merge(data)
  rescue JSON::ParserError
    deep_dup(DEFAULT_SECTIONS)
  end

  def save!
    FileUtils.mkdir_p(File.dirname(path))
    data = @sections.merge(current_iteration: @current_iteration)
    File.write(path, JSON.pretty_generate(data))
  end


  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def log_iteration
    @sections[:iteration_log] << {
      iteration: @current_iteration,
      timestamp: Time.now.utc.iso8601
    }
    save!
  end

  private

  # GraphNode concern implementations
  def graph_node_id
    @id
  end

  def graph_node_type
    :worker
  end

  def define_graph_edges
    edges = []
    
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

