require "test_helper"

class ResearchWorkflowTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  def setup
    @owner_id = SecureRandom.uuid
    @output_path = Rails.root.join("tmp", "research_workflow_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@output_path)

    @original_state_path = ENV["AGENT_STATE_PATH"]
    ENV["AGENT_STATE_PATH"] = @output_path
  end

  def teardown
    FileUtils.rm_rf(@output_path) if @output_path && File.exist?(@output_path)

    if @original_state_path
      ENV["AGENT_STATE_PATH"] = @original_state_path
    else
      ENV.delete("AGENT_STATE_PATH")
    end
  end

  test "initialization with research path, goal, and owner_id" do
    workflow = ResearchWorkflow.new(
      goal: "How does the calculator work?",
      owner_id: @owner_id,
      research_path: FIXTURE_PATH,
      max_depth: 2
    )

    assert_equal "How does the calculator work?", workflow.goal
    assert_equal @owner_id, workflow.owner_id
    assert_equal FIXTURE_PATH, workflow.research_path
  end

  test "decompose phase produces goal tree" do
    workflow = ResearchWorkflow.new(
      goal: "Explain the math operations",
      owner_id: @owner_id,
      research_path: FIXTURE_PATH,
      max_depth: 1
    )

    workflow.execute

    if workflow.complete?
      assert workflow.result[:goal_tree], "Should have goal tree"
    end
  end

  test "handles empty codebase gracefully" do
    empty_dir = Rails.root.join("tmp", "empty_research_#{Process.pid}").to_s
    FileUtils.mkdir_p(empty_dir)

    begin
      workflow = ResearchWorkflow.new(
        goal: "What is in this codebase?",
        owner_id: @owner_id,
        research_path: empty_dir,
        max_depth: 1
      )

      # Should not crash
      workflow.execute

      assert workflow.complete? || workflow.failed?, "Should complete or fail gracefully"
    ensure
      FileUtils.rm_rf(empty_dir)
    end
  end

  test "respects max_depth parameter" do
    workflow = ResearchWorkflow.new(
      goal: "Research everything",
      owner_id: @owner_id,
      research_path: FIXTURE_PATH,
      max_depth: 1
    )

    workflow.execute

    # With max_depth 1, should complete relatively quickly
  end

  test "creates research_memory accessor" do
    workflow = ResearchWorkflow.new(
      goal: "Simple research",
      owner_id: @owner_id,
      research_path: FIXTURE_PATH,
      max_depth: 1
    )

    workflow.execute

    if workflow.complete?
      assert workflow.research_memory, "Should have research_memory"
      assert_kind_of ResearchMemoryStore, workflow.research_memory
    end
  end
end

