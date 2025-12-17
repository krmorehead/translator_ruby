require "test_helper"

class CodebaseResearcherTest < ActiveSupport::TestCase
  # Use let for lazy-evaluated, memoized test fixtures
  let(:temp_dir) do
    dir = Rails.root.join("tmp", "codebase_researcher_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(dir)
    # Create a simple test file in the codebase
    File.write(File.join(dir, "sample.rb"), "# Sample Ruby file\nclass Sample; end")
    dir
  end

  # Context using factories
  let(:seed_context) { build(:research_context, :full) }
  let(:minimal_context) { build(:research_context, :with_codebase_summary) }

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end

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

  test "creates memory store during execution" do
    worker = CodebaseResearcher.new(
      goal: "Understand the codebase structure",
      path: temp_dir
    )

    # Execute with no workflows registered - should still create memory store
    result = worker.execute

    assert_not_nil worker.memory_store
    assert_instance_of ResearchMemoryStore, worker.memory_store
    assert_equal worker.owner_id, worker.memory_store.owner_id
  end

  test "execute returns structured result" do
    worker = CodebaseResearcher.new(
      goal: "Research the sample code",
      path: temp_dir
    )

    result = worker.execute

    assert result[:success]
    assert_equal "Research the sample code", result[:goal]
    assert_equal File.expand_path(temp_dir), result[:path]
    assert_equal worker.owner_id, result[:owner_id]
    assert_kind_of Array, result[:findings]
    assert_kind_of Hash, result[:memory]
    assert_kind_of Array, result[:output_files]
    assert_kind_of Hash, result[:metadata]
  end

  test "stores research goal in memory" do
    worker = CodebaseResearcher.new(
      goal: "Analyze the architecture",
      path: temp_dir
    )

    worker.execute

    goal_section = worker.memory_store.get_section(:research_goal)
    assert_equal 1, goal_section.size
    assert_equal "Analyze the architecture", goal_section.first[:text]
    assert_equal "active", goal_section.first[:status]
  end

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

  test "max_depth option is stored" do
    worker = CodebaseResearcher.new(
      goal: "Deep research",
      path: temp_dir,
      max_depth: 6
    )

    result = worker.execute

    assert result[:success]
    assert_equal 6, result[:metadata][:max_depth]
  end

  test "inherits from BaseWorker" do
    assert CodebaseResearcher < BaseWorker
  end

  test "worker creates state directory" do
    worker = CodebaseResearcher.new(
      goal: "Test state directory",
      path: temp_dir
    )

    worker.execute

    assert File.exist?(worker.state_path)
    assert File.directory?(worker.state_path)
  end

  test "memory store is persisted to state path" do
    worker = CodebaseResearcher.new(
      goal: "Test persistence",
      path: temp_dir
    )

    worker.execute

    memory_file = File.join(worker.state_path, "research_memory.json")
    assert File.exist?(memory_file)

    # Verify content
    data = JSON.parse(File.read(memory_file))
    assert_equal "Test persistence", data["research_goal"].first["text"]
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

  test "context is included in result metadata" do
    worker = CodebaseResearcher.new(
      goal: "Research the API",
      path: temp_dir,
      context: minimal_context
    )

    result = worker.execute

    assert result[:success]
    assert_equal minimal_context, result[:metadata][:context]
  end

  # State machine tests for research-specific states
  test "has research-specific states defined" do
    states = CodebaseResearcher.states

    assert_includes states, :pending
    assert_includes states, :initializing
    assert_includes states, :decomposing
    assert_includes states, :discovering
    assert_includes states, :analyzing
    assert_includes states, :synthesizing
    assert_includes states, :complete
    assert_includes states, :failed
  end

  test "states have phase metadata" do
    assert_nil CodebaseResearcher._states[:pending][:phase]
    assert_equal :setup, CodebaseResearcher._states[:initializing][:phase]
    assert_equal :planning, CodebaseResearcher._states[:decomposing][:phase]
    assert_equal :research, CodebaseResearcher._states[:discovering][:phase]
    assert_equal :research, CodebaseResearcher._states[:analyzing][:phase]
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

    # Force to initializing to check phase
    worker.trigger(:start)
    assert_equal :setup, worker.phase
  end

  test "state history is included in result" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir
    )

    result = worker.execute

    assert result[:state_history].is_a?(Array)
    assert result[:state_history].size > 0
  end

  test "final state is included in metadata" do
    worker = CodebaseResearcher.new(
      goal: "Test research",
      path: temp_dir
    )

    result = worker.execute

    assert_equal :complete, result[:metadata][:final_state]
  end
end

