# frozen_string_literal: true

# Workflow that evaluates whether a step has been successfully completed.
# Provides quality control before moving to the next step.
#
# Evaluates based on:
# - Were the step's tests satisfied?
# - Are files modified correctly?
# - Are requirements met?
# - Are there errors or warnings?
# - Is code quality acceptable?
#
# @example Evaluate a step
#   workflow = StepEvaluationWorkflow.new(
#     owner_id: worker.owner_id,
#     parent_memory: worker.memory_store
#   )
#   
#   workflow.setup(
#     step: plan_step,
#     step_result: execution_result,
#     path: "/path/to/codebase",
#     system_prompt: sisyphus_system_prompt
#   )
#   
#   evaluation = workflow.execute
#
class StepEvaluationWorkflow < BaseWorkflow
  # Evaluation-specific states
  initial_state :pending

  state :pending,    description: "Workflow created"
  state :running,    description: "Workflow started"
  state :evaluating, description: "Evaluating step completion"
  state :complete,   description: "Evaluation complete"
  state :failed,     description: "Evaluation failed"

  # Define transitions
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :evaluating, on: :initialized
  transition from: :evaluating, to: :complete, on: :finish
  transition from: [:running, :evaluating], to: :failed, on: :fail

  attr_reader :step, :step_result, :path, :system_prompt, :evaluation_result

  # Initialize the workflow
  # @param owner_id [String] Parent worker's owner ID
  # @param parent_memory [WorkflowMemoryStore] Parent memory store
  def initialize(owner_id:, parent_memory: nil)
    super(owner_id: owner_id, parent_memory: parent_memory)
    
    @step = nil
    @step_result = nil
    @path = nil
    @system_prompt = nil
    @evaluation_result = nil
  end

  # Setup the workflow with step and result
  # @param step [Planning::Step] The step that was executed
  # @param step_result [Hash] The execution result from StepExecutionWorkflow
  # @param path [String] Codebase root path
  # @param system_prompt [Object] System prompt for LLM calls
  # @return [self]
  def setup(step:, step_result:, path:, system_prompt: nil)
    validate_setup_params!(step, step_result, path)
    
    @step = step
    @step_result = step_result
    @path = path
    @system_prompt = system_prompt

    # Initialize workflow memory
    initialize_workflow_memory if @owner_id

    self
  end

  # Execute the evaluation
  # @return [Hash] Evaluation result with pass/fail, feedback, and confidence
  def execute
    trigger(:start)
    trigger(:initialized)

    result = evaluate_step_completion
    
    # Build result before final transition
    evaluation = build_evaluation_result(result)
    trigger(:finish)

    # Update metadata with final state
    evaluation[:metadata][:final_state] = current_state
    evaluation
  rescue StandardError => e
    handle_error(e)
  end

  private

  # Validate setup parameters
  def validate_setup_params!(step, step_result, path)
    unless step.is_a?(Planning::Step)
      raise TypeError, "step must be a Planning::Step, got #{step.class}"
    end

    unless step_result.is_a?(Hash)
      raise TypeError, "step_result must be a Hash, got #{step_result.class}"
    end

    unless step_result.key?(:step_id)
      raise ArgumentError, "step_result must contain :step_id key"
    end

    unless path.is_a?(String) && !path.empty?
      raise ArgumentError, "path must be a non-empty String, got #{path.inspect}"
    end

    unless File.directory?(path)
      raise ArgumentError, "path must be an existing directory: #{path}"
    end
  end

  # Evaluate step completion
  # Uses LLM to assess whether step objectives were met
  def evaluate_step_completion
    record_decision(
      decision: "evaluate_step_completion",
      rationale: "Evaluating completion of step: #{@step.title}",
      context: {
        step_number: @step.number,
        execution_success: @step_result[:success],
        files_changed: @step_result[:files_changed]&.size || 0,
        has_diffs: @step_result[:diffs]&.any? || false
      }
    )

    # Use StepEvaluationPrompt for LLM-based evaluation
    prompt = Execution::StepEvaluationPrompt.new(
      step: @step,
      step_result: @step_result,
      context: {}
    )

    user_message = <<~MSG
      I executed this step:

      **Step**: #{@step.title}
      **Intent**: #{@step.intent}

      **Expected Details**:
      #{@step.details.map { |d| "- #{d}" }.join("\n")}

      **Test Requirements**:
      #{@step.tests.map { |t| "- #{t}" }.join("\n")}

      **Execution Results**:
      - Success: #{@step_result[:success]}
      - Actions Taken: #{@step_result[:actions_taken]&.size || 0}
      - Files Changed: #{@step_result[:files_changed]&.size || 0}
      #{@step_result[:error_message] ? "- Error: #{@step_result[:error_message]}" : ""}

      Did this step successfully accomplish its objectives?
    MSG

    result = prompt.execute(prompt: user_message, context: nil)

    # Return the evaluation from LLM
    result[:content]
  end

  # Basic evaluation without LLM (placeholder)
  # Checks if execution was successful and basic requirements met
  def basic_evaluation
    passed = @step_result[:success] == true
    
    feedback = if passed
      "Step executed successfully. All actions completed without errors."
    else
      "Step execution failed: #{@step_result[:error_message]}"
    end

    missing_requirements = []
    concerns = []

    # Check if step has tests defined but no test outputs
    if @step.tests.any? && @step_result[:tool_outputs].empty?
      concerns << "Step defines tests but no test outputs were recorded"
    end

    # Check if step details suggest file modifications but none occurred
    if @step.details.any? { |d| d.downcase.include?("create") || d.downcase.include?("add") }
      if @step_result[:files_changed].empty?
        concerns << "Step suggests file modifications but no files were changed"
      end
    end

    {
      passed: passed,
      confidence: passed ? 0.8 : 0.2,
      feedback: feedback,
      missing_requirements: missing_requirements,
      concerns: concerns,
      should_retry: !passed
    }
  end

  # Build the complete evaluation result
  def build_evaluation_result(evaluation)
    record_decision(
      decision: "evaluation_complete",
      rationale: "Evaluation #{evaluation[:passed] ? 'passed' : 'failed'} with confidence #{evaluation[:confidence]}",
      context: {
        passed: evaluation[:passed],
        confidence: evaluation[:confidence],
        concerns_count: evaluation[:concerns].size
      }
    )

    {
      step_id: @step.number,
      step_title: @step.title,
      passed: evaluation[:passed],
      confidence: evaluation[:confidence],
      feedback: evaluation[:feedback],
      missing_requirements: evaluation[:missing_requirements],
      concerns: evaluation[:concerns],
      should_retry: evaluation[:should_retry],
      evaluated_at: Time.now.utc.iso8601,
      metadata: {
        workflow_id: @workflow_id,
        execution_success: @step_result[:success],
        files_changed_count: @step_result[:files_changed]&.size || 0
      }
    }
  end

  # Handle evaluation errors
  def handle_error(error)
    Rails.logger.error "[StepEvaluationWorkflow] Error evaluating step #{@step&.number}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")

    record_decision(
      decision: "evaluation_failed",
      rationale: "Evaluation failed: #{error.message}",
      context: {
        error_class: error.class.name,
        step_number: @step&.number
      }
    )

    mark_failed(error.message)

    {
      step_id: @step&.number,
      step_title: @step&.title,
      passed: false,
      confidence: 0.0,
      feedback: "Evaluation failed due to error: #{error.message}",
      missing_requirements: [],
      concerns: ["Evaluation workflow encountered an error"],
      should_retry: true,
      error_message: error.message,
      error_class: error.class.name,
      metadata: {
        workflow_id: @workflow_id,
        failed: true,
        final_state: current_state
      }
    }
  end
end

