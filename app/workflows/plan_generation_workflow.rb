# frozen_string_literal: true

# Workflow that generates execution plans from analysis results.
# Converts codebase analysis into structured plans with milestones and steps.
class PlanGenerationWorkflow < BaseWorkflow
  attr_reader :goal, :analysis_results, :context

  # Planning-specific states
  initial_state :pending

  state :pending,     description: "Workflow created"
  state :running,     description: "Initializing"
  state :generating,  description: "Generating plan from analysis"
  state :parsing,     description: "Parsing plan structure"
  state :complete,    description: "Completed"
  state :failed,      description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :generating, on: :initialized
  transition from: :generating, to: :parsing, on: :generated
  transition from: :parsing, to: :complete, on: :finish
  transition from: [:running, :generating, :parsing], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # @param goal [String] The goal to create a plan for
  # @param analysis_results [Hash] Results from CodebaseAnalysisWorkflow
  # @param owner_id [String] Unique ID for state isolation
  # @param parent_memory [#get_section, nil] Parent worker's memory
  # @param context [String, nil] Optional additional context
  def initialize(goal:, analysis_results:, owner_id:, parent_memory: nil, context: nil)
    validate_parameters!(goal, analysis_results, owner_id)
    super(owner_id: owner_id, parent_memory: parent_memory)

    @goal = goal
    @analysis_results = analysis_results
    @context = context
    @execution_plan = nil
  end

  # Execute the plan generation workflow
  # @return [Planning::ExecutionPlan] Generated execution plan
  def execute
    trigger(:start)
    initialize_workflow_memory
    record_decision(
      decision: "Starting plan generation",
      rationale: "Goal: #{goal}",
      context: {
        relevant_files_count: analysis_results[:relevant_files]&.size || 0,
        patterns_count: analysis_results[:patterns]&.size || 0
      }
    )

    # Phase 1: Generate plan with LLM
    trigger(:initialized)
    generate_plan

    # Phase 2: Parse into ExecutionPlan object
    trigger(:generated)
    parse_plan

    # Complete - mark with hash representation for memory
    mark_complete(@execution_plan.to_h)
    @execution_plan
  rescue => e
    mark_failed("Plan generation failed: #{e.message}")
    # Return a minimal valid plan on failure
    Planning::ExecutionPlan.new(
      goal: goal,
      milestones: [],
      metadata: { error: e.message }
    )
  end

  private

  # Generate plan using LLM
  def generate_plan
    prompt = Planning::PlanGenerationPrompt.new(
      goal: @goal,
      analysis_results: @analysis_results,
      context: @context
    )

    response = prompt.execute
    @plan_data = response[:content]

    record_decision(
      decision: "Generated plan structure",
      rationale: "LLM created plan with #{@plan_data[:milestones]&.size || 0} milestones",
      context: {
        milestones_count: @plan_data[:milestones]&.size || 0,
        has_constraints: @plan_data[:constraints]&.any? || false,
        has_assumptions: @plan_data[:assumptions]&.any? || false,
        has_risks: @plan_data[:risks]&.any? || false
      }
    )
  end

  # Parse LLM response into ExecutionPlan object
  def parse_plan
    milestones = []

    @plan_data[:milestones]&.each_with_index do |milestone_data, m_idx|
      steps = []

      milestone_data[:steps]&.each_with_index do |step_data, s_idx|
        step = Planning::PlanStep.new(
          title: step_data[:title],
          intent: step_data[:intent],
          details: step_data[:details] || [],
          tests: step_data[:tests] || [],
          estimated_duration: step_data[:estimated_duration],
          dependencies: step_data[:dependencies],
          file_changes: step_data[:file_changes],
          order_index: s_idx
        )
        steps << step
      end

      milestone = Planning::PlanMilestone.new(
        title: milestone_data[:title],
        description: milestone_data[:description],
        steps: steps,
        order_index: m_idx,
        estimated_duration: milestone_data[:estimated_duration],
        success_criteria: milestone_data[:success_criteria]
      )
      milestones << milestone
    end

    @execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: milestones,
      constraints: @plan_data[:constraints],
      assumptions: @plan_data[:assumptions],
      risks: @plan_data[:risks],
      metadata: { analysis_results: @analysis_results }
    )

    total_steps = milestones.sum(&:step_count)
    record_decision(
      decision: "Parsed plan into ExecutionPlan object",
      rationale: "Created #{milestones.size} milestones with #{total_steps} total steps",
      context: {
        milestones_count: milestones.size,
        total_steps: total_steps
      }
    )
  end

  def validate_parameters!(goal, analysis_results, owner_id)
    raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
    unless analysis_results.is_a?(Hash)
      raise ArgumentError, "analysis_results must be a Hash, got #{analysis_results.class}"
    end
    raise ArgumentError, "owner_id must be a String, got #{owner_id.class}" unless owner_id.is_a?(String)
  end
end

