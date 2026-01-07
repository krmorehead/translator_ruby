# frozen_string_literal: true

# Daedalus - The master architect and planner of Greek mythology.
# This worker generates structured execution plans by exploring the codebase.
# Named after Daedalus, the legendary craftsman who built the Labyrinth and
# designed wings that could fly - a fitting symbol for careful planning and execution.
#
# Inspired by Cline's "Plan Mode" - tools are used directly during planning
# rather than in a separate analysis phase.
#
# Flow (following Cline pattern):
# 1. Generate plan with embedded codebase exploration
# 2. Write output files (PlanOutputService)
#
# @example
#   worker = DaedalusWorker.new(
#     goal: "Create a new feature",
#     path: "/path/to/codebase",
#     context: Contexts::BaseContext.new
#   )
#   result = worker.execute
#   puts result[:output_paths][:plan_path]
#
class DaedalusWorker < BaseWorker
  attr_reader :research_memory, :execution_plan, :output_paths, :path

  # Register workflows this worker uses
  register_workflow PlanGenerationWorkflow

  # Following Cline pattern: Tools are used by LLM during planning
  # No need to register them at worker level - they're accessed via GenericLLMClient

  # Plan-specific states (extends base worker)
  initial_state :pending

  state :pending,     description: "Worker created"
  state :running,     description: "Initializing"
  state :planning,    description: "Generating plan with codebase exploration"
  state :writing,     description: "Writing output files"
  state :complete,    description: "Completed"
  state :failed,      description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :planning, on: :initialized
  transition from: :planning, to: :writing, on: :planned
  transition from: :writing, to: :complete, on: :finish
  transition from: [:running, :planning, :writing], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # @param goal [String] What to accomplish
  # @param path [String] Codebase root
  # @param context [Contexts::BaseContext] Context for planning
  def initialize(goal:, path:, context:, **options)
    validate_init_params!(goal, path)
    super(goal: goal, context: context, **options)

    @path = path
    @research_memory = nil
    @execution_plan = nil
    @output_paths = nil
  end

  # Process a chat message using exploration tools
  # @param content [String] User's message
  # @param conversation_history [Array<Hash>] Previous messages
  # @return [Hash] Result with :content, :tool_calls, :file_changes
  def process_message(content:, conversation_history: [])
    # Ensure worker is initialized
    initialize_worker unless @research_memory
    
    # Use DaedalusChatPrompt with exploration tools
    prompt = Planning::DaedalusChatPrompt.new(
      path: @path,
      conversation_history: conversation_history
    )
    
    # Prompt handles tool calling loop internally
    result = prompt.execute_with_tools(user_message: content)
    
    {
      success: true,
      content: result[:content],
      tool_calls: result[:tool_calls],
      file_changes: []
    }
  rescue => e
    Rails.logger.error("DaedalusWorker message processing error: #{e.message}\n#{e.backtrace.join("\n")}")
    {
      success: false,
      error: e.message,
      content: "Error processing message: #{e.message}",
      tool_calls: [],
      file_changes: []
    }
  end

  # Execute the full planning pipeline
  # Following Cline: tools are used directly during planning
  # @return [Hash] Result with execution_plan, output_paths, metadata
  def execute
    trigger(:start)
    initialize_worker

    # Phase 1: Generate plan (with embedded codebase exploration)
    trigger(:initialized)
    run_planning

    # Phase 2: Write output files
    trigger(:planned)
    write_output_files

    # Complete
    trigger(:finish)
    build_result
  rescue => e
    handle_error(e)
  end

  # Initialize worker memory
  def initialize_worker
    @research_memory = ResearchMemoryStore.new(
      workflow_id: @owner_id,
      workflow_name: "daedalus_worker",
      parent_id: @owner_id,  # Workers are root, so parent is self
      owner_id: @owner_id
    )
    # Store goal in research_goal section (it's an array)
    @research_memory.set_section(:research_goal, [goal])

    Rails.logger.info("DaedalusWorker: Initialized with goal: #{goal}")
  end

  private

  # Generate plan using PlanGenerationWorkflow
  # Following Cline: workflow uses tools directly to explore codebase as needed
  # No separate analysis phase - exploration happens during planning
  def run_planning
    workflow = PlanGenerationWorkflow.new(
      goal: goal,
      path: @path,  # Pass path for codebase exploration
      owner_id: owner_id,
      parent_id: @research_memory.workflow_id,
      context: context
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
      base_path: AgentConfig.data_path
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
      success: true,
      execution_plan: @execution_plan,
      output_paths: @output_paths,
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

  # Handle errors during execution
  def handle_error(error)
    mark_failed("DaedalusWorker failed: #{error.message}")
    Rails.logger.error("DaedalusWorker error: #{error.message}\n#{error.backtrace.join("\n")}")
    { success: false, error: error.message }
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

