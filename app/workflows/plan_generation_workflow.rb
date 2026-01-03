# frozen_string_literal: true

# PlanGenerationWorkflow
# Generates structured execution plans with milestones and steps.
# Following Cline pattern: explores codebase using tools as needed during planning.
#
# The workflow has access to FileTreeTool, GrepTool, and ReadFileTool
# to explore the codebase during plan generation, letting the LLM decide
# what to explore based on the goal.
#
class PlanGenerationWorkflow < BaseWorkflow
  attr_reader :goal, :path, :context, :execution_plan

  # Planning-specific states
  initial_state :pending

  state :pending,     description: "Workflow created"
  state :running,     description: "Initializing"
  state :generating,  description: "Generating plan with codebase exploration"
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
  # @param path [String] Codebase root for exploration
  # @param owner_id [String] Unique ID for state isolation
  # @param parent_memory [ResearchMemoryStore, nil] Parent worker's memory
  # @param context [Contexts::BaseContext, nil] Planning context
  def initialize(goal:, path:, owner_id:, parent_memory: nil, context: nil)
    validate_parameters!(goal, path, owner_id)
    super(owner_id: owner_id, parent_memory: parent_memory)

    @goal = goal
    @path = path
    @context = context
    @execution_plan = nil
  end

  # Execute the plan generation workflow
  # Following Cline: explores codebase during planning, not before
  # @return [Planning::ExecutionPlan] Generated execution plan
  def execute
    trigger(:start)
    initialize_workflow_memory
    record_decision(
      decision: "Starting plan generation with codebase exploration",
      rationale: "Goal: #{goal}, Path: #{path}",
      context: { codebase_path: path }
    )

    # Phase 1: Generate plan with LLM (includes codebase exploration)
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

  # Generate plan using LLM with codebase exploration
  # Following Cline: LLM has access to tools and explores as needed
  def generate_plan
    prompt = Planning::PlanGenerationPrompt.new(
      goal: @goal,
      path: @path,
      context: extract_context_hint
    )

    record_decision(
      decision: "Sending plan generation request to LLM",
      rationale: "LLM will explore codebase using tools and generate structured plan",
      context: { 
        goal: @goal,
        codebase_path: @path,
        has_context_hint: extract_context_hint.present?
      }
    )

    # Call LLM with planning prompt
    # The prompt instructs LLM to use tools (file_tree, grep, read_file) to explore
    result = GenericLLMClient.call(
      system: prompt.system_message,
      user: prompt.user_message,
      response_format: { type: "json_object" }
    )

    @raw_plan_response = result[:content]

    record_decision(
      decision: "Received plan from LLM",
      rationale: "Successfully generated plan structure",
      context: { response_length: @raw_plan_response.length }
    )
  end

  # Parse LLM response into ExecutionPlan object
  def parse_plan
    # Parse JSON response
    plan_data = JSON.parse(@raw_plan_response, symbolize_names: true)

    # Convert to ExecutionPlan object
    @execution_plan = Planning::ExecutionPlan.from_h(plan_data)

    record_decision(
      decision: "Parsed plan into ExecutionPlan object",
      rationale: "Created structured plan with milestones and steps",
      context: {
        milestone_count: @execution_plan.milestone_count,
        step_count: @execution_plan.step_count
      }
    )
  rescue JSON::ParserError => e
    raise "Failed to parse LLM response as JSON: #{e.message}"
  rescue => e
    raise "Failed to convert plan data to ExecutionPlan: #{e.message}"
  end

  def validate_parameters!(goal, path, owner_id)
    raise ArgumentError, "goal must be a String" unless goal.is_a?(String)
    raise ArgumentError, "goal cannot be empty" if goal.strip.empty?
    raise ArgumentError, "path must be a String" unless path.is_a?(String)
    raise ArgumentError, "path cannot be empty" if path.strip.empty?
    raise ArgumentError, "owner_id must be a String" unless owner_id.is_a?(String)
    raise ArgumentError, "owner_id cannot be empty" if owner_id.strip.empty?
  end

  # Extract context hint from BaseContext if available
  def extract_context_hint
    return nil unless @context
    
    # Get all entries with "hint" or "additional_context" topics
    hint_entries = @context.find_by_topic("hint") + @context.find_by_topic("additional_context")
    return nil if hint_entries.empty?
    
    # Combine all hint content
    hint_entries.map { |entry| entry[:content] }.join("\n")
  end
end
