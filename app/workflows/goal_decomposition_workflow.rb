# frozen_string_literal: true

# Reusable workflow for recursively breaking down goals into actionable sub-goals.
# This workflow is useful beyond just codebase research - it can be used for
# project planning, task breakdown, or any hierarchical goal structure.
#
# Maintains its own WorkflowMemoryStore and can query parent memory for context.
class GoalDecompositionWorkflow < BaseWorkflow
  attr_reader :goal, :max_depth, :goal_tree, :context

  # Default maximum decomposition depth
  DEFAULT_MAX_DEPTH = 4

  # Decomposition-specific states
  initial_state :pending

  state :pending,      phase: nil,       description: "Workflow created"
  state :running,      phase: :setup,    description: "Initializing"
  state :decomposing,  phase: :planning, description: "Breaking down goals"
  state :complete,     phase: nil,       description: "Completed"
  state :failed,       phase: nil,       description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :decomposing, on: :initialized
  transition from: :decomposing, to: :complete, on: :finish
  transition from: [:running, :decomposing], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # @param goal [String] The goal to decompose
  # @param owner_id [String] Unique ID for state isolation
  # @param context [Hash] Seed context for decomposition
  #   - codebase_summary [String] High-level description of the codebase
  #   - focus_areas [Array<String>] Areas to prioritize in decomposition
  #   - known_files [Array<String>] Files already known to be relevant
  #   - prior_findings [String] Previous findings to build on
  #   - constraints [Hash] Constraints on decomposition
  # @param parent_memory [#get_section, nil] Parent memory for context queries
  # @param max_depth [Integer] Maximum decomposition depth
  def initialize(goal:, owner_id:, context: {}, parent_memory: nil, max_depth: DEFAULT_MAX_DEPTH)
    super(owner_id: owner_id, parent_memory: parent_memory)
    @goal = goal
    @context = context || {}
    @max_depth = max_depth
    @goal_tree = nil
  end

  # Setup for compatibility with BaseWorkflow
  def setup(prompt: nil, conversation: nil)
    super
    self
  end

  # Execute the recursive decomposition

def execute
  trigger(:start)
  Rails.logger.info "[GoalDecompositionWorkflow] Starting decomposition for goal: #{goal}"
  Rails.logger.info "[GoalDecompositionWorkflow] Using context: #{context.inspect}"
  
  begin
    record_decision(
      decision: "Starting goal decomposition",
      rationale: "Breaking down: #{goal}",
      context: { max_depth: max_depth }
    )

    trigger(:initialized)
    Rails.logger.info "[GoalDecompositionWorkflow] Building initial context"
    decomp_context = build_initial_context
    Rails.logger.info "[GoalDecompositionWorkflow] Initial context built: #{decomp_context.inspect}"
    
    @goal_tree = decompose_recursively(
      goal: goal,
      parent_id: nil,
      depth: 0,
      decomp_context: decomp_context
    )

    Rails.logger.info "[GoalDecompositionWorkflow] Decomposition completed with tree: #{@goal_tree.inspect}"
    
    mark_complete({
      goal_tree: @goal_tree,
      leaf_count: count_leaves(@goal_tree),
      max_depth_reached: max_depth_in_tree(@goal_tree),
      total_questions: count_all(@goal_tree),
      seed_context_used: context.present?,
      workflow_memory_summary: memory_summary
    })

    result
  rescue StandardError => e
    Rails.logger.error "[GoalDecompositionWorkflow] Error during execution: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    mark_failed(e.message)
    nil
  end
end

  # Get all leaf goals (ready for investigation)
  # @return [Array<Hash>] Array of leaf goal nodes
  def leaf_goals
    collect_leaves(@goal_tree)
  end

  
  def build_initial_context
    initial = {}

    # Include codebase summary
    initial[:codebase_summary] = context[:codebase_summary] if context[:codebase_summary]

    # Include focus areas as guidance
    if context[:focus_areas]&.any?
      initial[:focus_guidance] = "Focus particularly on: #{context[:focus_areas].join(', ')}"
    end

    # Include known files
    if context[:known_files]&.any?
      initial[:known_relevant_files] = context[:known_files]
    end

    # Include prior findings
    if context[:prior_findings].present?
      initial[:prior_knowledge] = context[:prior_findings]
    end

    # Find relevant context from memory
    relevant_context = find_relevant_context("research goal sub questions context chain")

    if relevant_context.any?
      # Use first relevant context as parent goal
      initial[:parent_goal] = relevant_context.first.to_s
    end

    # Include constraints
    if context[:constraints].present?
      initial[:constraints] = context[:constraints]
    end

    initial
  end

  def decompose_recursively(goal:, parent_id:, depth:, decomp_context:)
    # Base case: max depth reached
    if depth >= max_depth
      return create_leaf_node(goal, parent_id, depth, "Max depth reached")
    end

    # Use TopicDecompositionPrompt to break down the goal
    prompt = Research::TopicDecompositionPrompt.new
    result = prompt.decompose(
      topic: goal,
      context: decomp_context.merge(parent_question: parent_id ? goal : nil)
    )

    questions = result[:content]["questions"] || []

    # If no questions returned, treat as leaf
    if questions.empty?
      return create_leaf_node(goal, parent_id, depth, "No decomposition possible")
    end

    # Build tree node with children
    node_id = SecureRandom.uuid
    node = {
      id: node_id,
      text: goal,
      parent_id: parent_id,
      depth: depth,
      is_leaf: false,
      children: [],
      metadata: {
        decomposition_id: node_id,
        constraints: decomp_context[:constraints] || {},
        focus_area: decomp_context[:focus_guidance]
      }
    }

    questions.each do |q|
      question_text = q["question"]
      is_leaf = q["is_leaf"]

      if is_leaf
        # This is a leaf - no further decomposition
        child = create_leaf_node(
          question_text,
          node[:id],
          depth + 1,
          q["rationale"]
        )
        child[:priority] = q["priority"]
        child[:aspects] = q["aspects"]
        node[:children] << child
      else
        # Recurse to decompose further
        child = decompose_recursively(
          goal: question_text,
          parent_id: node[:id],
          depth: depth + 1,
          decomp_context: decomp_context.merge(
            parent_question: goal,
            previous_questions: node[:children].map { |c| c[:text] }
          )
        )
        child[:priority] = q["priority"]
        child[:rationale] = q["rationale"]
        child[:aspects] = q["aspects"]
        node[:children] << child
      end
    end

    node
  end

  def create_leaf_node(text, parent_id, depth, rationale)
    leaf_id = SecureRandom.uuid
    {
      id: leaf_id,
      text: text,
      parent_id: parent_id,
      depth: depth,
      is_leaf: true,
      rationale: rationale,
      children: [],
      metadata: {
        decomposition_id: leaf_id,
        constraints: {},
        focus_area: nil
      }
    }
  end

  def count_leaves(node)
    return 0 if node.nil?
    return 1 if node[:is_leaf]

    (node[:children] || []).sum { |child| count_leaves(child) }
  end

  def count_all(node)
    return 0 if node.nil?

    1 + (node[:children] || []).sum { |child| count_all(child) }
  end

  def max_depth_in_tree(node, current_max = 0)
    return current_max if node.nil?

    new_max = [current_max, node[:depth] || 0].max
    (node[:children] || []).each do |child|
      new_max = max_depth_in_tree(child, new_max)
    end
    new_max
  end

  def collect_leaves(node, leaves = [])
    return leaves if node.nil?

    if node[:is_leaf]
      leaves << node
    else
      (node[:children] || []).each { |child| collect_leaves(child, leaves) }
    end

    leaves
  end
end
