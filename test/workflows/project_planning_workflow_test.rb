# frozen_string_literal: true

require "test_helper"

class ProjectPlanningWorkflowTest < ActiveSupport::TestCase
  include ResearchTestFactory

  # ============================================================================
  # Unit Tests - No LLM calls
  # ============================================================================

  test "initialization with required parameters" do
    workflow = ProjectPlanningWorkflow.new(
      goal: "Add feature X",
      project_name: "feature_x",
      owner_id: "test-owner-123",
      research_results: { findings: [] }
    )

    assert_equal "Add feature X", workflow.goal
    assert_equal "feature_x", workflow.project_name
    assert_equal "test-owner-123", workflow.owner_id
  end

  test "inherits from BaseWorkflow" do
    assert ProjectPlanningWorkflow < BaseWorkflow
  end

  test "has planning states defined" do
    states = ProjectPlanningWorkflow.states

    assert_includes states, :pending
    assert_includes states, :running
    assert_includes states, :milestones
    assert_includes states, :steps
    assert_includes states, :detailing
    assert_includes states, :validating
    assert_includes states, :synthesizing
    assert_includes states, :complete
    assert_includes states, :failed
  end

  test "states have phase metadata" do
    assert_nil ProjectPlanningWorkflow._states[:pending][:phase]
    assert_equal :setup, ProjectPlanningWorkflow._states[:running][:phase]
    assert_equal :planning, ProjectPlanningWorkflow._states[:milestones][:phase]
    assert_equal :planning, ProjectPlanningWorkflow._states[:steps][:phase]
    assert_equal :planning, ProjectPlanningWorkflow._states[:detailing][:phase]
    assert_equal :validation, ProjectPlanningWorkflow._states[:validating][:phase]
    assert_equal :output, ProjectPlanningWorkflow._states[:synthesizing][:phase]
  end

  test "starts in pending state" do
    workflow = ProjectPlanningWorkflow.new(
      goal: "Test goal",
      project_name: "test_project",
      owner_id: SecureRandom.uuid,
      research_results: {}
    )

    assert_equal :pending, workflow.current_state
    assert workflow.pending?
  end

  test "accepts parent_memory parameter" do
    parent_memory = build_memory_store
    workflow = ProjectPlanningWorkflow.new(
      goal: "Test goal",
      project_name: "test_project",
      owner_id: SecureRandom.uuid,
      research_results: {},
      parent_memory: parent_memory
    )

    assert_not_nil workflow.parent_memory
  end

  test "handles empty research results gracefully" do
    workflow = ProjectPlanningWorkflow.new(
      goal: "Test goal",
      project_name: "test_project",
      owner_id: SecureRandom.uuid,
      research_results: nil
    )

    assert_equal({}, workflow.research_results)
  end
end
