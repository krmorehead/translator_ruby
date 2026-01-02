# frozen_string_literal: true

require "test_helper"

class StepEvaluationWorkflowTest < ActiveSupport::TestCase
  def setup
    @owner_id = SecureRandom.uuid
    @path = Dir.mktmpdir
    @step = create_test_step
    @successful_result = create_successful_step_result
    @failed_result = create_failed_step_result
  end

  def teardown
    FileUtils.rm_rf(@path) if @path && File.exist?(@path)
  end

  # Helper to create a test step
  def create_test_step
    Planning::Step.new(
      milestone_number: 1, step_number: 1,
      title: "Create User Model",
      intent: "Define the core user entity",
      details: ["Add email field", "Add password field"],
      tests: ["Test user creation", "Test validations"]
    )
  end

  # Helper to create a successful step result
  def create_successful_step_result
    {
      step_id: "1.1",
      step_title: "Create User Model",
      success: true,
      actions_taken: [{ tool: "write_file", params: {} }],
      files_changed: ["app/models/user.rb"],
      diffs: { "app/models/user.rb" => "+class User\n+end" },
      tool_outputs: { test_run: "All tests passed" },
      duration: 1.5,
      executed_at: Time.now.utc.iso8601,
      metadata: { workflow_id: SecureRandom.uuid }
    }
  end

  # Helper to create a failed step result
  def create_failed_step_result
    {
      step_id: "1.1",
      step_title: "Create User Model",
      success: false,
      error_message: "File write failed",
      actions_taken: [],
      files_changed: [],
      diffs: {},
      tool_outputs: {},
      metadata: { workflow_id: SecureRandom.uuid }
    }
  end

  # ===== Initialization Tests =====
  speed_profile :fast
  test "initializes with owner_id" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    assert_equal @owner_id, workflow.owner_id
    assert_not_nil workflow.workflow_id
    assert workflow.pending?
  end

  speed_profile :fast
  test "initializes with parent_memory" do
    # Create a REAL parent workflow instance (not a mock)
    parent_workflow = ResearchWorkflow.new(
      goal: "parent workflow goal",
      research_path: @path,
      owner_id: @owner_id
    )
    
    # Use the real workflow's memory store
    parent_memory = parent_workflow.workflow_memory

    workflow = StepEvaluationWorkflow.new(
      owner_id: @owner_id,
      parent_memory: parent_memory
    )

    assert_equal parent_memory, workflow.parent_memory
  end

  speed_profile :fast
  test "initializes state variables" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    assert_nil workflow.step
    assert_nil workflow.step_result
    assert_nil workflow.path
    assert_nil workflow.system_prompt
    assert_nil workflow.evaluation_result
  end

  # ===== Setup Tests =====

  speed_profile :fast
  test "setup accepts valid parameters" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    result = workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path,
      system_prompt: "test prompt"
    )

    assert_equal workflow, result # Returns self for chaining
    assert_equal @step, workflow.step
    assert_equal @successful_result, workflow.step_result
    assert_equal @path, workflow.path
    assert_equal "test prompt", workflow.system_prompt
  end

  speed_profile :fast
  test "setup validates step is a Planning::Step" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    error = assert_raises(TypeError) do
      workflow.setup(
        step: "not a step",
        step_result: @successful_result,
        path: @path
      )
    end

    assert_match(/step must be a Planning::Step/, error.message)
  end

  speed_profile :fast
  test "setup validates step_result is a Hash" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    error = assert_raises(TypeError) do
      workflow.setup(
        step: @step,
        step_result: "not a hash",
        path: @path
      )
    end

    assert_match(/step_result must be a Hash/, error.message)
  end

  speed_profile :fast
  test "setup validates step_result contains step_id" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    error = assert_raises(ArgumentError) do
      workflow.setup(
        step: @step,
        step_result: { success: true },
        path: @path
      )
    end

    assert_match(/step_result must contain :step_id key/, error.message)
  end

  speed_profile :fast
  test "setup validates path is a non-empty string" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    error = assert_raises(ArgumentError) do
      workflow.setup(
        step: @step,
        step_result: @successful_result,
        path: ""
      )
    end

    assert_match(/path must be a non-empty String/, error.message)
  end

  speed_profile :fast
  test "setup validates path is an existing directory" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    error = assert_raises(ArgumentError) do
      workflow.setup(
        step: @step,
        step_result: @successful_result,
        path: "/nonexistent/path"
      )
    end

    assert_match(/path must be an existing directory/, error.message)
  end

  speed_profile :fast
  test "setup initializes workflow memory" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    assert_not_nil workflow.workflow_memory
    assert_instance_of WorkflowMemoryStore, workflow.workflow_memory
  end

  # ===== State Machine Tests =====

  speed_profile :fast
  test "starts in pending state" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)

    assert workflow.pending?
    assert_equal :pending, workflow.current_state
  end

  speed_profile :fast
  test "transitions through evaluation phases" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    # pending → running
    workflow.trigger(:start)
    assert workflow.running?

    # running → evaluating
    workflow.trigger(:initialized)
    assert workflow.in_state?(:evaluating)

    # evaluating → complete
    workflow.trigger(:finish)
    assert workflow.complete?
  end

  speed_profile :fast
  test "can transition to failed from evaluation phases" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    # From evaluating → failed
    workflow.trigger(:fail)
    assert workflow.failed?
  end

  # ===== Execute Method Tests =====

  speed_profile :fast
  test "execute evaluates successful step result" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    evaluation = workflow.execute

    assert workflow.complete?
    assert evaluation[:passed]
    assert_equal "1.1", evaluation[:step_id]
    assert_equal "Create User Model", evaluation[:step_title]
    assert evaluation[:confidence] > 0.5
    assert_not_nil evaluation[:feedback]
    assert evaluation[:feedback].length > 0, "Feedback should not be empty"
    refute evaluation[:should_retry]
  end

  speed_profile :slow
  test "execute evaluates failed step result" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @failed_result,
      path: @path
    )

    evaluation = workflow.execute

    assert workflow.complete?
    refute evaluation[:passed]
    assert_equal "1.1", evaluation[:step_id]
    assert evaluation[:confidence] < 0.5
    assert_includes evaluation[:feedback], "failed"
    assert evaluation[:should_retry]
  end

  speed_profile :slow
  test "execute returns complete evaluation structure" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    evaluation = workflow.execute

    # Verify evaluation structure
    assert_includes evaluation, :step_id
    assert_includes evaluation, :step_title
    assert_includes evaluation, :passed
    assert_includes evaluation, :confidence
    assert_includes evaluation, :feedback
    assert_includes evaluation, :missing_requirements
    assert_includes evaluation, :concerns
    assert_includes evaluation, :should_retry
    assert_includes evaluation, :evaluated_at
    assert_includes evaluation, :metadata
  end

  speed_profile :slow
  test "execute records decisions to workflow memory" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    workflow.execute

    decisions = workflow.workflow_memory.get_section(:decisions)
    assert decisions.any?
    assert decisions.all? { |d| d.is_a?(WorkflowMemories::Decision) }

    # Check for key decision points
    decision_names = decisions.map(&:decision)
    assert_includes decision_names, "evaluate_step_completion"
    assert_includes decision_names, "evaluation_complete"
  end

  speed_profile :slow
  test "execute handles errors gracefully" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    # Force an error
    workflow.define_singleton_method(:evaluate_step_completion) do
      raise StandardError, "Test error"
    end

    evaluation = workflow.execute

    assert workflow.failed?
    refute evaluation[:passed]
    assert_equal "Test error", evaluation[:error_message]
    assert_equal "StandardError", evaluation[:error_class]
    assert evaluation[:should_retry]
  end

  # ===== Basic Evaluation Tests =====

  speed_profile :slow
  test "basic_evaluation passes for successful execution" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    result = workflow.send(:basic_evaluation)

    assert result[:passed]
    assert result[:confidence] > 0.5
    assert_instance_of String, result[:feedback]
    assert_instance_of Array, result[:missing_requirements]
    assert_instance_of Array, result[:concerns]
  end

  speed_profile :slow
  test "basic_evaluation fails for failed execution" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @failed_result,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    result = workflow.send(:basic_evaluation)

    refute result[:passed]
    assert result[:confidence] < 0.5
    assert_includes result[:feedback], "failed"
    assert result[:should_retry]
  end

  speed_profile :slow
  test "basic_evaluation adds concern when tests defined but no outputs" do
    result_without_outputs = @successful_result.dup
    result_without_outputs[:tool_outputs] = {}

    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: result_without_outputs,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    result = workflow.send(:basic_evaluation)

    assert result[:concerns].any?
    assert result[:concerns].any? { |c| c.include?("test outputs") }
  end

  speed_profile :slow
  test "basic_evaluation adds concern when details suggest modifications but no files changed" do
    result_no_files = @successful_result.dup
    result_no_files[:files_changed] = []

    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: result_no_files,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    result = workflow.send(:basic_evaluation)

    assert result[:concerns].any?
    assert result[:concerns].any? { |c| c.include?("no files were changed") }
  end

  # ===== Evaluation Result Building Tests =====

  speed_profile :slow
  test "build_evaluation_result includes all required fields" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    basic_eval = workflow.send(:basic_evaluation)
    result = workflow.send(:build_evaluation_result, basic_eval)

    assert_equal "1.1", result[:step_id]
    assert_equal "Create User Model", result[:step_title]
    assert_equal basic_eval[:passed], result[:passed]
    assert_equal basic_eval[:confidence], result[:confidence]
    assert_equal basic_eval[:feedback], result[:feedback]
    assert_instance_of String, result[:evaluated_at]
    assert_instance_of Hash, result[:metadata]
  end

  speed_profile :slow
  test "build_evaluation_result includes metadata about execution" do
    workflow = StepEvaluationWorkflow.new(owner_id: @owner_id)
    workflow.setup(
      step: @step,
      step_result: @successful_result,
      path: @path
    )

    workflow.trigger(:start)
    workflow.trigger(:initialized)

    basic_eval = workflow.send(:basic_evaluation)
    result = workflow.send(:build_evaluation_result, basic_eval)

    assert_equal workflow.workflow_id, result[:metadata][:workflow_id]
    assert_equal true, result[:metadata][:execution_success]
    assert_equal 1, result[:metadata][:files_changed_count]
  end

  # ===== Workflow Name Tests =====

  speed_profile :slow
  test "workflow_name returns correct value" do
    assert_equal "step_evaluation_workflow", StepEvaluationWorkflow.workflow_name
  end
end

