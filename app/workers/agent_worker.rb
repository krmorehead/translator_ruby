# frozen_string_literal: true

# Goal-driven agent worker that uses an LLM planner to select actions.
# Instead of following a rigid pipeline, the agent assesses its current state,
# plans the next action (or custom workflow), executes it, and loops until
# the goal is achieved or resources are exhausted.
#
# Subclasses should:
# - Register available actions via `register_action`
# - Implement `create_memory_store` to provide domain-specific memory
# - Optionally override `goal_achieved?` for custom completion logic
# - Optionally override `resources_exhausted?` for custom limits
#
# @example
#   class ResearchAgent < AgentWorker
#     register_action :search_files, class_name: "Actions::SearchFilesAction"
#     register_action :analyze_file, class_name: "Actions::AnalyzeFileAction"
#
#     def create_memory_store
#       ResearchMemoryStore.new(owner_id: owner_id)
#     end
#   end
#
class AgentWorker < BaseWorker
  include ActionCache
  include ActionRegistry

  # Default limits to prevent runaway execution
  DEFAULT_MAX_ITERATIONS = 50
  DEFAULT_MAX_ACTIONS = 100

  # Agent-specific states
  initial_state :pending

  state :pending,     phase: nil,        description: "Agent created, not yet started"
  state :running,     phase: :setup,     description: "Agent initializing"
  state :planning,    phase: :reasoning, description: "Planning next action"
  state :executing,   phase: :work,      description: "Executing action"
  state :evaluating,  phase: :reasoning, description: "Evaluating progress"
  state :synthesizing, phase: :output,   description: "Synthesizing final results"
  state :complete,    phase: nil,        description: "Agent completed successfully"
  state :failed,      phase: nil,        description: "Agent encountered an error"

  # Define valid transitions
  transition from: :pending,     to: :running,     on: :start
  transition from: :running,     to: :planning,    on: :initialized
  transition from: :planning,    to: :executing,   on: :action_selected
  transition from: :executing,   to: :evaluating,  on: :action_completed
  transition from: :evaluating,  to: :planning,    on: :continue
  transition from: :evaluating,  to: :synthesizing, on: :goal_reached
  transition from: :synthesizing, to: :complete,   on: :finish

  # Error and retry transitions
  transition from: [:running, :planning, :executing, :evaluating, :synthesizing],
             to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  attr_reader :memory_store, :iteration_count, :action_count
  attr_reader :goal_context, :action_history_context

  def initialize(goal:, context:, **options)
    # BaseWorker needs path, but we don't use it - pass nil
    super(goal: goal, context: context, path: nil, **options)
    @max_iterations = options.fetch(:max_iterations, DEFAULT_MAX_ITERATIONS)
    @max_actions = options.fetch(:max_actions, DEFAULT_MAX_ACTIONS)
    @iteration_count = 0
    @action_count = 0
    @current_plan = nil
    @memory_store = nil

    # Initialize context objects
    @goal_context = Contexts::GoalContext.new(goal_text: goal)
    @action_history_context = Contexts::ActionHistoryContext.new

    clear_action_cache!
  end

  # Execute the goal-driven agent loop
  # @return [Hash] Final result with findings and metadata
  def execute
    @started_at = Time.now.utc
    trigger(:start)
    initialize_agent

    trigger(:initialized)

    # Main agent loop
    until should_stop?
      @iteration_count += 1

      # Plan phase: decide what to do next
      plan = plan_next_action
      break if plan[:action] == "stop"

      trigger(:action_selected)

      # Execute phase: run the selected action
      execute_planned_action(plan)

      trigger(:action_completed)

      # Evaluate phase: check if goal is achieved
      if goal_achieved?
        trigger(:goal_reached)
        break
      else
        trigger(:continue)
      end
    end

    # Transition to synthesizing if not already there
    transition_to_synthesizing

    # Synthesize final results
    synthesis = synthesize_findings

    # Transition to complete
    trigger(:finish)

    # Build and return result
    @result = build_result(synthesis)
    @result
  rescue StandardError => e
    handle_error(e)
  end

  # Transition to synthesizing state from any valid state
  def transition_to_synthesizing
    case current_state
    when :evaluating
      trigger(:goal_reached)
    when :planning
      # From planning, we need to go through the action path to reach synthesizing
      trigger(:action_selected)
      trigger(:action_completed)
      trigger(:goal_reached)
    when :synthesizing
      # Already there
    when :executing
      trigger(:action_completed)
      trigger(:goal_reached)
    end
  end

  # Check if the agent should stop execution
  # @return [Boolean]
  def should_stop?
    goal_achieved? || resources_exhausted?
  end

  # Check if the goal has been achieved
  # Subclasses can override for custom logic
  # @return [Boolean]
  def goal_achieved?
    return false if @action_history_context.actions.empty?

    progress = evaluate_goal_progress
    progress[:goal_achieved] == true
  end

  # Check if we've exhausted our resource limits
  # @return [Boolean]
  def resources_exhausted?
    @iteration_count >= @max_iterations || @action_count >= @max_actions
  end

  # Get available actions for this agent
  # @return [Array<Hash>] Action definitions
  def available_actions
    self.class.action_definitions
  end

  
  # Initialize agent-specific components
  # Subclasses should override to set up domain-specific state
  def initialize_agent
    ensure_state_directory!
    @memory_store = create_memory_store
    record_decision(
      decision: "Starting agent",
      rationale: "Goal: #{goal}",
      context: { max_iterations: @max_iterations, max_actions: @max_actions }
    )
  end

  # Create the memory store for this agent
  # Subclasses must implement this
  # @return [ResearchMemoryStore] A memory store instance
  def create_memory_store
    raise NotImplementedError, "#{self.class.name} must implement #create_memory_store"
  end

  # Plan the next action using the LLM planner
  # @return [Hash] The planned action
  def plan_next_action
    prompt = AgentPlanningPrompt.new(actions: available_actions)
    context = build_planning_context

    result = prompt.execute(prompt: goal, context: context)
    plan = result[:content]

    record_decision(
      decision: "Planned action: #{plan[:action]}",
      rationale: plan[:rationale],
      context: { arguments: plan[:arguments], expected_outcome: plan[:expected_outcome] }
    )

    @current_plan = plan
    plan
  end

  # Execute a planned action
  # @param plan [Hash] The action plan from the planner
  # @return [Hash] The action result
  def execute_planned_action(plan)
    action_name = plan[:action].to_sym
    arguments = plan[:arguments] || {}

    # Handle custom workflows specially
    if action_name == :custom_workflow
      return execute_custom_workflow(plan[:steps])
    end

    # Get the action class using ActionRegistry
    action_class = action_class_for(action_name)

    # Execute with caching
    context_hash = @action_history_context.compute_hash
    result = execute_with_cache(action_name, arguments, context_hash) do
      execute_action(action_class, arguments)
    end

    # Record in action history context
    @action_count += 1
    @action_history_context.record_action(
      name: action_name,
      arguments: arguments,
      result: result,
      iteration: @iteration_count
    )

    # Update memory with findings
    update_memory_with_result(action_name, result)

    result
  end

  # Execute a single action
  # @param action_class [Class] The action class
  # @param arguments [Hash] Arguments for the action
  # @return [Hash] The action result
  def execute_action(action_class, arguments)
    action = action_class.new(
      agent: self,
      memory_store: @memory_store,
      goal: goal
    )
    action.execute(**arguments.symbolize_keys)
  end

  # Execute a custom workflow (sequence of actions)
  # @param steps [Array<Hash>] The workflow steps
  # @return [Hash] Combined results
  def execute_custom_workflow(steps)
    results = []
    previous_result = nil

    steps.each_with_index do |step, index|
      # Substitute $result references with previous result
      arguments = substitute_result_references(step[:arguments], previous_result)

      plan = {
        action: step[:action],
        arguments: arguments,
        rationale: "Step #{index + 1} of custom workflow"
      }

      result = execute_planned_action(plan)
      results << result
      previous_result = result

      # Stop if a step fails
      break unless result[:success]
    end

    {
      success: results.all? { |r| r[:success] },
      steps: results,
      workflow_type: :custom
    }
  end

  # Evaluate progress toward the goal
  # @return [Hash] Progress evaluation with :goal_achieved key
  def evaluate_goal_progress
    prompt = GoalProgressPrompt.new
    context = build_evaluation_context

    result = prompt.execute(prompt: goal, context: context)
    result[:content]
  end

  # Synthesize all findings into a final result
  # @return [Hash] Synthesized findings
  def synthesize_findings
    findings = Array(memory_store.get_section(:findings))
    return { summary: "No findings" } if findings.empty?

    prompt = Research::SynthesisPrompt.new
    context = build_synthesis_context
    result = prompt.execute(prompt: goal, context: context)
    result[:content]
  end

  # Build context for the planning prompt
  # @return [Contexts::WorkflowContext] Planning context
  def build_planning_context
    context = Contexts::WorkflowContext.new(
      goal: goal
    )

    # Add goal context as sub-context
    context.add_sub_context(:goal, @goal_context)

    # Add action history as sub-context
    context.add_sub_context(:actions, @action_history_context)

    # Add recent findings from memory
    findings = Array(memory_store.get_section(:findings))
    findings.last(10).each do |finding|
      content_text = finding.is_a?(Hash) ? (finding[:text] || finding.to_s) : finding.to_s
      source = finding.is_a?(Hash) ? finding[:source] : "finding"
      context.add(
        content: content_text,
        topics: ["finding", source].compact,
        source: source
      )
    end

    # Add memory summary using intelligent serialization
    if memory_store.respond_to?(:to_prompt_text)
      summary = memory_store.to_prompt_text(context_type: :context_chain, max_tokens: 300)
      context.add(content: summary, topics: ["memory"], source: "memory") unless summary.blank?
    else
      # Fallback for non-research memory stores
      summary = memory_store.compressed_context_summary
      context.add(content: summary, topics: ["memory"], source: "memory") unless summary.blank?
    end

    context
  end

  # Build context for goal evaluation
  # @return [Contexts::WorkflowContext] Evaluation context
  def build_evaluation_context
    context = Contexts::WorkflowContext.new(
      goal: goal
    )

    context.add(content: "Goal: #{goal}", topics: ["goal"], source: "agent")
    context.add(content: "Iterations: #{@iteration_count}", topics: ["progress"], source: "agent")
    context.add(content: "Actions executed: #{@action_count}", topics: ["progress"], source: "agent")

    findings = memory_store.get_section(:findings)
    findings.each do |finding|
      context.add(
        content: finding[:text],
        topics: ["finding"],
        source: finding[:source]
      )
    end

    context
  end

  # Build context for synthesis
  # @return [Contexts::BaseContext] Synthesis context
  def build_synthesis_context
    memory_store.full_context
  end

  # Update memory with action result
  # @param action_name [Symbol] The action that was executed
  # @param result [Hash] The action result
  def update_memory_with_result(action_name, result)
    return unless result[:success]

    # Extract findings from result
    findings = result[:findings] || []
    findings = [{ text: result[:summary], source: action_name.to_s }] if findings.empty? && result[:summary]

    findings.each do |finding|
      # Mark progress on sub-goals if applicable
      @goal_context.pending_sub_goals.each do |sg|
        if finding[:text].downcase.include?(sg[:text].downcase.first(20))
          @goal_context.mark_progress(sg[:id], :in_progress)
        end
      end

      memory_store.update_section(
        name: :findings,
        content: finding.merge(action: action_name),
        append: true
      )
    end
  end

  # Substitute $result[n] references in arguments
  # @param arguments [Hash] Arguments that may contain references
  # @param previous_result [Hash] The previous action result
  # @return [Hash] Arguments with substitutions applied
  def substitute_result_references(arguments, previous_result)
    return {} if arguments.nil?
    return arguments if previous_result.nil?

    arguments.transform_values do |value|
      next value unless value.is_a?(String) && value.start_with?("$result")

      extract_result_value(value, previous_result)
    end
  end

  # Record a decision to memory
  # @param decision [String] What was decided
  # @param rationale [String] Why
  # @param context [Hash] Additional context
  def record_decision(decision:, rationale:, context: {})
    memory_store.record_state_transition(
      from: current_state,
      to: current_state,
      event: :decision,
      source: self.class.worker_name,
      payload: { decision: decision, rationale: rationale, context: context }
    )
  end

  # Build the final result hash
  # @param synthesis [Hash] The synthesized findings
  # @return [Hash] Complete result
  def build_result(synthesis)
    {
      success: true,
      goal: goal,owner_id: owner_id,
      findings: memory_store.get_section(:findings),
      synthesis: synthesis,
      action_history: @action_history_context.actions,
      goal_progress: @goal_context.overall_progress,
      cache_stats: cache_stats,
      metadata: {
        iterations: @iteration_count,
        actions_executed: @action_count,
        started_at: @started_at.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state,
        context: @goal_context.to_h
      }
    }
  end

  # Handle errors during execution
  # @param error [StandardError] The error
  # @return [Hash] Error result
  def handle_error(error)
    @error = error.message
    trigger(:fail) if can_trigger?(:fail)

    {
      success: false,
      error: error.message,
      goal: goal,
      owner_id: owner_id,
      findings: memory_store&.get_section(:findings) || [],
      action_history: @action_history_context.actions,
      metadata: {
        iterations: @iteration_count,
        actions_executed: @action_count,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state,
        error_class: error.class.name
      }
    }
  end
end
