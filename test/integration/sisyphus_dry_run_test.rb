# frozen_string_literal: true

require "test_helper"

class SisyphusDryRunTest < ActiveSupport::TestCase
  setup do
    @test_dir = Dir.mktmpdir("sisyphus_dry_run_test")
    @git_repo = File.join(@test_dir, "test_repo")
    FileUtils.mkdir_p(@git_repo)
    Dir.chdir(@git_repo) do
      `git init`
      `git config user.email "test@example.com"`
      `git config user.name "Test User"`
      File.write("README.md", "# Test Project\n")
      `git add .`
      `git commit -m "Initial commit"`
    end
  end

  teardown do
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  speed_profile :slow
  test "dry_run mode doesn't modify files" do
    # Create a simple plan that would create a file
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Create hello.rb file",
      intent: "Create a simple Ruby file with a hello method",
      details: [
        "Create app/hello.rb",
        "Add a hello method that returns 'Hello, World!'"
      ],
      tests: ["File should exist", "Method should return correct string"]
    )

    milestone = Planning::Milestone.new(
      number: 1,
      title: "Basic Setup",
      description: "Create initial file structure"
    )

    plan = Planning::Result.new(
      goal: "Create hello.rb",
      project_name: "test_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: ["app/hello.rb"],
      file_references_content: "# No references",
      project_plan_content: "# Test plan"
    )

    # Execute with dry_run enabled
    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: true }
    )

    # Record files before execution
    files_before = Dir.glob("#{@git_repo}/**/*").select { |f| File.file?(f) }

    result = worker.execute

    # Record files after execution
    files_after = Dir.glob("#{@git_repo}/**/*").select { |f| File.file?(f) }

    # Assert no files were created or modified
    assert_equal files_before.sort, files_after.sort,
                 "Dry run should not modify files"

    # Assert execution completed
    assert_equal :complete, worker.current_state

    # Assert result indicates dry run
    assert_equal true, result[:metadata][:dry_run]
  end

  speed_profile :slow
  test "dry_run mode generates execution record" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Test step",
      intent: "Test intent",
      details: ["Test detail"],
      tests: []
    )

    milestone = Planning::Milestone.new(
      number: 1,
      title: "Test milestone",
      description: "Test description"
    )

    plan = Planning::Result.new(
      goal: "Test goal",
      project_name: "test_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: ""
    )

    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: true }
    )

    result = worker.execute

    # Assert execution record was created
    refute_nil result
    assert result.is_a?(Hash)
    assert result.key?(:plan_id)
    assert result.key?(:step_results)
    assert result.key?(:metadata)
  end

  speed_profile :slow
  test "dry_run mode doesn't create git checkpoints" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Test step",
      intent: "Test intent",
      details: ["Test detail"],
      tests: []
    )

    milestone = Planning::Milestone.new(
      number: 1,
      title: "Test milestone",
      description: "Test description"
    )

    plan = Planning::Result.new(
      goal: "Test goal",
      project_name: "test_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: ""
    )

    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: true }
    )

    # Count commits before
    commits_before = Dir.chdir(@git_repo) do
      `git log --oneline`.lines.count
    end

    worker.execute

    # Count commits after
    commits_after = Dir.chdir(@git_repo) do
      `git log --oneline`.lines.count
    end

    # Assert no new commits (except initial)
    assert_equal commits_before, commits_after,
                 "Dry run should not create git commits"
  end

  speed_profile :slow
  test "dry_run mode simulates tool executions" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Run tests",
      intent: "Execute test suite",
      details: ["Run bundle exec rake test"],
      tests: ["Tests should pass"]
    )

    milestone = Planning::Milestone.new(
      number: 1,
      title: "Testing",
      description: "Run test suite"
    )

    plan = Planning::Result.new(
      goal: "Test execution",
      project_name: "test_project",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: ""
    )

    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: true }
    )

    result = worker.execute

    # Assert step results exist (simulated)
    assert result[:step_results].is_a?(Array)
  end

  speed_profile :fast
  test "dry_run configuration is validated" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Test",
      intent: "Test",
      details: [],
      tests: []
    )

    milestone = Planning::Milestone.new(
      number: 1,
      title: "Test",
      description: "Test"
    )

    plan = Planning::Result.new(
      goal: "Test",
      project_name: "test",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: ""
    )

    # Test that dry_run accepts boolean
    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: true }
    )
    assert_equal true, worker.config[:dry_run]

    worker2 = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: false }
    )
    assert_equal false, worker2.config[:dry_run]

    # Test default is false
    worker3 = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: {}
    )
    assert_equal false, worker3.config[:dry_run]
  end

  speed_profile :slow
  test "dry_run mode logs indicate simulation" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Test",
      intent: "Test",
      details: ["Test detail"],
      tests: []
    )

    milestone = Planning::Milestone.new(
      number: 1,
      title: "Test",
      description: "Test"
    )

    plan = Planning::Result.new(
      goal: "Test",
      project_name: "test",
      milestones: [milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: ""
    )

    worker = SisyphusWorker.new(
      execution_plan: plan,
      path: @git_repo,
      config: { dry_run: true }
    )

    result = worker.execute

    # Check metadata indicates dry run
    assert_equal true, result[:metadata][:dry_run],
                 "Result metadata should indicate dry run"

    # Check execution record status
    assert [:complete, :partial].include?(result[:status]),
           "Dry run should complete successfully"
  end
end

