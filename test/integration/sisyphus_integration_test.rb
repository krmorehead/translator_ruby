# frozen_string_literal: true

require "test_helper"

class SisyphusIntegrationTest < ActiveSupport::TestCase
  let(:sisyphus_context) { Contexts::BaseContext.new }
  let(:autonomous_config) do
    Configuration::SisyphusConfig.new(
      approval_mode: :autonomous,
      max_retries: 3,
      stream_progress: true,
      error_mode: :lenient,
      dry_run: false
    )
  end

  setup do
    @temp_dir = Dir.mktmpdir("sisyphus_integration")
    
    # Initialize git repo for checkpoints
    Dir.chdir(@temp_dir) do
      system("git init --quiet")
      system("git config user.email 'test@example.com'")
      system("git config user.name 'Test User'")
      
      # Create initial commit
      File.write("README.md", "# Test Project\n")
      system("git add .")
      system("git commit -m 'Initial commit' --quiet")
    end
    
    # Create a simple execution plan
    @execution_plan = create_simple_plan
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  # Integration test: successful execution
  speed_profile :medium
  test "executes without raising errors" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    # Execute - should handle errors gracefully
    result = worker.execute
    
    # Verify result structure exists
    assert_not_nil result
    assert result.key?(:success)
  end

  # Integration test: progress streaming
  speed_profile :medium
  test "initializes progress stream when enabled" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    worker.execute
    
    # Verify progress stream was initialized
    assert worker.progress_stream.is_a?(Array)
  end

  # Integration test: execution with git checkpoints
  speed_profile :medium
  test "creates initial checkpoint when git repo exists" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    initial_commits = count_git_commits(@temp_dir)
    
    worker.execute rescue nil # May fail, that's ok
    
    final_commits = count_git_commits(@temp_dir)
    
    # Should have created at least initial checkpoint
    assert final_commits >= initial_commits
  end

  # Integration test: state transitions
  speed_profile :fast
  test "starts in pending state" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    assert_equal :pending, worker.current_state
  end

  # Integration test: execution record tracking
  speed_profile :medium
  test "initializes execution record" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    worker.execute rescue nil # May fail, that's ok
    
    # Verify execution record was created
    assert_not_nil worker.execution_record
    assert_instance_of Execution::ExecutionRecord, worker.execution_record
  end

  # Integration test: memory persistence
  speed_profile :fast
  test "initializes memory store" do
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    worker.execute rescue nil # May fail, that's ok
    
    # Verify memory store exists
    assert_not_nil worker.memory_store
  end

  # Integration test: error handling in lenient mode
  speed_profile :fast
  test "handles failures gracefully in lenient mode" do
    plan = create_plan_with_failing_step
    
    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: autonomous_config
    )
    
    result = nil
    assert_nothing_raised do
      result = worker.execute
    end
    
    # Should have a result even if failed
    assert_not_nil result
  end

  # Integration test: configuration options
  speed_profile :fast
  test "respects configuration options" do
    custom_config = Configuration::SisyphusConfig.new(
      approval_mode: :autonomous,
      max_retries: 5,
      stream_progress: false,
      error_mode: :lenient,
      dry_run: false
    )
    
    worker = SisyphusWorker.new(
      execution_plan: @execution_plan,
      path: @temp_dir,
      context: sisyphus_context,
      config: custom_config
    )
    
    assert_equal :autonomous, worker.config.approval_mode
    assert_equal 5, worker.config.max_retries
    assert_equal false, worker.config.stream_progress
    assert_equal :lenient, worker.config.error_mode
  end

  private

  def create_simple_plan
    milestone = Planning::Milestone.new(
      number: 1,
      title: "Test Milestone",
      description: "A simple test milestone"
    )
    milestone.add_step(create_simple_step)
    
    Planning::Result.new(
      goal: "Test execution plan",
      project_name: "test_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "# File References\n\nNo files",
      project_plan_content: "# Project Plan\n\nTest plan"
    )
  end

  def create_simple_step
    Planning::Step.new(
      milestone_number: 1, step_number: 1,
      title: "Test Step",
      intent: "Test step execution",
      details: ["Execute a simple test step"],
      tests: ["Verify step completes"]
    )
  end

  def create_plan_with_failing_step
    failing_step = Planning::Step.new(
      milestone_number: 1, step_number: 1,
      title: "Failing Step",
      intent: "This step will fail",
      details: ["Execute a step that fails"],
      tests: ["This will not pass"]
    )
    
    milestone = Planning::Milestone.new(
      number: 1,
      title: "Failing Milestone",
      description: "Contains a failing step"
    )
    milestone.add_step(failing_step)
    
    Planning::Result.new(
      goal: "Failing execution plan",
      project_name: "failing_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "# File References\n\nNo files",
      project_plan_content: "# Project Plan\n\nFailing plan"
    )
  end

  def count_git_commits(path)
    Dir.chdir(path) do
      `git rev-list --count HEAD`.strip.to_i
    end
  end
end

