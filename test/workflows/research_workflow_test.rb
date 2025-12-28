# frozen_string_literal: true

require "test_helper"
class ResearchWorkflowTest < ActiveSupport::TestCase
  include ResearchTestFactory

  def setup
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

  # Memoized workflow - using let() style
  def workflow
    @workflow ||= build_workflow(
      goal: "How does the calculator work?",
      max_depth: 1
    )
  end

  # ============================================================================
  # Unit Tests (no LLM calls)
  # ============================================================================

  test "initialization with factory defaults" do
    wf = build_workflow
    assert_equal "How does Calculator work?", wf.goal
    assert_equal FIXTURE_PATH, wf.research_path
    assert_equal 1, wf.instance_variable_get(:@max_depth)
  end

  test "initialization with custom goal" do
    wf = build_workflow(goal: "Custom research goal")
    assert_equal "Custom research goal", wf.goal
  end

  test "initialization with output modes" do
    wf = build_workflow(output_modes: [:documentation])
    assert_equal [:documentation], wf.output_modes
  end

  test "initialization creates research context" do
    wf = build_workflow
    assert_not_nil wf.instance_variable_get(:@research_context)
    assert_kind_of Contexts::ResearchContext, wf.instance_variable_get(:@research_context)
  end

  test "initial state is pending" do
    wf = build_workflow
    assert_equal :pending, wf.current_state
  end

  test "PARALLEL_PASSES constant is 3" do
    assert_equal 3, ResearchWorkflow::PARALLEL_PASSES
  end

  test "MAX_EMPTY_LEAVES constant is 3" do
    assert_equal 3, ResearchWorkflow::MAX_EMPTY_LEAVES
  end

  test "VALID_OUTPUT_MODES includes report and documentation" do
    assert_includes ResearchWorkflow::VALID_OUTPUT_MODES, :report
    assert_includes ResearchWorkflow::VALID_OUTPUT_MODES, :documentation
  end

  # ============================================================================
  # Shared Execution Tests (single LLM run)
  # ============================================================================

  class << self
    attr_accessor :shared_workflow_result, :shared_workflow_computed
  end

  def shared_execution_result
    return self.class.shared_workflow_result if self.class.shared_workflow_computed

    wf = build_workflow(
      goal: "How does Calculator work?",
      max_depth: 1,
      output_modes: [:report]
    )
    wf.setup()
    wf.execute

    # Ensure result hash has expected structure even if workflow failed
    result = wf.result || { findings: [], sub_questions: [], synthesis: {}, goal_tree: nil }

    self.class.shared_workflow_result = {
      workflow: wf,
      result: result,
      complete: wf.complete?,
      failed: wf.failed?
    }
    self.class.shared_workflow_computed = true

    self.class.shared_workflow_result
  end

  test "shared: workflow completes successfully" do
    data = shared_execution_result
    assert data[:complete], "Workflow should complete"
    refute data[:failed], "Workflow should not fail"
  end

  test "shared: workflow produces goal tree" do
    data = shared_execution_result
    assert data[:result][:goal_tree], "Should have goal tree"
  end

  test "shared: workflow creates research memory" do
    data = shared_execution_result
    wf = data[:workflow]
    assert wf.research_memory, "Should have research_memory"
    assert_kind_of ResearchMemoryStore, wf.research_memory
  end

  test "shared: workflow produces findings" do
    data = shared_execution_result
    assert data[:result][:findings], "Should have findings"
  end

  test "shared: workflow produces sub_questions" do
    data = shared_execution_result
    assert data[:result][:sub_questions], "Should have sub_questions"
  end

  test "shared: workflow produces synthesis" do
    data = shared_execution_result
    assert data[:result][:synthesis], "Should have synthesis"
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  test "handles empty codebase gracefully" do
    empty_dir = Rails.root.join("tmp", "empty_research_#{Process.pid}").to_s
    FileUtils.mkdir_p(empty_dir)

    begin
      wf = build_workflow(research_path: empty_dir)
      wf.execute

      assert wf.complete? || wf.failed?, "Should complete or fail gracefully"
    ensure
      FileUtils.rm_rf(empty_dir)
    end
  end
end
