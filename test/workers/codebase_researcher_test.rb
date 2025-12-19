# frozen_string_literal: true

require "test_helper"

class CodebaseResearcherTest < ActiveSupport::TestCase
  include ResearchTestFactory

  # Shared execution result - runs once, used by many tests
  class << self
    attr_accessor :shared_result, :shared_worker, :shared_computed
  end

  def shared_execution
    return [self.class.shared_worker, self.class.shared_result] if self.class.shared_computed

    worker = CodebaseResearcher.new(
      goal: "How does the calculator work?",
      path: temp_dir
    )
    result = worker.execute

    self.class.shared_worker = worker
    self.class.shared_result = result
    self.class.shared_computed = true

    [worker, result]
  end

  # Lazy-evaluated temp directory
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

  test "initialization with goal and path" do
    worker = CodebaseResearcher.new(
      goal: "How does authentication work?",
      path: temp_dir
    )

    assert_equal "How does authentication work?", worker.goal
    assert_equal File.expand_path(temp_dir), worker.path
    assert_not_nil worker.owner_id
    assert worker.pending?
  end

  test "inherits from AgentWorker" do
    assert CodebaseResearcher < AgentWorker
  end

  test "inherits from BaseWorker through AgentWorker" do
    assert CodebaseResearcher < BaseWorker
  end

  test "has agent states defined" do
    states = CodebaseResearcher.states

    # Agent states
    assert_includes states, :pending
    assert_includes states, :running
    assert_includes states, :planning
    assert_includes states, :executing
    assert_includes states, :evaluating
    assert_includes states, :synthesizing
    assert_includes states, :complete
    assert_includes states, :failed
  end

  test "states have phase metadata" do
    assert_nil CodebaseResearcher._states[:pending][:phase]
    assert_equal :setup, CodebaseResearcher._states[:running][:phase]
    assert_equal :reasoning, CodebaseResearcher._states[:planning][:phase]
    assert_equal :work, CodebaseResearcher._states[:executing][:phase]
    assert_equal :reasoning, CodebaseResearcher._states[:evaluating][:phase]
    assert_equal :output, CodebaseResearcher._states[:synthesizing][:phase]
  end

  test "starts in pending state" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir
    )

    assert_equal :pending, worker.current_state
    assert worker.pending?
  end

  test "phase method returns current phase" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir
    )

    assert_nil worker.phase  # pending has no phase

    # Force to running to check phase
    worker.trigger(:start)
    assert_equal :setup, worker.phase
  end

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

  test "context defaults to empty hash" do
    worker = CodebaseResearcher.new(
      goal: "Research something",
      path: temp_dir
    )

    assert_equal({}, worker.context)
  end

  test "max_depth option can be set" do
    worker = CodebaseResearcher.new(
      goal: "Deep research",
      path: temp_dir,
      max_depth: 6
    )

    assert_equal 6, worker.instance_variable_get(:@max_depth)
  end

  test "registers research actions" do
    actions = CodebaseResearcher.action_definitions
    action_names = actions.map { |a| a[:name] }

    assert_includes action_names, "search_files"
    assert_includes action_names, "locate_definition"
    assert_includes action_names, "analyze_file"
    assert_includes action_names, "decompose_question"
    assert_includes action_names, "trace_references"
    assert_includes action_names, "synthesize_partial"
  end

  # ============================================================================
  # Shared Execution Tests - All use same LLM call
  # ============================================================================

  test "shared: creates memory store during execution" do
    worker, _result = shared_execution

    assert_not_nil worker.memory_store
    assert_instance_of ResearchMemoryStore, worker.memory_store
    assert_equal worker.owner_id, worker.memory_store.owner_id
  end

  test "shared: execute returns structured result" do
    _worker, result = shared_execution

    assert result[:success]
    assert_kind_of Array, result[:findings]
    assert_kind_of Hash, result[:metadata]
  end

  test "shared: stores research goal in memory" do
    worker, _result = shared_execution

    goal_section = worker.memory_store.get_section(:research_goal)
    assert_equal 1, goal_section.size
    assert_equal "active", goal_section.first[:status]
  end

  test "shared: worker creates state directory" do
    worker, _result = shared_execution

    assert File.exist?(worker.state_path)
    assert File.directory?(worker.state_path)
  end

  test "shared: memory store is persisted to state path" do
    worker, _result = shared_execution

    memory_file = File.join(worker.state_path, "research_memory.json")
    assert File.exist?(memory_file)

    data = JSON.parse(File.read(memory_file))
    assert data["research_goal"].first["text"].present?
  end

  test "shared: action history is tracked" do
    _worker, result = shared_execution

    # Agent tracks actions in action_history
    assert result[:action_history].is_a?(Array)
  end

  test "shared: final state is included in metadata" do
    _worker, result = shared_execution

    assert_equal :complete, result[:metadata][:final_state]
  end

  test "shared: context is included in result metadata" do
    _worker, result = shared_execution

    assert result[:metadata].key?(:context)
  end

  test "shared: cache stats are included in result" do
    _worker, result = shared_execution

    assert result[:cache_stats].is_a?(Hash)
    assert result[:cache_stats].key?(:hits)
    assert result[:cache_stats].key?(:misses)
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  test "handles errors gracefully" do
    worker = CodebaseResearcher.new(
      goal: "Research something",
      path: temp_dir
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
