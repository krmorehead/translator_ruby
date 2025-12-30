# frozen_string_literal: true

# Worker that orchestrates project planning by using CodebaseResearcher
# to gather information, then generating a structured project plan.
#
# Given a goal (feature/project to plan), path (codebase root), and project_name,
# the worker:
# 1. Uses CodebaseResearcher to understand the codebase
# 2. Passes research to ProjectPlanningWorkflow for plan generation
# 3. Writes output files via ProjectPlanOutputService
#
# @example Basic usage
#   planner = ProjectPlannerWorker.new(
#     goal: "Add user authentication",
#     path: "/path/to/codebase",
#     project_name: "user_authentication"
#   )
#   result = planner.execute
#
# @example With context
#   planner = ProjectPlannerWorker.new(
#     goal: "Add payment processing",
#     path: "/path/to/codebase",
#     project_name: "payment_processing",
#     context: {
#       known_files: ["app/services/billing_service.rb"],
#       constraints: "Must use Stripe API"
#     }
#   )
#
class ProjectPlannerWorker < BaseWorker
  # Register the workflows this worker uses
  register_workflow ProjectPlanningWorkflow

  # Planner-specific states
  initial_state :pending

  state :pending,     phase: nil,       description: "Worker created"
  state :running,     phase: :setup,    description: "Initializing"
  state :researching, phase: :research, description: "Running CodebaseResearcher"
  state :planning,    phase: :planning, description: "Generating project plan"
  state :writing,     phase: :output,   description: "Writing output files"
  state :complete,    phase: nil,       description: "Completed"
  state :failed,      phase: nil,       description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :researching, on: :initialized
  transition from: :researching, to: :planning, on: :researched
  transition from: :planning, to: :writing, on: :planned
  transition from: :writing, to: :complete, on: :finish
  transition from: [:running, :researching, :planning, :writing],
             to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  attr_reader :project_name, :memory_store, :research_result, :planning_result

  def initialize(goal:, path:, project_name:, context: {}, **options)
    super(goal: goal, path: path, context: context, **options)
    @project_name = project_name
    @max_research_depth = options.fetch(:max_research_depth, 2)
    @research_result = nil
    @planning_result = nil
  end

  # Execute the full project planning pipeline
  def execute
    trigger(:start)
    initialize_worker

    trigger(:initialized)
    perform_research

    trigger(:researched)
    generate_plan

    trigger(:planned)
    write_output_files

    trigger(:finish)
    @result[:metadata][:final_state] = current_state
    @result
  rescue StandardError => e
    Rails.logger.error "[ProjectPlannerWorker] Error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    mark_failed(e.message)
    build_error_result(e)
  end

  
  # Initialize the worker and create memory store
  def initialize_worker
    ensure_state_directory!
    @memory_store = create_memory_store

    record_decision(
      decision: "Starting project planning",
      rationale: "Goal: #{goal}, Project: #{project_name}",
      context: { path: path, max_research_depth: @max_research_depth }
    )
  end

  # Create the planning memory store
  def create_memory_store
    store_path = File.join(state_path, "planning_memory.json")
    ResearchMemoryStore.new(path: store_path, owner_id: owner_id)
  end

  # Phase 1: Research the codebase using CodebaseResearcher
  def perform_research
    record_decision(
      decision: "Starting codebase research",
      rationale: "Gathering information about the codebase for planning",
      context: { goal: goal, max_depth: @max_research_depth }
    )

    researcher = CodebaseResearcher.new(
      goal: goal,
      path: path,
      context: context,
      max_depth: @max_research_depth,
      output_modes: [:report]
    )

    @research_result = researcher.execute

    if !@research_result[:success]
      raise "Codebase research failed: #{@research_result[:error]}"
    end

    store_workflow_result(:codebase_research, @research_result)

    record_decision(
      decision: "Codebase research complete",
      rationale: "Found #{(@research_result[:findings] || []).size} findings",
      context: { file_count: (@research_result[:relevant_files] || []).size }
    )
  end

  # Phase 2: Generate the project plan using ProjectPlanningWorkflow
  def generate_plan
    record_decision(
      decision: "Starting project plan generation",
      rationale: "Transforming research findings into structured plan",
      context: { project_name: project_name }
    )

    workflow = ProjectPlanningWorkflow.new(
      goal: goal,
      project_name: project_name,
      owner_id: owner_id,
      research_results: @research_result,
      parent_memory: memory_store
    )

    workflow.setup
    workflow.execute

    if workflow.failed?
      raise "Project planning failed: #{workflow.error}"
    end

    @planning_result = workflow.result
    store_workflow_result(:project_planning, @planning_result)

    record_decision(
      decision: "Project plan generation complete",
      rationale: "Generated #{(@planning_result[:milestones] || []).size} milestones",
      context: {}
    )
  end

  # Phase 3: Write output files
  def write_output_files
    record_decision(
      decision: "Writing output files",
      rationale: "Persisting project plan to filesystem",
      context: { project_name: project_name }
    )

    output_service = ProjectPlanOutputService.new(
      project_name: project_name,
      base_path: path
    )

    output_paths = output_service.write(
      file_references_content: @planning_result[:file_references_content],
      project_plan_content: @planning_result[:project_plan_content]
    )

    @result = build_result(output_paths)
  end

  # Build the final result
  def build_result(output_paths)
    {
      success: true,
      goal: goal,
      path: path,
      project_name: project_name,
      owner_id: owner_id,
      project_path: output_paths[:project_path],
      file_references_path: output_paths[:file_references_path],
      project_plan_path: output_paths[:project_plan_path],
      research_summary: @research_result[:synthesis]&.dig(:summary) || @research_result[:synthesis]&.dig("summary"),
      milestones: @planning_result[:milestones] || [],
      existing_files: @planning_result[:existing_files] || [],
      planned_files: @planning_result[:planned_files] || [],
      metadata: {
        max_research_depth: @max_research_depth,
        context: context,
        started_at: Time.now.utc.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state,
        workflow_results: {
          codebase_research: workflow_result(:codebase_research)&.slice(:goal, :findings)&.tap { |h| h[:findings_count] = h.delete(:findings)&.size },
          project_planning: workflow_result(:project_planning)&.slice(:milestones)&.tap { |h| h[:milestone_count] = h.delete(:milestones)&.size }
        }
      }
    }
  end

  def build_error_result(error)
    {
      success: false,
      goal: goal,
      path: path,
      project_name: project_name,
      owner_id: owner_id,
      error: error.message,
      project_path: nil,
      file_references_path: nil,
      project_plan_path: nil,
      research_summary: @research_result&.dig(:synthesis, :summary),
      milestones: [],
      existing_files: [],
      planned_files: [],
      metadata: {
        final_state: current_state,
        error: error.message
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
end

