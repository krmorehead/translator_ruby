# frozen_string_literal: true

require "test_helper"

class PlanGenerationWorkflowTest < ActiveSupport::TestCase
  setup do
    @goal = "Create a PlanAgentWorker"
    @path = Rails.root.join("test/fixtures/example_codebase").to_s
    @owner_id = SecureRandom.uuid
  end

  speed_profile :fast
  test "initialization with required parameters" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    assert_not_nil workflow
    assert_equal @goal, workflow.goal
    assert_equal @path, workflow.path
    assert_equal @owner_id, workflow.owner_id
    assert workflow.pending?
  end

  speed_profile :fast
  test "validates goal must be a String" do
    error = assert_raises(ArgumentError) do
      PlanGenerationWorkflow.new(
        goal: 123,
        path: @path,
        owner_id: @owner_id
      )
    end
    assert_match(/goal must be a String/, error.message)
  end

  speed_profile :fast
  test "validates path must be a String" do
    error = assert_raises(ArgumentError) do
      PlanGenerationWorkflow.new(
        goal: @goal,
        path: 123,
        owner_id: @owner_id
      )
    end
    assert_match(/path must be a String/, error.message)
  end

  speed_profile :fast
  test "validates owner_id must be a String" do
    error = assert_raises(ArgumentError) do
      PlanGenerationWorkflow.new(
        goal: @goal,
        path: @path,
        owner_id: 123
      )
    end
    assert_match(/owner_id must be a String/, error.message)
  end

  speed_profile :slow
  test "execute transitions through states" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    result = workflow.execute

    # Should complete or fail (both are valid end states)
    assert workflow.complete? || workflow.failed?
    assert_not_nil result
  end

  speed_profile :slow
  test "execute returns ExecutionPlan on success" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    result = workflow.execute

    assert_instance_of Planning::ExecutionPlan, result
    assert_not_nil result.goal
    assert_instance_of Array, result.milestones
  end

  speed_profile :fast
  test "workflow initializes memory on execute" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    # Memory not initialized until execute
    memory_before = workflow.instance_variable_get(:@research_memory)
    assert_nil memory_before, "Memory should not be initialized before execute"
    
    # Execute to initialize memory
    workflow.trigger(:start)
    workflow.send(:initialize_workflow_memory)
    
    # Now memory should be initialized
    memory_after = workflow.instance_variable_get(:@research_memory)
    assert_not_nil memory_after, "Memory should be initialized after calling initialize_workflow_memory"
  end

  speed_profile :fast
  test "state query methods work correctly" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    # Check initial state
    assert workflow.pending?, "Should start in pending state"
    assert_not workflow.running?, "Should not be running initially"
    assert_not workflow.complete?, "Should not be complete initially"
    assert_not workflow.failed?, "Should not be failed initially"
  end

  speed_profile :fast
  test "can transition to running state" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    workflow.trigger(:start)
    assert workflow.running?, "Should be in running state after start"
  end

  speed_profile :fast
  test "execution_plan accessor works" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id
    )

    # Initially nil
    assert_nil workflow.execution_plan

    # After slow execution, should have a plan (this is a slow test verification)
    # For fast test, we just verify the accessor exists and returns nil initially
  end
end
