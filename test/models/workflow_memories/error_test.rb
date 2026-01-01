# frozen_string_literal: true

require "test_helper"

class WorkflowMemories::ErrorTest < ActiveSupport::TestCase
  speed_profile :fast

  speed_profile :fast
  test "creates error with required parameters" do
    error_memory = WorkflowMemories::Error.new(
      error_message: "Connection timeout",
      error_class: "NetworkError",
      checkpoint_id: "abc123",
      state: :executing
    )

    assert_equal "Connection timeout", error_memory.error_message
    assert_equal "NetworkError", error_memory.error_class
    assert_equal "abc123", error_memory.checkpoint_id
    assert_equal :executing, error_memory.state
  end

  speed_profile :fast
  test "validates error_message is a String" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Error.new(
        error_message: 123,
        error_class: "Error",
        checkpoint_id: "abc",
        state: :executing
      )
    end
    assert_match(/error_message must be a String/, error.message)
  end

  speed_profile :fast
  test "validates error_message is not empty" do
    error = assert_raises(ArgumentError) do
      WorkflowMemories::Error.new(
        error_message: "",
        error_class: "Error",
        checkpoint_id: "abc",
        state: :executing
      )
    end
    assert_match(/error_message cannot be empty/, error.message)
  end

  speed_profile :fast
  test "validates error_class is a String" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Error.new(
        error_message: "test",
        error_class: StandardError,
        checkpoint_id: "abc",
        state: :executing
      )
    end
    assert_match(/error_class must be a String/, error.message)
  end

  speed_profile :fast
  test "is frozen after creation" do
    error_memory = WorkflowMemories::Error.new(
      error_message: "test",
      error_class: "Error",
      checkpoint_id: "abc",
      state: :executing
    )

    assert error_memory.frozen?
  end

  speed_profile :fast
  test "vectorizable_content includes error details" do
    error_memory = WorkflowMemories::Error.new(
      error_message: "Database connection failed",
      error_class: "ActiveRecord::ConnectionError",
      checkpoint_id: "abc",
      state: :fetching_data
    )

    content = error_memory.vectorizable_content
    assert_includes content, "ActiveRecord::ConnectionError"
    assert_includes content, "Database connection failed"
    assert_includes content, "fetching_data"
  end

  speed_profile :fast
  test "serializes to hash" do
    error_memory = WorkflowMemories::Error.new(
      error_message: "test error",
      error_class: "TestError",
      checkpoint_id: "abc",
      state: :executing
    )

    hash = error_memory.to_h
    assert_equal "test error", hash[:error_message]
    assert_equal "TestError", hash[:error_class]
    assert_equal "abc", hash[:checkpoint_id]
    assert_equal :executing, hash[:state]
    assert_equal "error", hash[:memory_type]
  end

  speed_profile :fast
  test "deserializes from hash" do
    original = WorkflowMemories::Error.new(
      error_message: "test error",
      error_class: "TestError",
      checkpoint_id: "abc",
      state: :executing
    )

    hash = original.to_h
    reconstructed = WorkflowMemories::Error.from_h(hash)

    assert_equal original.error_message, reconstructed.error_message
    assert_equal original.error_class, reconstructed.error_class
    assert_equal original.checkpoint_id, reconstructed.checkpoint_id
    assert_equal original.state, reconstructed.state
  end

  speed_profile :fast
  test "from_h handles legacy :error key" do
    hash = {
      error: "Something went wrong",
      checkpoint_id: "abc",
      state: :executing
    }

    error_memory = WorkflowMemories::Error.from_h(hash)
    assert_equal "Something went wrong", error_memory.error_message
    assert_equal "StandardError", error_memory.error_class
  end

  speed_profile :fast
  test "from_h provides default error_class" do
    hash = {
      error_message: "test",
      checkpoint_id: "abc",
      state: :executing
    }

    error_memory = WorkflowMemories::Error.from_h(hash)
    assert_equal "StandardError", error_memory.error_class
  end
end

