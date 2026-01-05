require "test_helper"

class GoalDecompositionWorkflowTest < ActiveSupport::TestCase
  include DecompositionContextTests

  # Use let for lazy-evaluated, memoized test fixtures
  let(:owner_id) { SecureRandom.uuid }
  let(:parent_id) { SecureRandom.uuid }
  let(:temp_dir) do
    dir = Rails.root.join("tmp", "decomposition_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  # Required by DecompositionContextTests - uses factory
  let(:decomposition_context) { build(:research_context) }
  let(:full_context) { build(:research_context, :full) }

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end
  speed_profile :slow
  test "decomposes broad goal into sub-goals" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "Explain the entire architecture of a web application",
      owner_id: owner_id,
      parent_id: parent_id,
      max_depth: 2
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?, "Workflow should complete: #{workflow.error}"
    assert workflow.result[:goal_tree], "Should have a goal tree"
    assert workflow.result[:leaf_count] >= 1, "Should have at least one leaf"
  end

  speed_profile :slow
  test "recognizes leaf goals and stops decomposing" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "What is the return type of the add method?",
      owner_id: owner_id,
      parent_id: parent_id,
      max_depth: 4
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?
    # Very specific questions should result in leaves quickly
    leaves = workflow.leaf_goals
    assert leaves.any?, "Should have leaf goals"
  end

  speed_profile :slow
  test "respects max_depth limit" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "Explain everything about this complex system",
      owner_id: owner_id,
      parent_id: parent_id,
      max_depth: 1
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?
    max_depth = workflow.result[:max_depth_reached]
    assert max_depth <= 1, "Should not exceed max_depth of 1"
  end

  speed_profile :slow
  test "returns structured tree with leaf markers" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "How does authentication work?",
      owner_id: owner_id,
      parent_id: parent_id,
      max_depth: 2
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?
    tree = workflow.result[:goal_tree]

    assert tree[:id], "Root should have id"
    assert tree[:text], "Root should have text"
    assert_not_nil tree[:is_leaf], "Should have is_leaf marker"
  end

  speed_profile :slow
  test "handles already-specific goals" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "What line number is the divide method defined on?",
      owner_id: owner_id,
      parent_id: parent_id,
      max_depth: 3
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?
    # Should complete quickly with minimal decomposition
  end

  speed_profile :slow
  test "leaf_goals returns all leaves" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "Explain the calculator class",
      owner_id: owner_id,
      parent_id: parent_id,
      max_depth: 2
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?
    leaves = workflow.leaf_goals
    assert_kind_of Array, leaves
    leaves.each do |leaf|
      assert leaf[:is_leaf], "Each leaf should be marked as leaf"
    end
  end

  speed_profile :slow
  test "accepts context parameter" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "Analyze the payment system",
      owner_id: owner_id,
      parent_id: parent_id,
      context: full_context,
      max_depth: 2
    )

    assert_equal full_context, workflow.context
  end

  speed_profile :slow
  test "context defaults to empty hash" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "Simple goal",
      owner_id: owner_id,
      parent_id: parent_id
    )

    assert_equal({}, workflow.context)
  end

  speed_profile :slow
  test "result includes seed_context_used flag" do
    workflow = GoalDecompositionWorkflow.new(
      goal: "Goal with context",
      owner_id: owner_id,
      parent_id: parent_id,
      context: full_context,
      max_depth: 1
    )

    workflow.setup
    workflow.execute

    assert workflow.complete?
    assert workflow.result[:seed_context_used], "Should indicate seed context was used"
  end
end

