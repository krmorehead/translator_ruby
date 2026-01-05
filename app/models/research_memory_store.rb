# frozen_string_literal: true

# File-backed store for research memory broken into named sections.
# Specialized for research sessions with owner-based isolation.
# 
# Inherits from WorkflowMemoryStore to get base workflow functionality
# (state_transitions, decisions, errors, etc.) and adds research-specific sections.
# 
# RESPONSIBILITY: Storage and retrieval of domain objects ONLY.
# Contexts handle all formatting, serialization for prompts, and intelligent retrieval.
class ResearchMemoryStore < WorkflowMemoryStore
  # Research-specific sections (in addition to inherited workflow sections)
  RESEARCH_SECTIONS = {
    research_goal: [],
    sub_questions: [],
    discovered_files: [],
    findings: [],           # Array of WorkflowMemories::Finding objects
    context_chain: [],
    iteration_log: [],
    documentation_cache: [],
    action_history: []
  }.freeze
  
  attr_reader :current_iteration

  # Initialize the research memory store
  # Memory file path is automatically determined (NOT configurable)
  def initialize(owner_id:, workflow_id:, workflow_name:, parent_id:)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?
    raise ArgumentError, "workflow_id is required" if workflow_id.nil? || workflow_id.to_s.empty?
    raise ArgumentError, "workflow_name is required" if workflow_name.nil? || workflow_name.to_s.empty?
    raise ArgumentError, "parent_id is required" if parent_id.nil? || parent_id.to_s.empty?
    
    @workflow_id = workflow_id
    @workflow_name = workflow_name
    @owner_id = owner_id.to_s
    @parent_id = parent_id.to_s
    @current_iteration = 0
    @context_stack = []

    # Initialize @sections with research sections BEFORE calling super
    # so that serialize_sections works during parent's save!
    @sections = {}
    RESEARCH_SECTIONS.each do |key, default_value|
      @sections[key] = default_value.dup
    end

    # Call parent constructor
    # Parent will merge in workflow sections and call save!
    super(
      workflow_id: @workflow_id,
      workflow_name: @workflow_name,
      parent_id: @parent_id,
      owner_id: @owner_id
    )
  end
  
  # Reconstruct ResearchMemoryStore from hash
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
    
    # Deserialize all sections
    sections = hash[:sections]
    store.instance_variable_set(:@sections, {
      # Workflow sections (objects)
      state_transitions: sections[:state_transitions].map { |h| WorkflowMemories::StateTransition.from_h(h) },
      workflow_context: sections[:workflow_context].map { |h| WorkflowMemories::Context.from_h(h) },
      decisions: sections[:decisions].map { |h| WorkflowMemories::Decision.from_h(h) },
      errors: sections[:errors].map { |h| WorkflowMemories::Error.from_h(h) },
      outputs: sections[:outputs].map { |h| WorkflowMemories::Output.from_h(h) },
      checkpoints: sections[:checkpoints],
      # Research sections (objects)
      research_goal: sections[:research_goal],
      sub_questions: sections[:sub_questions],
      discovered_files: sections[:discovered_files],
      findings: sections[:findings].map { |h| WorkflowMemories::Finding.from_h(h) },
      context_chain: sections[:context_chain],
      iteration_log: sections[:iteration_log],
      documentation_cache: sections[:documentation_cache],
      action_history: sections[:action_history]
    })
    
    store.instance_variable_set(:@current_iteration, hash[:current_iteration] || 0)
    store.instance_variable_set(:@context_stack, [])
    
    store
  end

  # ========================================================================
  # Simple Accessors - No Logic
  # ========================================================================

  def get_section(name)
    @sections[name.to_sym]
  end

  def set_section(name, value)
    section_key = name.to_sym
    raise ArgumentError, "Unknown section: #{name}" unless @sections.key?(section_key)

    @sections[section_key] = value
    save!
    @sections[section_key]
  end

  def update_section(name:, content:, append: true)
    section_key = name.to_sym

    if append
      @sections[section_key] ||= []
      @sections[section_key] << content
    else
      @sections[section_key] = [content]
    end

    save!
    @sections[section_key]
  end

  # ========================================================================
  # Context Chain - Simple Stack Operations
  # ========================================================================

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

  def pop_context
    entry = @context_stack.pop
    save!
    entry
  end

  # Get context chain entries for a specific sub-question
  def chain_for(sub_question)
    @sections[:context_chain].select { |entry| entry[:sub_question] == sub_question }
  end

  # ========================================================================
  # Iteration Tracking
  # ========================================================================

  def next_iteration!
    @current_iteration += 1
    @sections[:iteration_log] << {
      iteration: @current_iteration,
      timestamp: Time.now.utc.iso8601
    }
    save!
    @current_iteration
  end

  # ========================================================================
  # Documentation Deduplication
  # ========================================================================

  def file_documented?(file_path, goal_hash)
    @sections[:documentation_cache].any? do |d|
      d[:path] == file_path && d[:goal_hash] == goal_hash
    end
  end

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

  def get_documentation_id(file_path, goal_hash)
    entry = @sections[:documentation_cache].find do |d|
      d[:path] == file_path && d[:goal_hash] == goal_hash
    end
    entry&.dig(:doc_id)
  end

  def clear_documentation_cache!(file_path: nil)
    if file_path
      @sections[:documentation_cache].delete_if { |d| d[:path] == file_path }
    else
      @sections[:documentation_cache] = []
    end
    save!
  end

  # ========================================================================
  # Action History Tracking
  # ========================================================================

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

  def action_history(action: nil, limit: 50)
    history = @sections[:action_history]
    history = history.select { |h| h[:action] == action } if action
    history.last(limit)
  end

  def find_previous_action(action, arguments)
    @sections[:action_history].reverse.find do |h|
      h[:action] == action && h[:arguments] == arguments
    end
  end

  # ========================================================================
  # Simple Summary - Returns Raw Data
  # ========================================================================

  def summarize_findings
    findings = @sections[:findings]
    
    {
      goal: @sections[:research_goal].first&.dig(:text),
      sub_question_count: @sections[:sub_questions].size,
      discovered_file_count: @sections[:discovered_files].size,
      finding_count: findings.size,
      findings_summary: findings.map(&:text).join("\n\n").strip,
      iterations: @current_iteration
    }
  end

  # ========================================================================
  # Serialization
  # ========================================================================

  def serialize_sections
    parent_sections = super
    
    # Sections must exist - fail loudly if they don't
    raise "findings section not initialized" unless @sections.key?(:findings)
    
    parent_sections.merge(
      research_goal: @sections[:research_goal],
      sub_questions: @sections[:sub_questions],
      discovered_files: @sections[:discovered_files],
      findings: @sections[:findings].map(&:to_h),
      context_chain: @sections[:context_chain],
      iteration_log: @sections[:iteration_log],
      documentation_cache: @sections[:documentation_cache],
      action_history: @sections[:action_history]
    )
  end
  
  def to_h
    super.merge(current_iteration: @current_iteration)
  end

  # ========================================================================
  # Utility
  # ========================================================================

  def self.goal_hash(goal)
    Digest::SHA256.hexdigest(goal.to_s.strip.downcase)
  end

  private

  # GraphNode implementations
  def graph_node_id
    @workflow_id
  end

  def define_graph_edges
    edges = []
    
    @sections.keys.each do |section_name|
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
