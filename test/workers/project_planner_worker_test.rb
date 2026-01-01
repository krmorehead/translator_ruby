# frozen_string_literal: true

require "test_helper"

class ProjectPlannerWorkerTest < ActiveSupport::TestCase
  include ResearchTestFactory

  let(:planner_context) { Contexts::BaseContext.new }

  # Shared execution result - runs once per test process
  class << self
    attr_accessor :shared_result, :shared_worker, :shared_computed
  end

  def shared_execution
    return [self.class.shared_worker, self.class.shared_result] if self.class.shared_computed

    worker = ProjectPlannerWorker.new(
      goal: "Add logging to Calculator",
      path: FIXTURE_PATH,
      project_name: "calculator_logging",
      max_research_depth: 1,
      context: Contexts::BaseContext.new
    )
    result = worker.execute

    self.class.shared_worker = worker
    self.class.shared_result = result
    self.class.shared_computed = true

    [worker, result]
  end

  # Lazy-evaluated temp directory for tests that need a writable path
  def temp_dir
    @temp_dir ||= begin
      dir = Rails.root.join("tmp", "project_planner_test_#{Process.pid}").to_s
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "sample.rb"), "# Sample Ruby file\nclass Sample; end")
      dir
    end
  end

  def teardown
    if @temp_dir && !self.class.shared_computed
      FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
    end
  end

  # ============================================================================
  # Unit Tests - No LLM calls
  # ============================================================================
  speed_profile :fast
  test "initialization with goal, path, and project_name" do
    worker = ProjectPlannerWorker.new(
      goal: "Add user authentication",
      path: temp_dir,
      project_name: "user_auth",
      context: planner_context
    )

    assert_equal "Add user authentication", worker.goal
    assert_equal File.expand_path(temp_dir), worker.path
    assert_equal "user_auth", worker.project_name
    assert_not_nil worker.owner_id
    assert worker.pending?
  end

  speed_profile :fast
  test "inherits from BaseWorker" do
    assert ProjectPlannerWorker < BaseWorker
  end

  speed_profile :fast
  test "registers ProjectPlanningWorkflow" do
    workflows = ProjectPlannerWorker.registered_workflows
    assert_includes workflows, ProjectPlanningWorkflow
  end

  speed_profile :slow
  test "has planner states defined" do
    states = ProjectPlannerWorker.states

    assert_includes states, :pending
    assert_includes states, :running
    assert_includes states, :researching
    assert_includes states, :planning
    assert_includes states, :writing
    assert_includes states, :complete
    assert_includes states, :failed
  end

  speed_profile :slow
  test "states have phase metadata" do
    assert_nil ProjectPlannerWorker._states[:pending][:phase]
    assert_equal :setup, ProjectPlannerWorker._states[:running][:phase]
    assert_equal :research, ProjectPlannerWorker._states[:researching][:phase]
    assert_equal :planning, ProjectPlannerWorker._states[:planning][:phase]
    assert_equal :output, ProjectPlannerWorker._states[:writing][:phase]
  end

  speed_profile :slow
  test "starts in pending state" do
    worker = ProjectPlannerWorker.new(
      goal: "Test planning",
      path: temp_dir,
      project_name: "test_project",
      context: planner_context
    )

    assert_equal :pending, worker.current_state
    assert worker.pending?
  end

  speed_profile :slow
  test "accepts context parameter" do
    context = { known_files: ["lib/calculator.rb"], constraints: "Must be fast" }
    worker = ProjectPlannerWorker.new(
      goal: "Optimize calculator",
      path: temp_dir,
      project_name: "calc_optimization",
      context: context
    )

    assert_equal context, worker.context
  end

  speed_profile :slow
  test "max_research_depth option can be set" do
    worker = ProjectPlannerWorker.new(
      goal: "Deep research",
      path: temp_dir,
      project_name: "deep_project",
      max_research_depth: 5
    )

    assert_equal 5, worker.instance_variable_get(:@max_research_depth)
  end

  speed_profile :slow
  test "max_research_depth defaults to 2" do
    worker = ProjectPlannerWorker.new(
      goal: "Default depth",
      path: temp_dir,
      project_name: "default_project",
      context: planner_context
    )

    assert_equal 2, worker.instance_variable_get(:@max_research_depth)
  end

  # ============================================================================
  # Shared Execution Tests - All use same LLM call
  # ============================================================================

  speed_profile :slow
  test "shared: creates memory store during execution" do
    worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    assert_not_nil worker.memory_store
    assert_instance_of ResearchMemoryStore, worker.memory_store
    assert_equal worker.owner_id, worker.memory_store.owner_id
  end

  speed_profile :slow
  test "shared: execute returns structured result" do
    _worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    # Result should be a ProjectPlanner::Result object
    assert_instance_of ProjectPlanner::Result, result
    assert_equal true, result.success
    assert_not_nil result.goal
    assert_not_nil result.project_name
  end

  speed_profile :slow
  test "shared: result includes file paths" do
    _worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    assert_not_nil result.project_path
    assert_not_nil result.file_references_path
    assert_not_nil result.project_plan_path
  end

  speed_profile :slow
  test "shared: result includes milestones" do
    _worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    # Result has planning_result which contains milestones
    assert_not_nil result.planning_result
    assert_kind_of Array, result.planning_result.milestones
  end

  speed_profile :slow
  test "shared: result includes existing and planned files" do
    _worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    # Result has planning_result which contains file references
    assert_not_nil result.planning_result
    assert_kind_of Array, result.planning_result.existing_files
    assert_kind_of Array, result.planning_result.planned_files
  end

  speed_profile :slow
  test "shared: final state is complete" do
    worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    assert_equal :complete, result.metadata[:final_state]
    assert worker.complete?
  end

  speed_profile :slow
  test "shared: creates state directory" do
    worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    assert File.exist?(worker.state_path)
    assert File.directory?(worker.state_path)
  end

  speed_profile :slow
  test "shared: output files are created" do
    _worker, result = shared_execution
    assert result.success?, "Planning should succeed: #{result.error}"

    assert File.exist?(result.file_references_path)
    assert File.exist?(result.project_plan_path)
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  speed_profile :slow
  test "handles errors gracefully" do
    worker = ProjectPlannerWorker.new(
      goal: "Test error handling",
      path: temp_dir,
      project_name: "error_test",
      context: planner_context
    )

    # Mock the create_memory_store to raise an error
    def worker.create_memory_store
      raise StandardError, "Simulated error"
    end

    result = worker.execute

    assert_instance_of ProjectPlanner::Result, result
    assert_equal false, result.success
    assert result.failed?
    assert_includes result.error, "Simulated error"
    assert worker.failed?
  end
end
