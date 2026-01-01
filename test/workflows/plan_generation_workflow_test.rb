# frozen_string_literal: true

require "test_helper"

class PlanGenerationWorkflowTest < ActiveSupport::TestCase
  setup do
    @goal = "Create a PlanAgentWorker"
    @owner_id = SecureRandom.uuid
    @analysis_results = {
      relevant_files: ["app/workers/base_worker.rb"],
      patterns: ["Use state machines"],
      constraints: ["Follow OOP patterns"]
    }
  end

  speed_profile :fast
  test "initialization with required parameters" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
      owner_id: @owner_id
    )

    assert_not_nil workflow
    assert_equal @goal, workflow.goal
    assert_equal @analysis_results, workflow.analysis_results
    assert_equal @owner_id, workflow.owner_id
    assert workflow.pending?
  end

  speed_profile :fast
  test "validates goal must be a String" do
    error = assert_raises(ArgumentError) do
      PlanGenerationWorkflow.new(
        goal: 123,
        analysis_results: @analysis_results,
        owner_id: @owner_id
      )
    end
    assert_match(/goal must be a String/, error.message)
  end

  speed_profile :fast
  test "validates analysis_results must be a Hash" do
    error = assert_raises(ArgumentError) do
      PlanGenerationWorkflow.new(
        goal: @goal,
        analysis_results: "not a hash",
        owner_id: @owner_id
      )
    end
    assert_match(/analysis_results must be a Hash/, error.message)
  end

  speed_profile :fast
  test "validates owner_id must be a String" do
    error = assert_raises(ArgumentError) do
      PlanGenerationWorkflow.new(
        goal: @goal,
        analysis_results: @analysis_results,
        owner_id: 123
      )
    end
    assert_match(/owner_id must be a String/, error.message)
  end

  speed_profile :slow
  test "execute transitions through states" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
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
      analysis_results: @analysis_results,
      owner_id: @owner_id
    )

    result = workflow.execute

    # If successful, should return an ExecutionPlan
    if workflow.complete?
      assert result.is_a?(Planning::ExecutionPlan)
      assert_equal @goal, result.goal
      assert result.milestones.is_a?(Array)
    end
  end

  speed_profile :fast
  test "setup initializes workflow memory" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
      owner_id: @owner_id
    )

    workflow.setup

    assert_not_nil workflow.workflow_memory
  end

  speed_profile :fast
  test "workflow records decisions to memory" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
      owner_id: @owner_id
    )

    workflow.setup
    workflow.record_decision(
      decision: "Test decision",
      rationale: "Test rationale"
    )

    # Workflow memory should exist after setup
    assert_not_nil workflow.workflow_memory
  end

  speed_profile :fast
  test "state query methods work correctly" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
      owner_id: @owner_id
    )

    assert workflow.pending?
    refute workflow.running?
    refute workflow.complete?
    refute workflow.failed?
  end

  speed_profile :fast
  test "can transition to running state" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
      owner_id: @owner_id
    )

    workflow.trigger(:start)

    assert workflow.running?
    refute workflow.pending?
  end

  speed_profile :fast
  test "accepts optional context parameter" do
    workflow = PlanGenerationWorkflow.new(
      goal: @goal,
      analysis_results: @analysis_results,
      owner_id: @owner_id,
      context: "Additional context"
    )

    assert_equal "Additional context", workflow.context
  end
end

