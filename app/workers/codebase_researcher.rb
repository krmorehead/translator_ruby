# frozen_string_literal: true

# Worker that orchestrates codebase research by coordinating
# GoalDecompositionWorkflow and ResearchWorkflow.
#
# Given a goal (research topic) and path (codebase root), the worker:
# 1. Decomposes the goal into sub-questions using GoalDecompositionWorkflow
# 2. Researches each sub-question using ResearchWorkflow
# 3. Synthesizes findings into a unified result
#
# @example Basic usage
#   researcher = CodebaseResearcher.new(
#     goal: "How does authentication work?",
#     path: "/path/to/codebase"
#   )
#   result = researcher.execute
#
# @example With seed context
#   researcher = CodebaseResearcher.new(
#     goal: "How does the payment flow work?",
#     path: "/path/to/codebase",
#     context: {
#       known_files: ["app/services/payment_service.rb"],
#       prior_findings: "Payment uses Stripe API",
#       focus_areas: ["error handling", "refund logic"]
#     }
#   )
#
class CodebaseResearcher < BaseWorker
  # Register the workflows this worker uses
  register_workflow GoalDecompositionWorkflow
  register_workflow ResearchWorkflow

  # Researcher-specific states
  initial_state :pending

  state :pending,       phase: nil,        description: "Worker created"
  state :running,       phase: :setup,     description: "Initializing"
  state :decomposing,   phase: :planning,  description: "Decomposing goal"
  state :researching,   phase: :work,      description: "Researching sub-questions"
  state :synthesizing,  phase: :output,    description: "Synthesizing findings"
  state :complete,      phase: nil,        description: "Completed"
  state :failed,        phase: nil,        description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :decomposing, on: :initialized
  transition from: :decomposing, to: :researching, on: :decomposed
  transition from: :researching, to: :synthesizing, on: :researched
  transition from: :synthesizing, to: :complete, on: :finish
  transition from: [:running, :decomposing, :researching, :synthesizing],
             to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  attr_reader :output_modes, :memory_store, :goal_tree

  def initialize(goal:, path:, context: {}, **options)
    super
    @output_modes = Array(options.fetch(:output_modes, [:report, :documentation])).map(&:to_sym)
    @max_depth = options.fetch(:max_depth, 4)
    @goal_tree = nil
    @research_result = nil
    @metadata = { decomposition_id: nil, constraints: {} }
  end

  def metadata
    @metadata
  end

  def initialize_worker
    ensure_state_directory!
    ensure_output_directory!
    @memory_store = create_memory_store

    record_decision(
      decision: "Starting codebase research",
      rationale: "Goal: #{goal}",
      context: { path: path, output_modes: output_modes, max_depth: @max_depth }
    )
  end

  def execute
    trigger(:start)
    initialize_worker

    trigger(:initialized)
    decompose_goal

    trigger(:decomposed)
    perform_research

    trigger(:researched)
    synthesize_results
  end

  # Phase : Decompose the goal using GoalDecompositionWorkflow
  def decompose_goal
    record_decision(
      decision: "Decomposing research goal",
      rationale: "Breaking down goal for systematic research",
      context: { goal: goal, max_depth: @max_depth }
    )

    workflow = GoalDecompositionWorkflow.new(
      goal: goal,
      owner_id: owner_id,
      context: context.merge(goal_tree: @goal_tree),
      parent_memory: memory_store,
      max_depth: @max_depth
    )

    workflow.setup
    workflow.execute

    if workflow.failed?
      Rails.logger.warn "Decomposition failed: #{workflow.error}"
      # Fallback to minimal structure
      @goal_tree = { is_leaf: true, text: "Fallback question" }
      record_decision(decision: "Using fallback decomposition", rationale: "Original decomposition failed")
    else
      @goal_tree = workflow.result[:goal_tree]
      @metadata[:decomposition_id] = @goal_tree[:metadata][:decomposition_id]
      @metadata[:constraints] = @goal_tree[:metadata][:constraints]
      store_workflow_result(:goal_decomposition, workflow.result)
    end

    # Convert UUID-based tree to flat structure
    flat_structure = process_goal_tree(@goal_tree)

    # Store sub-questions in memory
    flat_structure.each do |leaf|
      memory_store.update_section(
        name: :sub_questions,
        content: {
          text: leaf[:text],
          status: "pending",
          parent_id: leaf[:parent_id],
          decomposition_metadata: leaf[:metadata]
        },
        append: true
      )
    end

    record_decision(
      decision: "Goal decomposition complete",
      rationale: "Processed #{flat_structure.size} questions",
      context: {
        leaf_count: flat_structure.size,
        decomposition_status: workflow.failed? ? "fallback" : "success"
      }
    )
  end

  # Create the research memory store
  def create_memory_store
    store_path = File.join(state_path, "research_memory.json")
    store = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)

    store.set_section(:research_goal, [
      { text: goal, status: "active", context: context, timestamp: Time.now.utc.iso8601 }
    ])

    store
  end

  # Phase 1: Decompose the goal using GoalDecompositionWorkflow
  def process_goal_tree(tree)
    convert_to_flat_structure(tree)
  end
  public :process_goal_tree
  # Phase 2: Research using ResearchWorkflow
  def perform_research
    record_decision(
      decision: "Starting research workflow",
      rationale: "Researching decomposed goals",
      context: { output_modes: output_modes }
    )

    Rails.logger.info "[CodebaseResearcher] Starting ResearchWorkflow with goal: #{goal}"
    Rails.logger.info "[CodebaseResearcher] Using context: #{context.inspect}"
    Rails.logger.info "[CodebaseResearcher] goal_tree: #{@goal_tree.inspect}"

    unless @goal_tree
      Rails.logger.error "[CodebaseResearcher] Missing goal_tree - cannot proceed with research"
      raise "Missing goal_tree: Goal decomposition must be completed before research can begin"
    end

    workflow = ResearchWorkflow.new(
      goal: goal,
      owner_id: owner_id,
      research_path: path,
      context: context.merge(goal_tree: @goal_tree),
      parent_memory: memory_store,
      max_depth: @max_depth,
      output_modes: output_modes
    )

    workflow.setup
    begin
      workflow.execute
      if workflow.failed?
        raise "Research workflow failed: #{workflow.error}"
      end
    rescue StandardError => e
      Rails.logger.error "[CodebaseResearcher] Research workflow error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end

    @research_result = workflow.result
    Rails.logger.info "[CodebaseResearcher] Research result: #{@research_result.inspect}"
    store_workflow_result(:research, @research_result)

    # Transfer findings to our memory store
    (@research_result[:findings] || []).each do |finding|
      memory_store.update_section(
        name: :findings,
        content: finding,
        append: true
      )
    end

    record_decision(
      decision: "Research workflow complete",
      rationale: "Found #{(@research_result[:findings] || []).size} findings",
      context: { file_count: (@research_result[:file_analyses] || []).size }
    )
  end

  # Phase 3: Synthesize results from both workflows
  def synthesize_results
    record_decision(
      decision: "Synthesizing research results",
      rationale: "Combining findings from all workflows",
      context: {}
    )

    @result = build_result
  end

  # Build the final result combining all workflow results
  def build_result
    research = @research_result || {}

    {
      success: true,
      goal: goal,
      path: path,
      owner_id: owner_id,
      goal_tree: @goal_tree,
      findings: research[:findings] || memory_store.get_section(:findings),
      synthesis: research[:synthesis] || {},
      file_an: research[:file_analyses] || [],
      sub_questions: memory_store.get_section(:sub_questions),
      relevant_files: research[:relevant_files] || [],
      relevant_files_tree: research[:relevant_files_tree] || "",
      output_modes: output_modes,
      memory: memory_store.to_h,
      action_history: memory_store.action_history,
      goal_progress: calculate_goal_progress,
      cache_stats: {},
      metadata: {
        max_depth: @max_depth,
        output_modes: output_modes,
        context: context,
        started_at: Time.now.utc.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state,
        workflow_results: {
          goal_decomposition: workflow_result(:goal_decomposition),
          research: workflow_result(:research)
        },
        decomposition_metadata: @goal_tree&.fetch(:metadata, {})
      }
    }
  end

  def build_error_result(error)
    {
      success: false,
      goal: goal,
      path: path,
      owner_id: owner_id,
      error: error.message,
      findings: memory_store&.get_section(:findings) || [],
      synthesis: {},
      file_analyses: [],
      sub_questions: memory_store&.get_section(:sub_questions) || [],
      relevant_files: [],
      relevant_files_tree: "",
      output_modes: output_modes,
      memory: memory_store&.to_h || {},
      action_history: memory_store&.action_history || [],
      goal_progress: 0,
      cache_stats: {},
      metadata: {
        final_state: current_state,
        error: error.message,
        decomposition_status: "failed",
        workflow_results: {
          goal_decomposition: workflow_result(:goal_decomposition),
          research: workflow_result(:research)
        }
      }
    }
  end

  def record_decision(decision:, rationale:, context:)
    return unless memory_store

    memory_store.record_action(
      action: :decision,
      arguments: { decision: decision, rationale: rationale },
      result: { context: context }
    )
  end

  def calculate_goal_progress
    sub_questions = memory_store&.get_section(:sub_questions) || []
    return 0 if sub_questions.empty?

    completed = sub_questions.count { |sq| sq[:status] == "completed" }
    (completed.to_f / sub_questions.size * 100).round
  end

  # Convert UUID-based tree structure to flat array of leaf nodes
  def convert_to_flat_structure(node, parent_id = nil)
    return [] unless node

    if node[:is_leaf]
      {
        text: node[:text],
        parent_id: parent_id,
        metadata: {
          decomposition_id: node[:id],
          depth: node[:depth],
          focus_area: node[:focus_area],
          constraints: node[:constraints]
        }
      }
    else
      (node[:children] || []).flat_map do |child|
        convert_to_flat_structure(child, node[:id])
      end
    end
  end
end
