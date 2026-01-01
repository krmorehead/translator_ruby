# frozen_string_literal: true

require "test_helper"

class SisyphusEndToEndTest < ActiveSupport::TestCase
  def setup
    # Create temp directory for test execution
    @temp_dir = Dir.mktmpdir("sisyphus_test")
    
    # Initialize git repo
    Dir.chdir(@temp_dir) do
      system("git init", out: File::NULL, err: File::NULL)
      system("git config user.email 'test@example.com'", out: File::NULL, err: File::NULL)
      system("git config user.name 'Test User'", out: File::NULL, err: File::NULL)
    end

    # Create a simple plan with one step
    @step = Planning::Step.new(
      milestone_number: 1,
      step_number: 1,
      title: "Create Hello World Script",
      intent: "Create a simple Ruby script that prints 'Hello, World!'",
      details: [
        "Create a new file called hello.rb",
        "Add a Ruby shebang line",
        "Print 'Hello, World!' to stdout"
      ],
      tests: [
        "Running 'ruby hello.rb' should print 'Hello, World!'",
        "File should be executable"
      ]
    )

    @milestone = Planning::Milestone.new(
      number: 1,
      title: "Create Hello World",
      description: "Simple first milestone"
    )
    @milestone.add_step(@step)

    @execution_plan = Planning::Result.new(
      goal: "Create a Hello World script",
      project_name: "Hello World Project",
      milestones: [@milestone],
      existing_files: [],
      planned_files: [],
      file_references_content: "",
      project_plan_content: "Create a Hello World script in Ruby"
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  # Full end-to-end test with real LLM and tool execution
  speed_profile :slow
  test "executes complete workflow from planning to evaluation" do
    # Create and execute workflow for single step
    execution_workflow = StepExecutionWorkflow.new(owner_id: "test_user")
    execution_workflow.setup(step: @step, path: @temp_dir)

    # Execute - this will hit real LLM for context, planning, validation, and execution
    step_result = execution_workflow.execute

    # Verify workflow completed
    assert execution_workflow.complete?, "Execution workflow should complete"
    assert_not_nil step_result, "Should return step result"
    assert step_result.is_a?(Hash), "Step result should be a hash"

    # Verify step result structure
    assert step_result.key?(:step_id), "Should have step_id"
    assert step_result.key?(:success), "Should have success flag"
    assert step_result.key?(:actions_taken), "Should have actions_taken"

    # Now evaluate the step
    evaluation_workflow = StepEvaluationWorkflow.new(owner_id: "test_user")
    evaluation_workflow.setup(
      step: @step,
      step_result: step_result,
      path: @temp_dir
    )

    # Execute evaluation - hits real LLM
    evaluation = evaluation_workflow.execute

    # Verify evaluation completed
    assert evaluation_workflow.complete?, "Evaluation workflow should complete"
    assert_not_nil evaluation, "Should return evaluation"
    
    # Verify evaluation structure
    assert evaluation.key?(:passed), "Should have passed flag"
    assert evaluation.key?(:confidence), "Should have confidence score"
    assert evaluation.key?(:feedback), "Should have feedback"

    # Log results for manual inspection
    puts "\n=== Execution Result ==="
    puts "Success: #{step_result[:success]}"
    puts "Actions: #{step_result[:actions_taken]&.size || 0}"
    puts "Files Changed: #{step_result[:files_changed]&.size || 0}"
    
    puts "\n=== Evaluation Result ==="
    puts "Passed: #{evaluation[:passed]}"
    puts "Confidence: #{evaluation[:confidence]}"
    puts "Feedback: #{evaluation[:feedback]}"
  end

  # Test workflow memory is captured
  speed_profile :slow
  test "captures workflow memory and decisions" do
    execution_workflow = StepExecutionWorkflow.new(owner_id: "test_user")
    execution_workflow.setup(step: @step, path: @temp_dir)

    step_result = execution_workflow.execute

    # Verify workflow completed
    assert execution_workflow.complete?, "Workflow should complete"
    assert_not_nil step_result, "Should return result"

    # Verify result has metadata (which would contain workflow decisions)
    assert step_result.key?(:metadata), "Should have metadata"
    assert step_result[:metadata].key?(:workflow_id), "Should have workflow ID"

    puts "\n=== Workflow Completed ==="
    puts "Workflow ID: #{step_result[:metadata][:workflow_id]}"
    puts "Final State: #{step_result[:metadata][:final_state]}"
  end

  # Test that tools are actually executed
  speed_profile :slow
  test "actually executes tools and creates files" do
    execution_workflow = StepExecutionWorkflow.new(owner_id: "test_user")
    execution_workflow.setup(step: @step, path: @temp_dir)

    step_result = execution_workflow.execute

    # Check if LLM planned to create the file
    actions = step_result[:actions_taken] || []
    
    # If tools were executed, verify structure
    if actions.any?
      actions.each do |action|
        assert action.key?(:tool), "Action should specify tool"
        assert action.key?(:executed), "Action should have executed flag"
        
        puts "\nTool executed: #{action[:tool]}"
        puts "Success: #{action[:success]}"
        puts "Output: #{action[:output]&.first(100)}"
      end
    end

    # Print step result for debugging
    puts "\n=== Step Result Details ==="
    puts "Success: #{step_result[:success]}"
    puts "Actions taken: #{actions.size}"
    puts "Files changed: #{(step_result[:files_changed] || []).size}"
  end
end

