# frozen_string_literal: true

require "test_helper"

class WorkflowMemories::StateTransitionTest < ActiveSupport::TestCase
  speed_profile :fast

  speed_profile :fast
  test "creates state transition with required parameters" do
    transition = WorkflowMemories::StateTransition.new(
      from: :idle,
      to: :planning,
      event: :start,
      source: "SisyphusWorker",
      payload: { request_id: "123" },
      duration: 1.5,
      checkpoint_id: "abc123",
      state: :planning
    )

    assert_equal :idle, transition.from
    assert_equal :planning, transition.to
    assert_equal :start, transition.event
    assert_equal "SisyphusWorker", transition.source
    assert_equal({ request_id: "123" }, transition.payload)
    assert_equal 1.5, transition.duration
    assert_equal "abc123", transition.checkpoint_id
    assert_equal :planning, transition.state
  end

  speed_profile :fast
  test "validates from is a Symbol" do
    error = assert_raises(TypeError) do
      WorkflowMemories::StateTransition.new(
        from: "idle",
        to: :planning,
        event: :start,
        source: "test",
        payload: {},
        duration: 0.0,
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/from must be a Symbol/, error.message)
  end

  speed_profile :fast
  test "validates to is a Symbol" do
    error = assert_raises(TypeError) do
      WorkflowMemories::StateTransition.new(
        from: :idle,
        to: "planning",
        event: :start,
        source: "test",
        payload: {},
        duration: 0.0,
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/to must be a Symbol/, error.message)
  end

  speed_profile :fast
  test "validates event is a Symbol" do
    error = assert_raises(TypeError) do
      WorkflowMemories::StateTransition.new(
        from: :idle,
        to: :planning,
        event: "start",
        source: "test",
        payload: {},
        duration: 0.0,
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/event must be a Symbol/, error.message)
  end

  speed_profile :fast
  test "validates source is a String" do
    error = assert_raises(TypeError) do
      WorkflowMemories::StateTransition.new(
        from: :idle,
        to: :planning,
        event: :start,
        source: :test,
        payload: {},
        duration: 0.0,
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/source must be a String/, error.message)
  end

  speed_profile :fast
  test "validates payload is a Hash" do
    error = assert_raises(TypeError) do
      WorkflowMemories::StateTransition.new(
        from: :idle,
        to: :planning,
        event: :start,
        source: "test",
        payload: "not a hash",
        duration: 0.0,
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/payload must be a Hash/, error.message)
  end

  speed_profile :fast
  test "validates duration is Numeric" do
    error = assert_raises(TypeError) do
      WorkflowMemories::StateTransition.new(
        from: :idle,
        to: :planning,
        event: :start,
        source: "test",
        payload: {},
        duration: "not numeric",
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/duration must be Numeric/, error.message)
  end

  speed_profile :fast
  test "is frozen after creation" do
    transition = WorkflowMemories::StateTransition.new(
      from: :idle,
      to: :planning,
      event: :start,
      source: "test",
      payload: {},
      duration: 0.0,
      checkpoint_id: "abc",
      state: :planning
    )

    assert transition.frozen?
  end

  speed_profile :fast
  test "vectorizable_content describes transition" do
    transition = WorkflowMemories::StateTransition.new(
      from: :idle,
      to: :executing,
      event: :go,
      source: "WorkflowEngine",
      payload: {},
      duration: 2.5,
      checkpoint_id: "abc",
      state: :executing
    )

    content = transition.vectorizable_content
    assert_includes content, "WorkflowEngine"
    assert_includes content, "idle"
    assert_includes content, "executing"
    assert_includes content, "go"
  end

  speed_profile :fast
  test "vectorizable_content includes payload keys" do
    transition = WorkflowMemories::StateTransition.new(
      from: :idle,
      to: :executing,
      event: :go,
      source: "test",
      payload: { step_id: "123", tool: "bash" },
      duration: 0.0,
      checkpoint_id: "abc",
      state: :executing
    )

    content = transition.vectorizable_content
    assert_includes content, "step_id"
    assert_includes content, "tool"
  end

  speed_profile :fast
  test "serializes to hash" do
    transition = WorkflowMemories::StateTransition.new(
      from: :idle,
      to: :planning,
      event: :start,
      source: "test",
      payload: { key: "value" },
      duration: 1.0,
      checkpoint_id: "abc",
      state: :planning
    )

    hash = transition.to_h
    assert_equal :idle, hash[:from]
    assert_equal :planning, hash[:to]
    assert_equal :start, hash[:event]
    assert_equal "test", hash[:source]
    assert_equal({ key: "value" }, hash[:payload])
    assert_equal 1.0, hash[:duration]
    assert_equal "abc", hash[:checkpoint_id]
    assert_equal :planning, hash[:state]
    assert_equal "state_transition", hash[:memory_type]
  end

  speed_profile :fast
  test "deserializes from hash" do
    original = WorkflowMemories::StateTransition.new(
      from: :idle,
      to: :planning,
      event: :start,
      source: "test",
      payload: { key: "value" },
      duration: 1.5,
      checkpoint_id: "abc",
      state: :planning
    )

    hash = original.to_h
    reconstructed = WorkflowMemories::StateTransition.from_h(hash)

    assert_equal original.from, reconstructed.from
    assert_equal original.to, reconstructed.to
    assert_equal original.event, reconstructed.event
    assert_equal original.source, reconstructed.source
    assert_equal original.payload, reconstructed.payload
    assert_equal original.duration, reconstructed.duration
  end

  speed_profile :fast
  test "from_h provides defaults for missing payload and duration" do
    hash = {
      from: :idle,
      to: :planning,
      event: :start,
      source: "test",
      checkpoint_id: "abc",
      state: :planning
    }

    transition = WorkflowMemories::StateTransition.from_h(hash)
    assert_equal({}, transition.payload)
    assert_equal 0.0, transition.duration
  end
end

