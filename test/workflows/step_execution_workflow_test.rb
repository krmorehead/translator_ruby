# frozen_string_literal: true

require "test_helper"

class StepExecutionWorkflowTest < ActiveSupport::TestCase
  def setup
    @owner_id = SecureRandom.uuid
    @path = Dir.mktmpdir
    @step = create_test_step
  end

  def teardown
    FileUtils.rm_rf(@path) if @path && File.exist?(@path)
  end

  # Helper to create a test step
  def create_test_step
    Planning::Step.new(
      milestone_number: 1, step_number: 1,
      title: "Create User Model",
      intent: "Define the core user entity with authentication",
      details: [
        "Add email and password_digest fields",
        "Include validation for email uniqueness",
        "Add has_secure_password"
      ],
      tests: [
        "Test user creation with valid attributes",
        "Test email validation",
        "Test password authentication"
      ]
    )
  end

  # ===== Initialization Tests =====
  speed_profile :fast
  test "initializes with owner_id" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

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
    parent_memory = parent_workflow.workflow_memory

    workflow = StepExecutionWorkflow.new(
      owner_id: @owner_id,
      parent_memory: parent_memory
    )

    assert_equal parent_memory, workflow.parent_memory
  end

  speed_profile :fast
  test "initializes state variables" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

    assert_nil workflow.step
    assert_nil workflow.path
    assert_nil workflow.context
    assert_nil workflow.system_prompt
    assert_equal({}, workflow.assembled_context)
    assert_equal([], workflow.planned_tools)
    assert_equal([], workflow.validation_results)
    assert_equal([], workflow.tool_executions)
    assert_equal({}, workflow.diffs)
  end

  # ===== Setup Tests =====

  speed_profile :fast
  test "setup accepts valid parameters" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

    result = workflow.setup(
      step: @step,
      path: @path,
      context: { test: "context" },
      system_prompt: "test prompt"
    )

    assert_equal workflow, result # Returns self for chaining
    assert_equal @step, workflow.step
    assert_equal @path, workflow.path
    assert_equal({ test: "context" }, workflow.context)
    assert_equal "test prompt", workflow.system_prompt
  end

  speed_profile :fast
  test "setup validates step is a Planning::Step" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

    error = assert_raises(TypeError) do
      workflow.setup(step: "not a step", path: @path)
    end

    assert_match(/step must be a Planning::Step/, error.message)
  end

  speed_profile :fast
  test "setup validates path is a non-empty string" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

    error = assert_raises(ArgumentError) do
      workflow.setup(step: @step, path: "")
    end

    assert_match(/path must be a non-empty String/, error.message)
  end

  speed_profile :fast
  test "setup validates path is an existing directory" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

    error = assert_raises(ArgumentError) do
      workflow.setup(step: @step, path: "/nonexistent/path")
    end

    assert_match(/path must be an existing directory/, error.message)
  end

  speed_profile :fast
  test "setup initializes workflow memory" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    assert_not_nil workflow.workflow_memory
    assert_instance_of WorkflowMemoryStore, workflow.workflow_memory
  end

  # ===== State Machine Tests =====

  speed_profile :fast
  test "starts in pending state" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)

    assert workflow.pending?
    assert_equal :pending, workflow.current_state
  end

  speed_profile :fast
  test "transitions through execution phases" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    # pending → running
    workflow.trigger(:start)
    assert workflow.running?

    # running → assembling_context
    workflow.trigger(:initialized)
    assert workflow.in_state?(:assembling_context)

    # assembling_context → planning
    workflow.trigger(:context_assembled)
    assert workflow.in_state?(:planning)

    # planning → validating
    workflow.trigger(:planned)
    assert workflow.in_state?(:validating)

    # validating → executing
    workflow.trigger(:validated)
    assert workflow.in_state?(:executing)

    # executing → recording
    workflow.trigger(:executed)
    assert workflow.in_state?(:recording)

    # recording → complete
    workflow.trigger(:finish)
    assert workflow.complete?
  end

  speed_profile :fast
  test "can transition to failed from any execution phase" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.trigger(:context_assembled)

    # From planning → failed
    workflow.trigger(:fail)
    assert workflow.failed?
  end

  # ===== Execute Method Tests =====

  speed_profile :slow
  test "execute runs through all phases successfully" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    result = workflow.execute

    assert workflow.complete?
    assert result[:success]
    assert_equal "1.1", result[:step_id]
    assert_equal "Create User Model", result[:step_title]
    assert result[:metadata][:final_state]
  end

  speed_profile :slow
  test "execute returns step result structure" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    result = workflow.execute

    # Verify result structure
    assert_includes result, :step_id
    assert_includes result, :step_title
    assert_includes result, :success
    assert_includes result, :actions_taken
    assert_includes result, :files_changed
    assert_includes result, :diffs
    assert_includes result, :tool_outputs
    assert_includes result, :duration
    assert_includes result, :executed_at
    assert_includes result, :metadata
  end

  speed_profile :slow
  test "execute records decisions to workflow memory" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.execute

    decisions = workflow.workflow_memory.get_section(:decisions)
    assert decisions.any?
    assert decisions.all? { |d| d.is_a?(WorkflowMemories::Decision) }

    # Check for key decision points
    decision_names = decisions.map(&:decision)
    assert_includes decision_names, "assemble_context"
    assert_includes decision_names, "plan_tool_sequence"
    assert_includes decision_names, "validate_tools"
    assert_includes decision_names, "execute_tools"
    assert_includes decision_names, "record_results"
  end

  speed_profile :slow
  test "execute handles errors gracefully" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    # Force an error by stubbing a method
    workflow.define_singleton_method(:assemble_context) do
      raise StandardError, "Test error"
    end

    result = workflow.execute

    assert workflow.failed?
    refute result[:success]
    assert_equal "Test error", result[:error_message]
    assert_equal "StandardError", result[:error_class]
    assert_includes result[:metadata], :failed_at_phase
  end

  # ===== Context Assembly Phase Tests =====

  speed_profile :slow
  test "assemble_context records decision" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)

    decisions = workflow.workflow_memory.get_section(:decisions)
    context_decision = decisions.find { |d| d[:decision] == "assemble_context" }

    assert_not_nil context_decision
    assert_includes context_decision[:rationale], "Create User Model"
  end

  speed_profile :slow
  test "assemble_context populates assembled_context" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)

    assert_not_empty workflow.assembled_context
    assert_equal @step.intent, workflow.assembled_context[:step_intent]
    assert_equal @step.details, workflow.assembled_context[:step_details]
    assert_equal @step.tests, workflow.assembled_context[:step_tests]
    assert_equal @path, workflow.assembled_context[:codebase_path]
  end

  # ===== Planning Phase Tests =====

  speed_profile :slow
  test "plan_tool_sequence records decision" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)
    workflow.trigger(:context_assembled)
    workflow.send(:plan_tool_sequence)

    decisions = workflow.workflow_memory.get_section(:decisions)
    planning_decision = decisions.find { |d| d[:decision] == "plan_tool_sequence" }

    assert_not_nil planning_decision
    assert_includes planning_decision[:rationale], "Planning tool calls"
  end

  # ===== Validation Phase Tests =====

  speed_profile :slow
  test "validate_tools records decision" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)
    workflow.trigger(:context_assembled)
    workflow.send(:plan_tool_sequence)
    workflow.trigger(:planned)
    workflow.send(:validate_tools)

    decisions = workflow.workflow_memory.get_section(:decisions)
    validation_decision = decisions.find { |d| d[:decision] == "validate_tools" }

    assert_not_nil validation_decision
    assert_includes validation_decision[:rationale], "Validating"
  end

  # ===== Execution Phase Tests =====

  speed_profile :slow
  test "execute_tools records decision" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)
    workflow.trigger(:context_assembled)
    workflow.send(:plan_tool_sequence)
    workflow.trigger(:planned)
    workflow.send(:validate_tools)
    workflow.trigger(:validated)
    workflow.send(:execute_tools)

    decisions = workflow.workflow_memory.get_section(:decisions)
    execution_decision = decisions.find { |d| d[:decision] == "execute_tools" }

    assert_not_nil execution_decision
    assert_includes execution_decision[:rationale], "Executing tools"
  end

  # ===== Recording Phase Tests =====

  speed_profile :slow
  test "record_results builds complete result structure" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)
    workflow.trigger(:context_assembled)
    workflow.send(:plan_tool_sequence)
    workflow.trigger(:planned)
    workflow.send(:validate_tools)
    workflow.trigger(:validated)
    workflow.send(:execute_tools)
    workflow.trigger(:executed)

    result = workflow.send(:record_results)

    assert_equal "1.1", result[:step_id]
    assert_equal "Create User Model", result[:step_title]
    assert result[:success]
    assert_instance_of Array, result[:actions_taken]
    assert_instance_of Array, result[:files_changed]
    assert_instance_of Hash, result[:diffs]
    assert_instance_of Hash, result[:tool_outputs]
    assert_instance_of Hash, result[:metadata]
  end

  speed_profile :slow
  test "record_results includes metadata about execution" do
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id)
    workflow.setup(step: @step, path: @path)

    workflow.trigger(:start)
    workflow.trigger(:initialized)
    workflow.send(:assemble_context)
    workflow.trigger(:context_assembled)
    workflow.send(:plan_tool_sequence)
    workflow.trigger(:planned)
    workflow.send(:validate_tools)
    workflow.trigger(:validated)
    workflow.send(:execute_tools)
    workflow.trigger(:executed)

    result = workflow.send(:record_results)

    assert_equal workflow.workflow_id, result[:metadata][:workflow_id]
    assert_includes result[:metadata], :assembled_context_keys
    assert_includes result[:metadata], :planned_tool_count
    assert_includes result[:metadata], :validation_warnings
  end

  # ===== Workflow Name Tests =====

  speed_profile :fast
  test "workflow_name returns correct value" do
    assert_equal "step_execution_workflow", StepExecutionWorkflow.workflow_name
  end
end

