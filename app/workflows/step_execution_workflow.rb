# frozen_string_literal: true

# Workflow responsible for executing a single plan step.
# Implements the complete execution pipeline:
# 1. Context Assembly - Determine what codebase context is needed
# 2. Planning - Plan the sequence of tool calls
# 3. Validation - Validate tool parameters before execution
# 4. Execution - Execute tools and record results
# 5. Recording - Build StepResult with actions, diffs, and outputs
#
# @example Execute a step
#   workflow = StepExecutionWorkflow.new(
#     owner_id: worker.owner_id,
#     parent_memory: worker.memory_store
#   )
#   
#   workflow.setup(
#     step: plan_step,
#     path: "/path/to/codebase",
#     context: {},
#     system_prompt: sisyphus_system_prompt
#   )
#   
#   result = workflow.execute
#
class StepExecutionWorkflow < BaseWorkflow
  # Step execution-specific states
  initial_state :pending

  state :pending,            description: "Workflow created"
  state :running,            description: "Workflow started"
  state :assembling_context, description: "Gathering needed context"
  state :planning,           description: "Planning tool call sequence"
  state :validating,         description: "Validating tool parameters"
  state :executing,          description: "Executing tools"
  state :recording,          description: "Recording results"
  state :complete,           description: "Execution complete"
  state :failed,             description: "Execution failed"

  # Define transitions
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :assembling_context, on: :initialized
  transition from: :assembling_context, to: :planning, on: :context_assembled
  transition from: :planning, to: :validating, on: :planned
  transition from: :validating, to: :executing, on: :validated
  transition from: :executing, to: :recording, on: :executed
  transition from: :recording, to: :complete, on: :finish
  transition from: [:running, :assembling_context, :planning, :validating, :executing, :recording],
             to: :failed, on: :fail

  attr_reader :step, :path, :context, :system_prompt,
              :assembled_context, :planned_tools, :validation_results,
              :tool_executions, :diffs

  # Initialize the workflow
  # @param owner_id [String] Parent worker's owner ID
  # @param parent_memory [WorkflowMemoryStore] Parent memory store
  def initialize(owner_id:, parent_memory: nil)
    super(owner_id: owner_id, parent_memory: parent_memory)
    
    @step = nil
    @path = nil
    @context = nil
    @system_prompt = nil
    @assembled_context = {}
    @planned_tools = []
    @validation_results = []
    @tool_executions = []
    @diffs = {}
  end

  # Setup the workflow with step and context
  # @param step [Planning::Step] The step to execute
  # @param path [String] Codebase root path
  # @param context [Hash] Additional context
  # @param system_prompt [Object] System prompt for LLM calls
  # @return [self]
  def setup(step:, path:, context: {}, system_prompt: nil)
    validate_setup_params!(step, path)
    
    @step = step
    @path = path
    @context = context
    @system_prompt = system_prompt

    # Initialize workflow memory
    initialize_workflow_memory if @owner_id

    self
  end

  # Execute the complete step execution pipeline
  # @return [Hash] StepResult data
  def execute
    trigger(:start)
    trigger(:initialized)

    assemble_context
    trigger(:context_assembled)

    plan_tool_sequence
    trigger(:planned)

    validate_tools
    trigger(:validated)

    execute_tools
    trigger(:executed)

    result = record_results
    trigger(:finish)

    # Update metadata with final state
    result[:metadata][:final_state] = current_state
    result
  rescue StandardError => e
    handle_error(e)
  end

  private

  # Validate setup parameters
  def validate_setup_params!(step, path)
    unless step.is_a?(Planning::Step)
      raise TypeError, "step must be a Planning::Step, got #{step.class}"
    end

    unless path.is_a?(String) && !path.empty?
      raise ArgumentError, "path must be a non-empty String, got #{path.inspect}"
    end

    unless File.directory?(path)
      raise ArgumentError, "path must be an existing directory: #{path}"
    end
  end

  # Phase 1: Assemble Context
  # Determine what codebase context is needed for this step
  def assemble_context
    record_decision(
      decision: "assemble_context",
      rationale: "Gathering context for step: #{@step.title}",
      context: { step_number: @step.number }
    )

    # TODO: Implement in Milestone 3 with ContextAssemblyPrompt
    # For now, just record that we're in this phase
    @assembled_context = {
      step_intent: @step.intent,
      step_details: @step.details,
      step_tests: @step.tests,
      codebase_path: @path
    }
  end

  # Phase 2: Plan Tool Sequence
  # Plan the sequence of tool calls needed to accomplish the step
  def plan_tool_sequence
    record_decision(
      decision: "plan_tool_sequence",
      rationale: "Planning tool calls for step: #{@step.title}",
      context: { assembled_context_keys: @assembled_context.keys }
    )

    # TODO: Implement in Milestone 3 with StepPlanningPrompt
    # For now, just record that we're in this phase
    @planned_tools = []
  end

  # Phase 3: Validate Tools
  # Validate each planned tool call before execution
  def validate_tools
    record_decision(
      decision: "validate_tools",
      rationale: "Validating #{@planned_tools.size} planned tool calls",
      context: { tool_count: @planned_tools.size }
    )

    # TODO: Implement in Milestone 3 with ToolValidationPrompt
    # For now, just record that we're in this phase
    @validation_results = []
  end

  # Phase 4: Execute Tools
  # Execute the planned and validated tool calls
  def execute_tools
    record_decision(
      decision: "execute_tools",
      rationale: "Executing tools for step: #{@step.title}",
      context: { validation_warnings: @validation_results.size }
    )

    # TODO: Implement in Milestone 3 with StepExecutionPrompt and ToolCallService
    # For now, just record that we're in this phase
    @tool_executions = []
    @diffs = {}
  end

  # Phase 5: Record Results
  # Build StepResult object with all execution data
  def record_results
    record_decision(
      decision: "record_results",
      rationale: "Recording results for step: #{@step.title}",
      context: {
        tool_executions: @tool_executions.size,
        diffs_generated: @diffs.size
      }
    )

    # TODO: Implement in Milestone 2 with StepResult class
    # For now, return a hash structure
    {
      step_id: @step.number,
      step_title: @step.title,
      success: true,
      actions_taken: @tool_executions,
      files_changed: @diffs.keys,
      diffs: @diffs,
      tool_outputs: {},
      duration: 0.0,
      executed_at: Time.now.utc.iso8601,
      metadata: {
        workflow_id: @workflow_id,
        assembled_context_keys: @assembled_context.keys,
        planned_tool_count: @planned_tools.size,
        validation_warnings: @validation_results.size
      }
    }
  end

  # Handle execution errors
  def handle_error(error)
    Rails.logger.error "[StepExecutionWorkflow] Error in step #{@step&.number}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")

    record_decision(
      decision: "execution_failed",
      rationale: "Step execution failed: #{error.message}",
      context: {
        error_class: error.class.name,
        step_number: @step&.number,
        current_phase: current_state
      }
    )

    mark_failed(error.message)

    {
      step_id: @step&.number,
      step_title: @step&.title,
      success: false,
      error_message: error.message,
      error_class: error.class.name,
      actions_taken: @tool_executions,
      files_changed: [],
      diffs: {},
      metadata: {
        workflow_id: @workflow_id,
        failed_at_phase: current_state,
        final_state: current_state
      }
    }
  end
end

