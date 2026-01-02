# frozen_string_literal: true

# Daedalus - The master architect and planner of Greek mythology.
# This worker analyzes user requests and generates structured execution plans.
# Named after Daedalus, the legendary craftsman who built the Labyrinth and
# designed wings that could fly - a fitting symbol for careful planning and execution.
#
# Inspired by Cline's "Plan Mode" but adapted to our OOP architecture.
#
# Flow:
# 1. Analyze codebase (CodebaseAnalysisWorkflow)
# 2. Generate plan (PlanGenerationWorkflow)
# 3. Write output files (PlanOutputService)
#
# @example
#   worker = DaedalusWorker.new(
#     goal: "Create a new feature",
#     path: "/path/to/codebase"
#   )
#   result = worker.execute
#   puts result[:output_paths][:plan_path]
#
class DaedalusWorker < BaseWorker
  attr_reader :research_memory, :analysis_results, :execution_plan, :output_paths

  # Register workflows this worker uses
  register_workflow CodebaseAnalysisWorkflow
  register_workflow PlanGenerationWorkflow

  # Plan-specific states (extends base worker)
  initial_state :pending

  state :pending,     description: "Worker created"
  state :running,     description: "Initializing"
  state :analyzing,   description: "Analyzing codebase"
  state :planning,    description: "Generating plan"
  state :writing,     description: "Writing output files"
  state :complete,    description: "Completed"
  state :failed,      description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :analyzing, on: :initialized
  transition from: :analyzing, to: :planning, on: :analyzed
  transition from: :planning, to: :writing, on: :planned
  transition from: :writing, to: :complete, on: :finish
  transition from: [:running, :analyzing, :planning, :writing], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # @param goal [String] What to accomplish
  # @param path [String] Codebase root
  # @param context [Hash] Optional hints/context
  def initialize(goal:, path:, context:, **options)
    validate_init_params!(goal, path)
    super(goal: goal, path: path, context: context, **options)

    @research_memory = nil
    @analysis_results = nil
    @execution_plan = nil
    @output_paths = nil
  end

  # Execute the full planning pipeline
  # @return [Hash] Result with execution_plan, output_paths, analysis_summary, metadata
  def execute
    trigger(:start)
    initialize_worker

    # Phase 1: Analyze codebase
    trigger(:initialized)
    run_analysis

    # Phase 2: Generate plan
    trigger(:analyzed)
    run_planning

    # Phase 3: Write output files
    trigger(:planned)
    write_output_files

    # Complete and build result
    trigger(:finish)
    build_result
  rescue => e
    mark_failed("DaedalusWorker failed: #{e.message}")
    Rails.logger.error("DaedalusWorker error: #{e.message}\n#{e.backtrace.join("\n")}")
    { error: e.message }
  end

  # Initialize worker memory
  def initialize_worker
    store_path = File.join(state_path, "plan_memory.json")
    @research_memory = ResearchMemoryStore.new(path: store_path, owner_id: @owner_id)
    # Store goal in research_goal section (it's an array)
    @research_memory.set_section(:research_goal, [goal])
  end

  private

  # Run codebase analysis workflow
  def run_analysis
    workflow = CodebaseAnalysisWorkflow.new(
      goal: goal,
      path: path,
      owner_id: owner_id,
      parent_memory: @research_memory
    )

    @analysis_results = workflow.execute

    # Store analysis results in findings
    @research_memory.update_section(
      name: :findings,
      content: @analysis_results
    )

    Rails.logger.info("DaedalusWorker: Analysis found #{@analysis_results[:relevant_files].size} relevant files")
  end

  # Run plan generation workflow
  def run_planning
    workflow = PlanGenerationWorkflow.new(
      goal: goal,
      analysis_results: @analysis_results,
      owner_id: owner_id,
      parent_memory: @research_memory,
      context: context[:additional_context]
    )

    @execution_plan = workflow.execute

    # Store execution plan in workflow_outputs
    @research_memory.update_section(
      name: :workflow_outputs,
      content: @execution_plan.to_h
    )

    Rails.logger.info("DaedalusWorker: Generated plan with #{@execution_plan.milestone_count} milestones")
  end

  # Write plan output files
  def write_output_files
    service = PlanOutputService.new(
      execution_plan: @execution_plan,
      base_path: path
    )

    @output_paths = service.write

    # Store output paths in workflow_outputs
    @research_memory.update_section(
      name: :workflow_outputs,
      content: { output_paths: @output_paths }
    )

    Rails.logger.info("DaedalusWorker: Wrote plan to #{@output_paths[:plan_path]}")
  end

  # Build final result hash
  def build_result
    @result = {
      execution_plan: @execution_plan,
      output_paths: @output_paths,
      analysis_summary: {
        relevant_files: @analysis_results[:relevant_files],
        patterns: @analysis_results[:patterns],
        constraints: @analysis_results[:constraints]
      },
      metadata: {
        goal: goal,
        path: path,
        owner_id: owner_id,
        final_state: current_state,
        milestone_count: @execution_plan.milestone_count,
        step_count: @execution_plan.step_count
      }
    }

    # Update metadata with final state
    @result[:metadata][:final_state] = current_state
    @result
  end

  # Mark worker as failed
  def mark_failed(message)
    @error = message
    # Store error in findings section
    @research_memory&.update_section(
      name: :findings,
      content: { error: message, state: current_state, timestamp: Time.now.utc.iso8601 }
    )
    trigger(:fail)
  end

  def validate_init_params!(goal, path)
    raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
    raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
    raise ArgumentError, "goal cannot be empty" if goal.strip.empty?
    raise ArgumentError, "path cannot be empty" if path.strip.empty?
  end

  # Record state transitions to memory
  def record_state_transition_to_memory(from, to, event, payload)
    return unless @research_memory

    @research_memory.record_state_transition(
      from: from,
      to: to,
      event: event,
      payload: payload
    )
  end
end

