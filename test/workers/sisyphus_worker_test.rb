# frozen_string_literal: true

require "test_helper"

class SisyphusWorkerTest < ActiveSupport::TestCase
  let(:worker_context) { Contexts::BaseContext.new }

  def setup
    @path = create_temp_git_repo
    @execution_plan = create_test_plan
  end

  def teardown
    FileUtils.rm_rf(@path) if @path && File.exist?(@path)
  end

  # Helper to create a test execution plan
  def create_test_plan
    milestone = Planning::Milestone.new(
      number: 1,
      title: "Test Milestone",
      description: "A test milestone for Sisyphus"
    )

    step = Planning::Step.new(
      milestone_number: 1, step_number: 1,
      title: "Test Step",
      intent: "Test the worker",
      details: ["Do something"],
      tests: ["Verify it works"]
    )

    milestone.add_step(step)

    Planning::Result.new(
      goal: "Test Goal",
      project_name: "test_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "# Test References",
      project_plan_content: "# Test Plan"
    )
  end

  # ===== Initialization Tests =====
  speed_profile :fast
  test "initializes with valid execution plan" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    assert_equal @execution_plan, worker.execution_plan
    assert_equal @path, worker.path
    assert_equal "Test Goal", worker.goal
    assert_equal :autonomous, worker.config.approval_mode
    assert_equal 3, worker.config.max_retries
    assert worker.config.stream_progress
    assert_equal :lenient, worker.config.error_mode
  end

  speed_profile :fast
  test "validates execution_plan is a Planning::Result" do
    error = assert_raises(TypeError) do
      SisyphusWorker.new(
        execution_plan: "not a plan",
        path: @path,
        context: worker_context
      )
    end

    assert_match(/execution_plan must be a Planning::Result/, error.message)
  end

  speed_profile :fast
  test "accepts custom configuration" do
    config = Configuration::SisyphusConfig.new(
      approval_mode: :step,
      max_retries: 5,
      stream_progress: false,
      error_mode: :strict,
      dry_run: false
    )

    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context,
      config: config
    )

    assert_equal :step, worker.config.approval_mode
    assert_equal 5, worker.config.max_retries
    refute worker.config.stream_progress
    assert_equal :strict, worker.config.error_mode
  end

  speed_profile :fast
  test "validates approval_mode is valid" do
    error = assert_raises(ArgumentError) do
      Configuration::SisyphusConfig.new(
        approval_mode: :invalid,
        max_retries: 3,
        stream_progress: true,
        error_mode: :lenient,
        dry_run: false
      )
    end

    assert_match(/approval_mode must be one of/, error.message)
  end

  speed_profile :fast
  test "validates max_retries is positive integer" do
    error = assert_raises(ArgumentError) do
      Configuration::SisyphusConfig.new(
        approval_mode: :autonomous,
        max_retries: -1,
        stream_progress: true,
        error_mode: :lenient,
        dry_run: false
      )
    end

    assert_match(/max_retries must be positive/, error.message)
  end

  speed_profile :fast
  test "validates error_mode is valid" do
    error = assert_raises(ArgumentError) do
      Configuration::SisyphusConfig.new(
        approval_mode: :autonomous,
        max_retries: 3,
        stream_progress: true,
        error_mode: :invalid,
        dry_run: false
      )
    end

    assert_match(/error_mode must be/, error.message)
  end

  # ===== State Machine Tests =====

  speed_profile :fast
  test "initializes in pending state" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    assert worker.pending?
    assert_equal :pending, worker.current_state
  end

  speed_profile :fast
  test "transitions through execution lifecycle states" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    # pending → running
    worker.trigger(:start)
    assert worker.running?

    # running → executing
    worker.trigger(:initialized)
    assert worker.in_state?(:executing)

    # executing → evaluating
    worker.trigger(:executed)
    assert worker.in_state?(:evaluating)

    # evaluating → checkpoint_created
    worker.trigger(:checkpoint)
    assert worker.in_state?(:checkpoint_created)

    # checkpoint_created → complete
    worker.trigger(:finish)
    assert worker.complete?
  end

  speed_profile :fast
  test "transitions to error_recovery on error" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.trigger(:start)
    worker.trigger(:initialized)
    worker.trigger(:error)

    assert worker.in_state?(:error_recovery)
  end

  speed_profile :fast
  test "transitions from error_recovery to executing on recovered" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.trigger(:start)
    worker.trigger(:initialized)
    worker.trigger(:error)
    assert worker.in_state?(:error_recovery)

    worker.trigger(:recovered)
    assert worker.in_state?(:executing)
  end

  speed_profile :fast
  test "transitions from error_recovery to failed on fail" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.trigger(:start)
    worker.trigger(:initialized)
    worker.trigger(:error)
    worker.trigger(:fail)

    assert worker.failed?
  end

  speed_profile :fast
  test "supports streaming_progress state" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.trigger(:start)
    worker.trigger(:initialized)
    worker.trigger(:stream)

    assert worker.in_state?(:streaming_progress)

    worker.trigger(:resume)
    assert worker.in_state?(:executing)
  end

  # ===== Milestone and Step Navigation Tests =====

  speed_profile :fast
  test "current_milestone returns first milestone initially" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    assert_equal "Test Milestone", worker.current_milestone.title
    assert_equal 1, worker.current_milestone.number
  end

  speed_profile :fast
  test "current_step returns first step initially" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    assert_equal "Test Step", worker.current_step.title
    assert_equal "1.1", worker.current_step.number
  end

  speed_profile :fast
  test "current_milestone returns nil when past last milestone" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.instance_variable_set(:@current_milestone_index, 999)

    assert_nil worker.current_milestone
  end

  speed_profile :fast
  test "current_step returns nil when past last step in milestone" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.instance_variable_set(:@current_step_index, 999)

    assert_nil worker.current_step
  end

  # ===== Progress Calculation Tests =====

  speed_profile :fast
  test "progress_percentage starts at 0" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    assert_equal 0.0, worker.progress_percentage
  end

  speed_profile :fast
  test "progress_percentage calculates correctly for single step plan" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    # Move to step 1
    worker.instance_variable_set(:@current_step_index, 1)

    # Should be 100% (1 step complete out of 1 total)
    assert_equal 100.0, worker.progress_percentage
  end

  speed_profile :fast
  test "progress_percentage calculates correctly for multi-milestone plan" do
    # Create plan with 2 milestones, 2 steps each
    milestone1 = Planning::Milestone.new(number: 1, title: "M1", description: "First")
    milestone1.add_step(Planning::Step.new(
      milestone_number: 1, step_number: 1, title: "S1", intent: "First step",
      details: ["Do thing"], tests: ["Test thing"]
    ))
    milestone1.add_step(Planning::Step.new(
      milestone_number: 1, step_number: 2, title: "S2", intent: "Second step",
      details: ["Do thing"], tests: ["Test thing"]
    ))

    milestone2 = Planning::Milestone.new(number: 2, title: "M2", description: "Second")
    milestone2.add_step(Planning::Step.new(
      milestone_number: 2, step_number: 1, title: "S3", intent: "Third step",
      details: ["Do thing"], tests: ["Test thing"]
    ))
    milestone2.add_step(Planning::Step.new(
      milestone_number: 2, step_number: 2, title: "S4", intent: "Fourth step",
      details: ["Do thing"], tests: ["Test thing"]
    ))

    plan = Planning::Result.new(
      goal: "Multi-milestone test",
      project_name: "multi_test",
      milestones: [milestone1, milestone2],
      existing_files: [],
      planned_files: [],
      file_references_content: "# Refs",
      project_plan_content: "# Plan"
    )

    worker = SisyphusWorker.new(execution_plan: plan, path: @path, context: worker_context)

    # At start: 0/4 = 0%
    assert_equal 0.0, worker.progress_percentage

    # After first step: 1/4 = 25%
    worker.instance_variable_set(:@current_step_index, 1)
    assert_equal 25.0, worker.progress_percentage

    # After first milestone: 2/4 = 50%
    worker.instance_variable_set(:@current_milestone_index, 1)
    worker.instance_variable_set(:@current_step_index, 0)
    assert_equal 50.0, worker.progress_percentage

    # After third step: 3/4 = 75%
    worker.instance_variable_set(:@current_step_index, 1)
    assert_equal 75.0, worker.progress_percentage
  end

  # ===== Progress Streaming Tests =====

  speed_profile :fast
  test "emit_progress adds event to stream when enabled" do
    config = Configuration::SisyphusConfig.new(
      approval_mode: :autonomous,
      max_retries: 3,
      stream_progress: true,
      error_mode: :lenient,
      dry_run: false
    )

    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context,
      config: config
    )

    # Initialize to create progress stream
    worker.trigger(:start)
    worker.send(:initialize_execution)

    worker.emit_progress(:test_event, { message: "test" })

    stream = worker.progress_stream
    assert_equal 2, stream.size # initialization event + test event

    event = stream.last
    assert_equal :test_event, event[:event_type]
    assert_equal "test", event[:data][:message]
    assert_equal "Test Milestone", event[:data][:milestone]
    assert_equal "Test Step", event[:data][:step]
    assert event[:timestamp]
  end

  speed_profile :fast
  test "emit_progress does nothing when streaming disabled" do
    config = Configuration::SisyphusConfig.new(
      approval_mode: :autonomous,
      max_retries: 3,
      stream_progress: false,
      error_mode: :lenient,
      dry_run: false
    )

    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context,
      config: config
    )

    worker.trigger(:start)
    worker.send(:initialize_execution)

    worker.emit_progress(:test_event, { message: "test" })

    assert_nil worker.progress_stream
  end

  # ===== Memory Store Tests =====

  speed_profile :fast
  test "creates memory store on initialization" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker.trigger(:start)
    worker.send(:initialize_execution)

    assert_not_nil worker.memory_store
    assert_instance_of WorkflowMemoryStore, worker.memory_store
  end

  # ===== Context and Options Tests =====

  speed_profile :fast
  test "requires context parameter" do
    assert_raises(ArgumentError) do
      SisyphusWorker.new(
        execution_plan: @execution_plan,
        path: @path
      )
    end
  end

  speed_profile :fast
  test "context must be BaseContext type" do
    assert_raises(TypeError) do
      SisyphusWorker.new(
        execution_plan: @execution_plan,
        path: @path,
        context: { known_files: ["app/models/user.rb"] }
      )
    end
  end

  speed_profile :fast
  test "generates unique owner_id" do
    worker1 = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    worker2 = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @path,
      context: worker_context
    )

    assert_not_equal worker1.owner_id, worker2.owner_id
  end

  # ===== Worker Name Tests =====

  speed_profile :fast
  test "worker_name returns correct value" do
    assert_equal "sisyphus_worker", SisyphusWorker.worker_name
  end
end
