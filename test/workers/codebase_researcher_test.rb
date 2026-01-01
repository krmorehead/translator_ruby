# frozen_string_literal: true

require "test_helper"

class CodebaseResearcherTest < ActiveSupport::TestCase
  include ResearchTestFactory

  let(:researcher_context) { Contexts::BaseContext.new }

  # Shared execution result - runs once per test process, used by many tests
  # Uses FIXTURE_PATH to share fixtures across test files
  class << self
    attr_accessor :shared_result, :shared_worker, :shared_computed
  end

  def shared_execution
    return [self.class.shared_worker, self.class.shared_result] if self.class.shared_computed

    worker = CodebaseResearcher.new(
      goal: "How does the calculator work?",
      path: FIXTURE_PATH,
      max_depth: 1,
      context: Contexts::BaseContext.new
    )
    result = worker.execute

    self.class.shared_worker = worker
    self.class.shared_result = result
    self.class.shared_computed = true

    [worker, result]
  end

  # Lazy-evaluated temp directory for tests that need a writable path
  def temp_dir
    @temp_dir ||= begin
      dir = Rails.root.join("tmp", "codebase_researcher_test_#{Process.pid}").to_s
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "sample.rb"), "# Sample Ruby file\nclass Sample; end")
      dir
    end
  end

  # Context using factories
  def seed_context
    @seed_context ||= build(:research_context, :full)
  end

  def minimal_context
    @minimal_context ||= build(:research_context, :with_codebase_summary)
  end

  def teardown
    # Only clean up if we created it in this test (not shared)
    if @temp_dir && !self.class.shared_computed
      FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
    end
  end

  # ============================================================================
  # Unit Tests - No LLM calls
  # ============================================================================
  speed_profile :fast
  test "initialization with goal and path" do
    worker = CodebaseResearcher.new(
      goal: "How does authentication work?",
      path: temp_dir,
      context: researcher_context
    )

    assert_equal "How does authentication work?", worker.goal
    assert_equal File.expand_path(temp_dir), worker.path
    assert_not_nil worker.owner_id
    assert worker.pending?
  end

  speed_profile :fast
  test "inherits from BaseWorker" do
    assert CodebaseResearcher < BaseWorker
  end

  speed_profile :fast
  test "registers GoalDecompositionWorkflow and ResearchWorkflow" do
    workflows = CodebaseResearcher.registered_workflows
    assert_includes workflows, GoalDecompositionWorkflow
    assert_includes workflows, ResearchWorkflow
  end

  speed_profile :fast
  test "has researcher states defined" do
    states = CodebaseResearcher.states

    # Researcher-specific states
    assert_includes states, :pending
    assert_includes states, :running
    assert_includes states, :decomposing
    assert_includes states, :researching
    assert_includes states, :synthesizing
    assert_includes states, :complete
    assert_includes states, :failed
  end

  speed_profile :slow
  test "states have phase metadata" do
    assert_nil CodebaseResearcher._states[:pending][:phase]
    assert_equal :setup, CodebaseResearcher._states[:running][:phase]
    assert_equal :planning, CodebaseResearcher._states[:decomposing][:phase]
    assert_equal :work, CodebaseResearcher._states[:researching][:phase]
    assert_equal :output, CodebaseResearcher._states[:synthesizing][:phase]
  end

  speed_profile :slow
  test "starts in pending state" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir,
      context: researcher_context
    )

    assert_equal :pending, worker.current_state
    assert worker.pending?
  end

  speed_profile :slow
  test "current_phase method returns phase for current state" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir,
      context: researcher_context
    )

    assert_nil worker.current_phase  # pending has no phase

    # Force to running to check phase
    worker.trigger(:start)
    assert_equal :setup, worker.current_phase
  end

  speed_profile :slow
  test "accepts context parameter using factory" do
    worker = CodebaseResearcher.new(
      goal: "How does payment work?",
      path: temp_dir,
      context: seed_context
    )

    assert_equal seed_context, worker.context
    assert_equal seed_context[:known_files], worker.context[:known_files]
    assert_equal seed_context[:prior_findings], worker.context[:prior_findings]
  end

  speed_profile :slow
  test "context defaults to empty hash" do
    worker = CodebaseResearcher.new(
      goal: "Research something",
      path: temp_dir,
      context: researcher_context
    )

    assert_equal({}, worker.context)
  end

  speed_profile :slow
  test "max_depth option can be set" do
    worker = CodebaseResearcher.new(
      goal: "Deep research",
      path: temp_dir,
      max_depth: 6,
      context: researcher_context
    )

    assert_equal 6, worker.instance_variable_get(:@max_depth)
  end

  speed_profile :slow
  test "output_modes defaults to report and documentation" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir,
      context: researcher_context
    )

    assert_includes worker.output_modes, :report
    assert_includes worker.output_modes, :documentation
  end

  speed_profile :slow
  test "output_modes can be customized" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir,
      output_modes: [:report],
      context: researcher_context
    )

    assert_equal [:report], worker.output_modes
  end

  # ============================================================================
  # Shared Execution Tests - All use same LLM call
  # ============================================================================

  speed_profile :slow
  test "shared: creates memory store during execution" do
    worker, _result = shared_execution

    assert_not_nil worker.memory_store
    assert_instance_of ResearchMemoryStore, worker.memory_store
    assert_equal worker.owner_id, worker.memory_store.owner_id
  end

  speed_profile :slow
  test "shared: execute returns structured result" do
    _worker, result = shared_execution

    assert result[:success]
    assert_kind_of Array, result[:findings]
    assert_kind_of Hash, result[:metadata]
  end

  speed_profile :slow
  test "shared: stores research goal in memory" do
    worker, _result = shared_execution

    goal_section = worker.memory_store.get_section(:research_goal)
    assert_equal 1, goal_section.size
    assert_equal "active", goal_section.first[:status]
  end

  speed_profile :slow
  test "shared: worker creates state directory" do
    worker, _result = shared_execution

    assert File.exist?(worker.state_path)
    assert File.directory?(worker.state_path)
  end

  speed_profile :slow
  test "shared: memory store is persisted to state path" do
    worker, _result = shared_execution

    memory_file = File.join(worker.state_path, "research_memory.json")
    assert File.exist?(memory_file)

    data = JSON.parse(File.read(memory_file))
    assert data["research_goal"].first["text"].present?
  end

  speed_profile :slow
  test "shared: action history is tracked" do
    _worker, result = shared_execution

    # Worker tracks actions in action_history
    assert result[:action_history].is_a?(Array)
  end

  speed_profile :slow
  test "shared: final state is included in metadata" do
    _worker, result = shared_execution

    assert_equal :complete, result[:metadata][:final_state]
  end

  speed_profile :slow
  test "shared: context is included in result metadata" do
    _worker, result = shared_execution

    assert result[:metadata].key?(:context)
  end

  speed_profile :slow
  test "shared: has goal_tree from decomposition" do
    worker, result = shared_execution

    assert_not_nil worker.goal_tree
    # Goal tree should have at least the root goal
    assert worker.goal_tree[:text].present? || worker.goal_tree[:goal].present?
  end

  speed_profile :slow
  test "shared: has findings from research" do
    _worker, result = shared_execution

    assert result[:findings].is_a?(Array)
  end

  speed_profile :slow
  test "shared: has sub_questions from decomposition" do
    _worker, result = shared_execution

    assert result[:sub_questions].is_a?(Array)
  end

  speed_profile :slow
  test "shared: workflow results are stored" do
    _worker, result = shared_execution

    assert result[:metadata][:workflow_results].is_a?(Hash)
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  speed_profile :slow
  test "handles errors gracefully" do
    worker = CodebaseResearcher.new(
      goal: "Research something",
      path: temp_dir,
      context: researcher_context
    )

    # Mock the create_memory_store to raise an error
    def worker.create_memory_store
      raise StandardError, "Simulated error"
    end

    result = worker.execute

    assert_equal false, result[:success]
    assert_includes result[:error], "Simulated error"
    assert worker.failed?
  end
end
