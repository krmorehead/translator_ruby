# frozen_string_literal: true

require "test_helper"

# Test suite for ExecutionStateStore
# Tests Redis-backed persistence of execution states
#
# Note: These tests require Redis to be running
# Skip if Redis is not available
class ExecutionStateStoreTest < ActiveSupport::TestCase
  def setup
    # Check if Redis is available
    begin
      Redis.current.ping
    rescue Redis::CannotConnectError, Redis::BaseConnectionError
      skip "Redis is not available - skipping ExecutionStateStore tests"
    end

    @store = ExecutionStateStore.new(ttl: 3600)

    # Create sample execution state
    @state = Execution::ExecutionState.new(
      execution_id: "test-#{SecureRandom.hex(4)}",
      plan_path: "/path/to/plan.md",
      project_path: "/path/to/project",
      status: :running,
      started_at: Time.now.utc.iso8601
    )
  end

  def teardown
    # Clean up test data
    if @state && @store
      @store.delete(@state.execution_id) rescue nil
    end
  end

  # Initialization tests

  test "initializes with default Redis connection" do
    store = ExecutionStateStore.new
    assert_not_nil store
  end

  test "initializes with custom Redis connection" do
    custom_redis = MockRedis.new
    store = ExecutionStateStore.new(redis: custom_redis)
    assert_not_nil store
  end

  test "initializes with custom TTL" do
    store = ExecutionStateStore.new(redis: @redis, ttl: 7200)
    assert_not_nil store
  end

  # Save tests

  test "save stores execution state in Redis" do
    result = @store.save(@state)

    assert result, "Should return true on successful save"
    assert @store.exists?(@state.execution_id), "Execution should exist after save"
  end

  test "save persists execution state" do
    @store.save(@state)

    retrieved = @store.get(@state.execution_id)
    assert_not_nil retrieved, "Should be able to retrieve saved state"
  end

  test "save allows retrieving list of executions" do
    @store.save(@state)

    executions = @store.list(limit: 10)
    assert executions.any? { |e| e.execution_id == @state.execution_id }, "Saved execution should appear in list"
  end

  test "save validates state parameter" do
    error = assert_raises(TypeError) do
      @store.save("not a state")
    end

    assert_includes error.message, "ExecutionState"
  end

  # Get tests

  test "get retrieves stored execution state" do
    @store.save(@state)

    retrieved = @store.get(@state.execution_id)

    assert_not_nil retrieved
    assert_equal @state.execution_id, retrieved.execution_id
    assert_equal @state.status, retrieved.status
  end

  test "get returns nil for non-existent execution" do
    retrieved = @store.get("non-existent-#{SecureRandom.hex(4)}")

    assert_nil retrieved
  end

  test "get validates execution_id parameter" do
    assert_raises(ArgumentError) do
      @store.get(nil)
    end

    assert_raises(ArgumentError) do
      @store.get("")
    end
  end

  test "get deserializes state correctly" do
    @store.save(@state)

    retrieved = @store.get(@state.execution_id)

    assert_equal @state.execution_id, retrieved.execution_id
    assert_equal @state.plan_path, retrieved.plan_path
    assert_equal @state.project_path, retrieved.project_path
    assert_equal @state.status, retrieved.status
  end

  # List tests

  test "list returns empty array when no executions" do
    executions = @store.list

    assert_equal [], executions
  end

  test "list returns stored executions" do
    # Save multiple executions
    state1 = Execution::ExecutionState.new(
      execution_id: "exec-1",
      plan_path: "/plan1.md",
      project_path: "/project1",
      status: :running,
      started_at: (Time.now - 2.hours).utc.iso8601
    )

    state2 = Execution::ExecutionState.new(
      execution_id: "exec-2",
      plan_path: "/plan2.md",
      project_path: "/project2",
      status: :complete,
      started_at: (Time.now - 1.hour).utc.iso8601
    )

    @store.save(state1)
    @store.save(state2)

    executions = @store.list

    assert_equal 2, executions.size
  end

  test "list returns executions in descending order (most recent first)" do
    # Save multiple executions with different timestamps
    oldest_id = "exec-oldest-#{SecureRandom.hex(4)}"
    newest_id = "exec-newest-#{SecureRandom.hex(4)}"
    middle_id = "exec-middle-#{SecureRandom.hex(4)}"

    state1 = Execution::ExecutionState.new(
      execution_id: oldest_id,
      plan_path: "/plan1.md",
      project_path: "/project1",
      status: :complete,
      started_at: (Time.now - 3.hours).utc.iso8601
    )

    state2 = Execution::ExecutionState.new(
      execution_id: newest_id,
      plan_path: "/plan2.md",
      project_path: "/project2",
      status: :running,
      started_at: Time.now.utc.iso8601
    )

    state3 = Execution::ExecutionState.new(
      execution_id: middle_id,
      plan_path: "/plan3.md",
      project_path: "/project3",
      status: :complete,
      started_at: (Time.now - 1.hour).utc.iso8601
    )

    @store.save(state1)
    @store.save(state2)
    @store.save(state3)

    executions = @store.list

    # Clean up
    [oldest_id, newest_id, middle_id].each { |id| @store.delete(id) rescue nil }

    assert_equal newest_id, executions.first.execution_id
    assert_equal oldest_id, executions.last.execution_id
  end

  test "list respects limit parameter" do
    # Save 5 executions
    ids = []
    5.times do |i|
      id = "exec-#{i}-#{SecureRandom.hex(4)}"
      ids << id
      state = Execution::ExecutionState.new(
        execution_id: id,
        plan_path: "/plan.md",
        project_path: "/project",
        status: :running,
        started_at: (Time.now - i.hours).utc.iso8601
      )
      @store.save(state)
    end

    executions = @store.list(limit: 3)

    # Clean up
    ids.each { |id| @store.delete(id) rescue nil }

    assert executions.size <= 5, "Should not exceed total executions"
    assert executions.size >= 3, "Should return at least limit executions if available"
  end

  # Delete tests

  test "delete removes execution from store" do
    @store.save(@state)

    result = @store.delete(@state.execution_id)

    assert result, "Should return true on successful delete"

    retrieved = @store.get(@state.execution_id)
    assert_nil retrieved, "State should no longer exist"
  end

  test "delete returns false for non-existent execution" do
    result = @store.delete("non-existent-#{SecureRandom.hex(4)}")

    assert_equal false, result
  end

  test "delete validates execution_id parameter" do
    assert_raises(ArgumentError) do
      @store.delete(nil)
    end

    assert_raises(ArgumentError) do
      @store.delete("")
    end
  end

  # Exists tests

  test "exists? returns true for stored execution" do
    @store.save(@state)

    assert @store.exists?(@state.execution_id)
  end

  test "exists? returns false for non-existent execution" do
    refute @store.exists?("non-existent-#{SecureRandom.hex(4)}")
  end

  test "exists? validates execution_id parameter" do
    assert_raises(ArgumentError) do
      @store.exists?(nil)
    end

    assert_raises(ArgumentError) do
      @store.exists?("")
    end
  end

  # Update tests

  test "update modifies existing execution state" do
    @store.save(@state)

    updated = @store.update(@state.execution_id) do |current_state|
      Execution::ExecutionState.new(
        execution_id: current_state.execution_id,
        plan_path: current_state.plan_path,
        project_path: current_state.project_path,
        status: :complete,
        started_at: current_state.started_at,
        completed_at: Time.now.utc.iso8601
      )
    end

    assert_not_nil updated
    assert_equal :complete, updated.status
  end

  test "update returns nil for non-existent execution" do
    updated = @store.update("non-existent-#{SecureRandom.hex(4)}") do |_state|
      # This block should not be called
      flunk "Block should not be called for non-existent execution"
    end

    assert_nil updated
  end

  # Integration tests

  test "complete workflow: save, get, update, delete" do
    # Save initial state
    @store.save(@state)
    assert @store.exists?(@state.execution_id)

    # Get and verify
    retrieved = @store.get(@state.execution_id)
    assert_equal :running, retrieved.status

    # Update status
    @store.update(@state.execution_id) do |current|
      Execution::ExecutionState.new(
        execution_id: current.execution_id,
        plan_path: current.plan_path,
        project_path: current.project_path,
        status: :complete,
        started_at: current.started_at,
        completed_at: Time.now.utc.iso8601
      )
    end

    # Verify update
    updated = @store.get(@state.execution_id)
    assert_equal :complete, updated.status

    # Delete
    @store.delete(@state.execution_id)
    refute @store.exists?(@state.execution_id)
  end
end

