require "test_helper"

class BaseWorkerTest < ActiveSupport::TestCase
  # Use let for lazy-evaluated, memoized test fixtures
  let(:temp_dir) do
    dir = Rails.root.join("tmp", "base_worker_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  # Shared context using factory
  let(:seed_context) { build(:research_context, :full) }

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end

  test "initializes with valid path" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert_equal "test goal", worker.goal
    assert_equal File.expand_path(temp_dir), worker.path
    assert worker.pending?
  end

  test "generates unique owner_id on initialization" do
    worker1 = BaseWorker.new(goal: "goal 1", path: temp_dir)
    worker2 = BaseWorker.new(goal: "goal 2", path: temp_dir)

    assert_not_nil worker1.owner_id
    assert_not_nil worker2.owner_id
    assert_not_equal worker1.owner_id, worker2.owner_id
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, worker1.owner_id)
  end

  test "workflow registration works" do
    # Create a test workflow class
    workflow_class = Class.new(BaseWorkflow)

    # Create a test worker class that registers workflows
    worker_class = Class.new(BaseWorker) do
      register_workflow workflow_class
    end

    assert_includes worker_class.registered_workflows, workflow_class
  end

  test "status transitions correctly" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert worker.pending?
    refute worker.running?
    refute worker.complete?
    refute worker.failed?

    worker.send(:mark_running)
    assert worker.running?
    refute worker.pending?

    worker.send(:mark_complete, { result: "done" })
    assert worker.complete?
    assert_equal({ result: "done" }, worker.result)

    # Test failed state on a fresh worker
    worker2 = BaseWorker.new(goal: "test goal", path: temp_dir)
    worker2.send(:mark_failed, "something went wrong")
    assert worker2.failed?
    assert_equal "something went wrong", worker2.error
  end

  test "execute raises NotImplementedError in base class" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert_raises(NotImplementedError) do
      worker.execute
    end
  end

  test "rejects non-existent paths" do
    assert_raises(ArgumentError) do
      BaseWorker.new(goal: "test goal", path: "/non/existent/path/#{SecureRandom.uuid}")
    end
  end

  test "parallel workers have isolated state" do
    worker1 = BaseWorker.new(goal: "goal 1", path: temp_dir)
    worker2 = BaseWorker.new(goal: "goal 2", path: temp_dir)

    # Different owner_ids means different state paths
    assert_not_equal worker1.state_path, worker2.state_path

    # Both state paths contain their respective owner_ids
    assert_includes worker1.state_path, worker1.owner_id
    assert_includes worker2.state_path, worker2.owner_id
  end

  test "state_path uses AGENT_STATE_PATH env var when set" do
    custom_path = File.join(temp_dir, "custom_state")

    original_env = ENV["AGENT_STATE_PATH"]
    ENV["AGENT_STATE_PATH"] = custom_path

    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert worker.state_path.start_with?(custom_path)
    assert_includes worker.state_path, worker.owner_id
  ensure
    if original_env
      ENV["AGENT_STATE_PATH"] = original_env
    else
      ENV.delete("AGENT_STATE_PATH")
    end
  end

  test "output_path uses RESEARCH_OUTPUT_PATH env var when set" do
    custom_path = File.join(temp_dir, "custom_output")

    original_env = ENV["RESEARCH_OUTPUT_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = custom_path

    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert_equal custom_path, worker.output_path
  ensure
    if original_env
      ENV["RESEARCH_OUTPUT_PATH"] = original_env
    else
      ENV.delete("RESEARCH_OUTPUT_PATH")
    end
  end

  test "ensure_state_directory creates directory" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    refute File.exist?(worker.state_path)

    worker.send(:ensure_state_directory!)

    assert File.exist?(worker.state_path)
    assert File.directory?(worker.state_path)
  end

  test "ensure_output_directory creates directory" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    refute File.exist?(worker.output_path)

    worker.send(:ensure_output_directory!)

    assert File.exist?(worker.output_path)
    assert File.directory?(worker.output_path)
  end

  test "worker_name returns underscored class name" do
    assert_equal "base_worker", BaseWorker.worker_name
  end

  test "stores and retrieves workflow results" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    worker.send(:store_workflow_result, "test_workflow", { data: "result" })

    assert_equal({ data: "result" }, worker.send(:workflow_result, "test_workflow"))
    assert_nil worker.send(:workflow_result, "nonexistent_workflow")
  end

  test "accepts context parameter" do
    # Use factory for context
    worker = BaseWorker.new(goal: "test goal", path: temp_dir, context: seed_context)

    assert_equal seed_context, worker.context
    assert_equal seed_context[:known_files], worker.context[:known_files]
    assert_equal seed_context[:prior_findings], worker.context[:prior_findings]
  end

  test "context defaults to empty hash" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert_equal({}, worker.context)
  end

  test "context with nil value defaults to empty hash" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir, context: nil)

    assert_equal({}, worker.context)
  end

  # State machine tests
  test "starts in pending state" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert_equal :pending, worker.current_state
    assert worker.pending?
    assert worker.in_state?(:pending)
  end

  test "has status method that returns current state" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert_equal :pending, worker.status
    worker.send(:mark_running)
    assert_equal :running, worker.status
  end

  test "can check available events" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    assert worker.can_trigger?(:start)
    assert worker.can_trigger?(:fail)
    refute worker.can_trigger?(:finish)
  end

  test "transition to running via mark_running" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    worker.send(:mark_running)

    assert worker.running?
    assert_equal :running, worker.current_state
  end

  test "transition to failed via mark_failed" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    worker.send(:mark_running)
    worker.send(:mark_failed, "error message")

    assert worker.failed?
    assert_equal "error message", worker.error
  end

  test "invalid state transitions raise errors" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    # Can't finish from pending
    assert_raises(StateMachine::InvalidTransition) do
      worker.trigger(:finish)
    end
  end

  test "state history is tracked" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    worker.send(:mark_running)
    worker.send(:mark_complete, { result: "done" })

    history = worker.state_history
    assert_equal 2, history.size
    assert_equal :pending, history[0][:from]
    assert_equal :running, history[0][:to]
    assert_equal :running, history[1][:from]
    assert_equal :complete, history[1][:to]
  end

  test "retry from failed state" do
    worker = BaseWorker.new(goal: "test goal", path: temp_dir)

    worker.send(:mark_failed, "error")
    assert worker.failed?

    worker.send(:mark_retry)
    assert worker.pending?
    assert_nil worker.error
  end
end

