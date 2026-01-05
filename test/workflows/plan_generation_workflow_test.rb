# frozen_string_literal: true

require "test_helper"

class PlanGenerationWorkflowTest < ActiveSupport::TestCase
  setup do
    @goal = "Create a PlanAgentWorker"
    @path = Rails.root.join("test/fixtures/example_codebase").to_s
    @owner_id = SecureRandom.uuid
    @parent_id = SecureRandom.uuid
    @context = Contexts::BaseContext.new
    @context.add(
      content: "Rails API project for testing",
      topics: ["project_context"],
      source: "test",
      metadata: {}
    )
  end

  speed_profile :fast
  test "initialization with required parameters" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
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
        owner_id: @owner_id,
        parent_id: @parent_id,
        context: @context
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
        owner_id: @owner_id,
        parent_id: @parent_id,
        context: @context
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
        owner_id: 123,
        parent_id: @parent_id,
        context: @context
      )
    end
    assert_match(/owner_id must be a String/, error.message)
  end

  speed_profile :slow
  test "execute transitions through states" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
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
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
    )

    result = workflow.execute

    assert_instance_of Planning::ExecutionPlan, result
    assert_not_nil result.goal
    assert_instance_of Array, result.milestones
  end

  speed_profile :slow
  test "workflow initializes memory on execute" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
    )

    # Memory is initialized in constructor (OOP pattern)
    memory_before = workflow.workflow_memory
    assert_not_nil memory_before, "Memory should be initialized in constructor"
    assert_kind_of WorkflowMemoryStore, memory_before
    
    # Execute uses the initialized memory (this hits LLM, so it's slow)
    result = workflow.execute
    
    # After execute, memory should still be the same instance
    memory_after = workflow.workflow_memory
    assert_equal memory_before.object_id, memory_after.object_id, "Should use same memory instance"
    
    # Verify result
    assert_instance_of Planning::ExecutionPlan, result
  end

  speed_profile :fast
  test "state query methods work correctly" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
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
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
    )

    workflow.trigger(:start)
    assert workflow.running?, "Should be in running state after start"
  end

  speed_profile :fast
  test "execution_plan accessor works" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      path: @path,
      owner_id: @owner_id,
      parent_id: @parent_id,
      context: @context
    )

    # Initially nil
    assert_nil workflow.execution_plan

    # After slow execution, should have a plan (this is a slow test verification)
    # For fast test, we just verify the accessor exists and returns nil initially
  end
end
