# frozen_string_literal: true

require "test_helper"

class WorkflowStateTest < ActiveSupport::TestCase
  speed_profile :fast
  test "initializes with defaults" do
    state = WorkflowState.new

    assert_equal :pending, state.status
    assert_nil state.prompt
    assert_equal({}, state.data)
    assert_nil state.error
    assert_predicate state, :pending?
    refute_predicate state, :running?
    refute_predicate state, :complete?
    refute_predicate state, :failed?
  end

  speed_profile :fast
  test "initializes with provided values" do
    data = { actions: 2 }
    state = WorkflowState.new(status: :running, prompt: "hi", data: data, error: "none")

    assert_equal :running, state.status
    assert_equal "hi", state.prompt
    assert_equal data, state.data
    assert_equal "none", state.error
  end

  speed_profile :fast
  test "with returns new instance and keeps immutability" do
    original = WorkflowState.new(status: :pending, prompt: "start")
    updated = original.with(status: :complete, data: { done: true })

    assert_equal :pending, original.status
    assert_equal :complete, updated.status
    assert_equal({ done: true }, updated.data)
    refute_equal original.object_id, updated.object_id
  end

  speed_profile :fast
  test "predicates work for all statuses" do
    assert_predicate WorkflowState.new(status: :complete), :complete?
    assert_predicate WorkflowState.new(status: :failed), :failed?
    assert_predicate WorkflowState.new(status: :pending), :pending?
    assert_predicate WorkflowState.new(status: :running), :running?
  end

  speed_profile :fast
  test "to_h serializes state" do
    state = WorkflowState.new(status: :failed, prompt: "oops", data: { step: 3 }, error: "boom")
    hash = state.to_h

    assert_equal :failed, hash[:status]
    assert_equal "oops", hash[:prompt]
    assert_equal({ step: 3 }, hash[:data])
    assert_equal "boom", hash[:error]
  end
end
