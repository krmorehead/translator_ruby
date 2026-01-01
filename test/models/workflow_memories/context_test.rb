# frozen_string_literal: true

require "test_helper"

class WorkflowMemories::ContextTest < ActiveSupport::TestCase
  speed_profile :fast

  speed_profile :fast
  test "creates context with required parameters" do
    context = WorkflowMemories::Context.new(
      context_data: { user_id: "123", session: "abc" },
      checkpoint_id: "abc123",
      state: :planning
    )

    assert_equal({ user_id: "123", session: "abc" }, context.context_data)
    assert_equal "abc123", context.checkpoint_id
    assert_equal :planning, context.state
  end

  speed_profile :fast
  test "validates context_data is a Hash" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Context.new(
        context_data: "not a hash",
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/context_data must be a Hash/, error.message)
  end

  speed_profile :fast
  test "validates context_data is not empty" do
    error = assert_raises(ArgumentError) do
      WorkflowMemories::Context.new(
        context_data: {},
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/context_data cannot be empty/, error.message)
  end

  speed_profile :fast
  test "is frozen after creation" do
    context = WorkflowMemories::Context.new(
      context_data: { key: "value" },
      checkpoint_id: "abc",
      state: :planning
    )

    assert context.frozen?
  end

  speed_profile :fast
  test "vectorizable_content summarizes context" do
    context = WorkflowMemories::Context.new(
      context_data: { user_id: "123", feature: "logging" },
      checkpoint_id: "abc",
      state: :executing
    )

    content = context.vectorizable_content
    assert_includes content, "user_id"
    assert_includes content, "feature"
    assert_includes content, "executing"
  end

  speed_profile :fast
  test "vectorizable_content truncates long strings" do
    long_string = "a" * 100
    context = WorkflowMemories::Context.new(
      context_data: { description: long_string },
      checkpoint_id: "abc",
      state: :planning
    )

    content = context.vectorizable_content
    assert_includes content, "..."
    assert content.length < long_string.length + 100
  end

  speed_profile :fast
  test "vectorizable_content summarizes arrays" do
    context = WorkflowMemories::Context.new(
      context_data: { items: [1, 2, 3, 4, 5] },
      checkpoint_id: "abc",
      state: :planning
    )

    content = context.vectorizable_content
    assert_includes content, "5 items"
  end

  speed_profile :fast
  test "vectorizable_content summarizes nested hashes" do
    context = WorkflowMemories::Context.new(
      context_data: { config: { host: "localhost", port: 3000 } },
      checkpoint_id: "abc",
      state: :planning
    )

    content = context.vectorizable_content
    assert_includes content, "host, port"
  end

  speed_profile :fast
  test "serializes to hash" do
    context = WorkflowMemories::Context.new(
      context_data: { key: "value" },
      checkpoint_id: "abc",
      state: :planning
    )

    hash = context.to_h
    assert_equal({ key: "value" }, hash[:context_data])
    assert_equal "abc", hash[:checkpoint_id]
    assert_equal :planning, hash[:state]
    assert_equal "context", hash[:memory_type]
  end

  speed_profile :fast
  test "deserializes from hash" do
    original = WorkflowMemories::Context.new(
      context_data: { user: "admin", role: "superuser" },
      checkpoint_id: "abc",
      state: :planning
    )

    hash = original.to_h
    reconstructed = WorkflowMemories::Context.from_h(hash)

    assert_equal original.context_data, reconstructed.context_data
    assert_equal original.checkpoint_id, reconstructed.checkpoint_id
    assert_equal original.state, reconstructed.state
  end

  speed_profile :fast
  test "from_h provides default empty hash for missing context_data" do
    hash = {
      checkpoint_id: "abc",
      state: :planning
    }

    # Should raise because empty context_data is not allowed
    error = assert_raises(ArgumentError) do
      WorkflowMemories::Context.from_h(hash)
    end
    assert_match(/context_data cannot be empty/, error.message)
  end
end

