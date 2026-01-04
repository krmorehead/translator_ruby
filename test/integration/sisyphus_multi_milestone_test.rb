# frozen_string_literal: true

require "test_helper"

# Integration test for multi-milestone Sisyphus execution with checkpoints
# Tests complete plan execution with multiple milestones, checkpoint creation,
# and verification of execution flow.
#
# NO MOCKS - Uses real LLM calls and real file operations
class SisyphusMultiMilestoneTest < ActiveSupport::TestCase
  def setup
    # Create temp directory for test execution
    @temp_dir = Dir.mktmpdir("sisyphus_multi_milestone")
    
    # Initialize git repo for checkpoint testing
    Dir.chdir(@temp_dir) do
      system("git init", out: File::NULL, err: File::NULL)
      system("git config user.email 'test@example.com'", out: File::NULL, err: File::NULL)
      system("git config user.name 'Test User'", out: File::NULL, err: File::NULL)
      
      # Create initial commit
      File.write("README.md", "# Multi-Milestone Test\n")
      system("git add .", out: File::NULL, err: File::NULL)
      system("git commit -m 'Initial commit'", out: File::NULL, err: File::NULL)
    end

    # Create a plan with multiple milestones
    @milestone1 = Planning::Milestone.new(
      number: 1,
      title: "Create Hello Script",
      description: "First milestone - create hello.rb"
    )
    
    step1_1 = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Create hello.rb",
      intent: "Create a simple Ruby hello script",
      details: [
        "Create hello.rb file",
        "Add shebang line",
        "Print 'Hello, World!'"
      ],
      tests: ["File should exist and print correctly"]
    )
    @milestone1.add_step(step1_1)

    @milestone2 = Planning::Milestone.new(
      number: 2,
      title: "Create Goodbye Script",
      description: "Second milestone - create goodbye.rb"
    )
    
    step2_1 = Planning::Step.new(
      milestone_number: 2,
      step_number: 1,
      title: "Create goodbye.rb",
      intent: "Create a simple Ruby goodbye script",
      details: [
        "Create goodbye.rb file",
        "Add shebang line",
        "Print 'Goodbye, World!'"
      ],
      tests: ["File should exist and print correctly"]
    )
    @milestone2.add_step(step2_1)

    @execution_plan = Planning::Result.new(
      goal: "Create greeting scripts",
      project_name: "Greeting Scripts",
      milestones: [@milestone1, @milestone2],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: "Multi-milestone test plan"
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  # Test complete multi-milestone execution with checkpoints
  speed_profile :slow
  test "executes multiple milestones with checkpoints at boundaries" do
    # Create SisyphusContext
    context = Contexts::SisyphusContext.new(
      codebase_path: @temp_dir,
      plan_goal: @execution_plan.goal,
      plan_id: @execution_plan.id,
      execution_id: SecureRandom.uuid,
      current_milestone: { number: 1, title: @milestone1.title, description: @milestone1.description }
    )
    
    # Count initial commits
    initial_commits = count_git_commits(@temp_dir)
    
    # Execute Milestone 1
    puts "\n=== Executing Milestone 1: #{@milestone1.title} ==="
    
    milestone1_step = @milestone1.steps.first
    execution_workflow1 = StepExecutionWorkflow.new(owner_id: "multi_milestone_test")
    execution_workflow1.setup(step: milestone1_step, path: @temp_dir, context: context)
    
    step_result1 = execution_workflow1.execute
    
    assert execution_workflow1.complete?, "Milestone 1 execution should complete"
    assert step_result1[:success], "Milestone 1 step should succeed"
    
    # Create checkpoint after milestone 1
    checkpoint_service = CheckpointService.new(path: @temp_dir)
    checkpoint1 = checkpoint_service.create_checkpoint(
      "Sisyphus: Completed #{@milestone1.title}",
      milestone_id: @milestone1.id,
      milestone_number: @milestone1.number
    )
    
    assert_not_nil checkpoint1, "Checkpoint should be created after Milestone 1"
    assert_not_nil checkpoint1.id, "Checkpoint should have an ID"
    
    puts "Checkpoint 1 created: #{checkpoint1.id[0..7]}"
    
    # Verify checkpoint was created (should have 1 more commit)
    after_m1_commits = count_git_commits(@temp_dir)
    assert_equal initial_commits + 1, after_m1_commits, "Should have one checkpoint after Milestone 1"
    
    # Execute Milestone 2
    puts "\n=== Executing Milestone 2: #{@milestone2.title} ==="
    
    context2 = context.with_current_position(
      milestone: { number: 2, title: @milestone2.title, description: @milestone2.description }
    )
    
    milestone2_step = @milestone2.steps.first
    execution_workflow2 = StepExecutionWorkflow.new(owner_id: "multi_milestone_test")
    execution_workflow2.setup(step: milestone2_step, path: @temp_dir, context: context2)
    
    step_result2 = execution_workflow2.execute
    
    assert execution_workflow2.complete?, "Milestone 2 execution should complete"
    assert step_result2[:success], "Milestone 2 step should succeed"
    
    # Create checkpoint after milestone 2
    checkpoint2 = checkpoint_service.create_checkpoint(
      "Sisyphus: Completed #{@milestone2.title}",
      milestone_id: @milestone2.id,
      milestone_number: @milestone2.number
    )
    
    assert_not_nil checkpoint2, "Checkpoint should be created after Milestone 2"
    
    puts "Checkpoint 2 created: #{checkpoint2.id[0..7]}"
    
    # Verify second checkpoint was created
    final_commits = count_git_commits(@temp_dir)
    assert_equal initial_commits + 2, final_commits, "Should have two checkpoints after both milestones"
    
    # Verify checkpoints can be listed
    checkpoints = checkpoint_service.list_checkpoints
    sisyphus_checkpoints = checkpoints.select { |cp| cp.message.start_with?("Sisyphus:") }
    
    assert_equal 2, sisyphus_checkpoints.size, "Should have 2 Sisyphus checkpoints"
    
    # Verify diff between checkpoints
    diff = checkpoint_service.diff_checkpoint(checkpoint1.id, checkpoint2.id)
    
    assert_includes diff, "goodbye.rb", "Diff should show goodbye.rb was added between checkpoints"
    
    puts "\n=== Execution Summary ==="
    puts "Initial commits: #{initial_commits}"
    puts "Final commits: #{final_commits}"
    puts "Checkpoints created: #{sisyphus_checkpoints.size}"
    puts "Files changed in M1: #{(step_result1[:files_changed] || []).size}"
    puts "Files changed in M2: #{(step_result2[:files_changed] || []).size}"
  end

  # Test ExecutionRecord tracks multiple milestones
  speed_profile :fast
  test "ExecutionRecord aggregates multiple milestone results" do
    # Create StepResult objects for multiple milestones
    step_result1 = Execution::StepResult.new(
      step_id: @milestone1.steps.first.id,
      success: true,
      actions_taken: [
        { tool: :write_file, params: { path: "hello.rb" }, success: true, executed: true }
      ],
      files_changed: ["hello.rb"],
      diffs: { "hello.rb" => "+puts 'Hello, World!'" },
      duration: 1.5
    )
    
    step_result2 = Execution::StepResult.new(
      step_id: @milestone2.steps.first.id,
      success: true,
      actions_taken: [
        { tool: :write_file, params: { path: "goodbye.rb" }, success: true, executed: true }
      ],
      files_changed: ["goodbye.rb"],
      diffs: { "goodbye.rb" => "+puts 'Goodbye, World!'" },
      duration: 1.3
    )
    
    # Create ExecutionRecord
    execution_record = Execution::ExecutionRecord.new(
      plan_id: @execution_plan.id,
      step_results: [],
      started_at: Time.now.utc.iso8601,
      status: :running
    )
    
    # Add step results
    execution_record.add_step_result(step_result1)
    execution_record.mark_milestone_completed("1")
    
    execution_record.add_step_result(step_result2)
    execution_record.mark_milestone_completed("2")
    
    # Mark as complete
    execution_record.update_status(:complete)
    
    # Verify aggregation
    assert_equal 2, execution_record.completed_steps, "Should have 2 completed steps"
    assert_equal 2, execution_record.total_files_changed, "Should have changed 2 files total"
    # OOP: milestone_id is stored as String per ExecutionRecord#mark_milestone_completed
    assert_equal ["1", "2"], execution_record.milestones_completed, "Should have completed milestones 1 and 2"
    assert_equal :complete, execution_record.status, "Status should be complete"
    
    # Verify serialization preserves all data
    serialized = execution_record.to_h
    
    assert_equal 2, serialized[:step_results].size
    assert_equal 2, serialized[:milestones_completed].size
    assert_equal :complete, serialized[:status]
    
    # Verify deserialization
    restored = Execution::ExecutionRecord.from_h(serialized)
    
    assert_equal execution_record.total_steps, restored.total_steps
    assert_equal execution_record.total_files_changed, restored.total_files_changed
    assert_equal execution_record.milestones_completed, restored.milestones_completed
  end

  # Test ChangeSet aggregates changes across multiple steps
  speed_profile :fast
  test "ChangeSet tracks cumulative changes across milestones" do
    # Create ChangeSet for milestone 1
    change_set1 = Execution::ChangeSet.new(
      files: {
        "hello.rb" => {
          change_type: :created,
          diff: "+#!/usr/bin/env ruby\n+puts 'Hello, World!'",
          before_hash: nil,
          after_hash: "abc123"
        }
      },
      milestone_id: @milestone1.id,
      step_id: @milestone1.steps.first.id,
      checkpoint_id: "checkpoint1"
    )
    
    # Create ChangeSet for milestone 2
    change_set2 = Execution::ChangeSet.new(
      files: {
        "goodbye.rb" => {
          change_type: :created,
          diff: "+#!/usr/bin/env ruby\n+puts 'Goodbye, World!'",
          before_hash: nil,
          after_hash: "def456"
        }
      },
      milestone_id: @milestone2.id,
      step_id: @milestone2.steps.first.id,
      checkpoint_id: "checkpoint2"
    )
    
    # Verify individual change sets
    assert_equal 1, change_set1.file_count
    assert_equal 1, change_set1.additions_count
    
    assert_equal 1, change_set2.file_count
    assert_equal 1, change_set2.additions_count
    
    # Verify serialization
    serialized1 = change_set1.to_h
    serialized2 = change_set2.to_h
    
    assert_equal 1, serialized1[:files].size
    assert serialized1[:files].key?("hello.rb")
    
    assert_equal 1, serialized2[:files].size
    assert serialized2[:files].key?("goodbye.rb")
    
    # Verify both can be deserialized
    restored1 = Execution::ChangeSet.from_h(serialized1)
    restored2 = Execution::ChangeSet.from_h(serialized2)
    
    assert_equal change_set1.file_count, restored1.file_count
    assert_equal change_set2.file_count, restored2.file_count
  end

  private

  def count_git_commits(path)
    Dir.chdir(path) do
      `git rev-list --count HEAD`.strip.to_i
    end
  end
end

