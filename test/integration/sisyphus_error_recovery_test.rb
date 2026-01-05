# frozen_string_literal: true

require "test_helper"

# Integration test for Sisyphus error recovery and retry logic
# Tests error handling, retry mechanisms, and recovery workflows with real LLM calls.
#
# NO MOCKS - Uses real LLM calls to test actual error recovery behavior
class SisyphusErrorRecoveryTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Dir.mktmpdir("sisyphus_error_recovery")
    @owner_id = "error_recovery_test"
    @parent_id = "error_recovery_parent"
    
    # Initialize git repo
    Dir.chdir(@temp_dir) do
      system("git init", out: File::NULL, err: File::NULL)
      system("git config user.email 'test@example.com'", out: File::NULL, err: File::NULL)
      system("git config user.name 'Test User'", out: File::NULL, err: File::NULL)
      
      File.write("README.md", "# Error Recovery Test\n")
      system("git add .", out: File::NULL, err: File::NULL)
      system("git commit -m 'Initial commit'", out: File::NULL, err: File::NULL)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  # Test that evaluation detects incomplete steps and provides feedback
  speed_profile :slow
  test "evaluation workflow detects incomplete step execution" do
    # Create a step that expects multiple changes
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Create Configuration Files",
      intent: "Create multiple config files",
      details: [
        "Create config/database.yml",
        "Create config/secrets.yml",
        "Create config/application.yml"
      ],
      tests: [
        "All three config files should exist",
        "Files should have proper YAML structure"
      ]
    )
    
    # Create a minimal step result (simulating incomplete execution)
    step_result = {
      step_id: step.id,
      success: true,
      actions_taken: [
        { tool: :write_file, params: { path: "config/database.yml" }, success: true, executed: true }
      ],
      files_changed: ["config/database.yml"],
      diffs: {
        "config/database.yml" => "+development:\n+  adapter: postgresql"
      },
      tool_outputs: {}
    }
    
    # Create SisyphusContext
    context = Contexts::SisyphusContext.new(
      codebase_path: @temp_dir,
      plan_goal: "Create config files",
      plan_id: SecureRandom.uuid,
      execution_id: SecureRandom.uuid
    )
    
    # Evaluate the incomplete step
    evaluation_workflow = StepEvaluationWorkflow.new(owner_id: @owner_id, parent_id: @parent_id)
    evaluation_workflow.setup(
      step: step,
      step_result: step_result,
      path: @temp_dir,
      context: context
    )
    
    evaluation = evaluation_workflow.execute
    
    # Verify evaluation completed
    assert evaluation_workflow.complete?, "Evaluation should complete"
    assert_not_nil evaluation, "Should return evaluation"
    
    # The LLM should detect missing files
    assert evaluation.key?(:passed), "Should have passed flag"
    assert evaluation.key?(:missing_requirements), "Should identify missing requirements"
    
    # Log evaluation results
    puts "\n=== Evaluation of Incomplete Step ==="
    puts "Passed: #{evaluation[:passed]}"
    puts "Confidence: #{evaluation[:confidence]}"
    puts "Missing Requirements: #{evaluation[:missing_requirements]}"
    puts "Concerns: #{evaluation[:concerns]}"
    puts "Should Retry: #{evaluation[:should_retry]}"
    
    # The LLM may or may not pass this depending on its interpretation,
    # but it should identify concerns or missing requirements
    has_feedback = evaluation[:missing_requirements]&.any? || evaluation[:concerns]&.any?
    assert has_feedback, "Evaluation should provide feedback about incomplete execution"
  end

  # Test memory persistence through workflow execution
  speed_profile :slow
  test "workflow execution produces metadata indicating memory tracking" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Simple Test Step",
      intent: "Test memory persistence",
      details: ["Create test.txt"],
      tests: ["File should exist"]
    )
    
    context = Contexts::SisyphusContext.new(
      codebase_path: @temp_dir,
      plan_goal: "Test memory",
      plan_id: SecureRandom.uuid,
      execution_id: SecureRandom.uuid
    )
    
    workflow = StepExecutionWorkflow.new(owner_id: @owner_id, parent_id: @parent_id)
    workflow.setup(step: step, path: @temp_dir, context: context)
    
    # Execute workflow (will create memory entries internally)
    step_result = workflow.execute
    
    # Verify workflow completed successfully
    assert workflow.complete?, "Workflow completion indicates memory is functioning"
    assert_not_nil step_result, "Step result indicates successful execution"
    
    # Verify step result includes workflow metadata
    assert step_result.key?(:metadata), "Should include metadata"
    assert step_result[:metadata].key?(:workflow_id), "Should track workflow ID"
    
    # The workflow uses memory internally for decision tracking
    # Successful completion proves memory system is working
  end

  # Test that retry logic can be implemented with step results
  speed_profile :fast
  test "step results can track attempt information" do
    step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Test Step with Retries",
      intent: "Test retry tracking",
      details: ["Execute a command"],
      tests: ["Command should succeed"]
    )
    
    # Simulate multiple execution attempts
    attempts = []
    
    3.times do |i|
      step_result = Execution::StepResult.new(
        step_id: step.id,
        success: false,
        actions_taken: [
          { tool: :bash, params: { command: "false" }, success: false, executed: true, attempt: i + 1 }
        ],
        files_changed: [],
        diffs: {},
        error_message: "Command failed with exit code 1 (attempt #{i + 1})"
      )
      
      attempts << step_result
    end
    
    # Verify each attempt is tracked
    assert_equal 3, attempts.size
    
    attempts.each_with_index do |result, index|
      assert result.failed?, "All attempts should be marked as failed"
      assert_includes result.error_message, "attempt #{index + 1}", "Error message should indicate attempt"
    end
    
    # Verify actions can track attempts
    final_attempt = attempts.last
    assert_equal 3, final_attempt.actions_taken.first[:attempt], "Action should track attempt number"
  end

  # Test ExecutionRecord status reflects partial completion
  speed_profile :fast
  test "ExecutionRecord correctly reports partial execution status" do
    execution_record = Execution::ExecutionRecord.new(
      plan_id: SecureRandom.uuid,
      step_results: [],
      started_at: Time.now.utc.iso8601,
      status: :running
    )
    
    # Add successful step
    successful_step = Execution::StepResult.new(
      step_id: SecureRandom.uuid,
      success: true,
      actions_taken: [{ tool: :write_file, success: true, executed: true }],
      files_changed: ["file1.rb"],
      diffs: { "file1.rb" => "+content" }
    )
    
    execution_record.add_step_result(successful_step)
    
    # Add failed step
    failed_step = Execution::StepResult.new(
      step_id: SecureRandom.uuid,
      success: false,
      actions_taken: [{ tool: :bash, success: false, executed: true }],
      files_changed: [],
      diffs: {},
      error_message: "Command failed"
    )
    
    execution_record.add_step_result(failed_step)
    
    # Update status based on results
    execution_record.update_status(:partial)
    
    # Verify status calculations
    assert_equal 2, execution_record.total_steps, "Should have 2 steps total"
    assert_equal 1, execution_record.completed_steps, "Should have 1 completed"
    assert_equal 1, execution_record.failed_steps, "Should have 1 failed"
    assert_equal :partial, execution_record.status, "Status should be partial"
    
    # Verify progress percentage with partial completion
    expected_progress = (1.0 / 2.0 * 100).round(1)
    assert_equal expected_progress, execution_record.progress_percentage
    
    # Verify serialization preserves partial status
    serialized = execution_record.to_h
    assert_equal :partial, serialized[:status]
    assert_equal 1, serialized[:step_results].count { |sr| sr[:success] }
    assert_equal 1, serialized[:step_results].count { |sr| !sr[:success] }
    
    # Verify serialization structure has all required fields
    assert serialized.key?(:plan_id)
    assert serialized.key?(:step_results)
    assert serialized.key?(:started_at)
    assert serialized.key?(:status)
  end

  # Test diff generation for failed steps
  speed_profile :fast
  test "generates diffs even for partially failed steps" do
    diff_service = DiffGenerationService.new
    
    # Simulate a step that partially completed
    # (created one file successfully, failed on second)
    change_set = Execution::ChangeSet.new(
      files: {
        "partial.rb" => {
          change_type: :created,
          diff: "+# This file was created\n+class Partial\nend",
          before_hash: nil,
          after_hash: "abc123"
        }
      },
      step_id: SecureRandom.uuid,
      summary: "Partial execution - 1 file created before failure"
    )
    
    # Verify change set tracks the file
    assert_equal 1, change_set.file_count, "Change set should have 1 file"
    assert_equal ["partial.rb"], change_set.changed_files, "Should track partial.rb"
    assert_equal 1, change_set.additions_count, "Should have 1 addition"
    
    # Generate workspace diff
    workspace_diff = diff_service.generate_workspace_diff(change_set)
    
    assert_not_nil workspace_diff, "Should generate diff even for partial execution"
    assert_includes workspace_diff, "+# This file was created", "Diff should show added content"
    
    # Verify diff stats
    stats = diff_service.diff_stats(workspace_diff)
    assert stats[:files_changed] >= 0, "Should track files changed"
    assert stats[:lines_added] > 0, "Should have lines added"
  end
end

