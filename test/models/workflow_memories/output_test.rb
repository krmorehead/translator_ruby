# frozen_string_literal: true

require "test_helper"

class WorkflowMemories::OutputTest < ActiveSupport::TestCase
  speed_profile :fast

  speed_profile :fast
  test "creates output with required parameters" do
    output = WorkflowMemories::Output.new(
      output_data: { result: "success", count: 42 },
      checkpoint_id: "abc123",
      state: :complete
    )

    assert_equal({ result: "success", count: 42 }, output.output_data)
    assert_equal "abc123", output.checkpoint_id
    assert_equal :complete, output.state
  end

  speed_profile :fast
  test "validates output_data is a Hash" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Output.new(
        output_data: "not a hash",
        checkpoint_id: "abc",
        state: :complete
      )
    end
    assert_match(/output_data must be a Hash/, error.message)
  end

  speed_profile :fast
  test "validates output_data is not empty" do
    error = assert_raises(ArgumentError) do
      WorkflowMemories::Output.new(
        output_data: {},
        checkpoint_id: "abc",
        state: :complete
      )
    end
    assert_match(/output_data cannot be empty/, error.message)
  end

  speed_profile :fast
  test "is frozen after creation" do
    output = WorkflowMemories::Output.new(
      output_data: { key: "value" },
      checkpoint_id: "abc",
      state: :complete
    )

    assert output.frozen?
  end

  speed_profile :fast
  test "vectorizable_content summarizes output with type info" do
    output = WorkflowMemories::Output.new(
      output_data: { message: "Hello", count: 5, success: true },
      checkpoint_id: "abc",
      state: :complete
    )

    content = output.vectorizable_content
    assert_includes content, "message"
    assert_includes content, "count"
    assert_includes content, "success"
    assert_includes content, "complete"
  end

  speed_profile :fast
  test "value_type_summary handles Strings" do
    output = WorkflowMemories::Output.new(
      output_data: { text: "Hello World" },
      checkpoint_id: "abc",
      state: :complete
    )

    content = output.vectorizable_content
    assert_includes content, "String(11 chars)"
  end

  speed_profile :fast
  test "value_type_summary handles Arrays" do
    output = WorkflowMemories::Output.new(
      output_data: { items: [1, 2, 3] },
      checkpoint_id: "abc",
      state: :complete
    )

    content = output.vectorizable_content
    assert_includes content, "Array(3 items)"
  end

  speed_profile :fast
  test "value_type_summary handles nested Hashes" do
    output = WorkflowMemories::Output.new(
      output_data: { config: { host: "localhost", port: 3000 } },
      checkpoint_id: "abc",
      state: :complete
    )

    content = output.vectorizable_content
    assert_includes content, "Hash(host, port)"
  end

  speed_profile :fast
  test "value_type_summary handles Numbers" do
    output = WorkflowMemories::Output.new(
      output_data: { count: 42, ratio: 3.14 },
      checkpoint_id: "abc",
      state: :complete
    )

    content = output.vectorizable_content
    assert_includes content, "Number(42)"
    assert_includes content, "Number(3.14)"
  end

  speed_profile :fast
  test "value_type_summary handles Booleans" do
    output = WorkflowMemories::Output.new(
      output_data: { success: true, failed: false },
      checkpoint_id: "abc",
      state: :complete
    )

    content = output.vectorizable_content
    assert_includes content, "Boolean(true)"
    assert_includes content, "Boolean(false)"
  end

  speed_profile :fast
  test "serializes to hash" do
    output = WorkflowMemories::Output.new(
      output_data: { result: "done" },
      checkpoint_id: "abc",
      state: :complete
    )

    hash = output.to_h
    assert_equal({ result: "done" }, hash[:output_data])
    assert_equal "abc", hash[:checkpoint_id]
    assert_equal :complete, hash[:state]
    assert_equal "output", hash[:memory_type]
  end

  speed_profile :fast
  test "deserializes from hash" do
    original = WorkflowMemories::Output.new(
      output_data: { result: "success", count: 10 },
      checkpoint_id: "abc",
      state: :complete
    )

    hash = original.to_h
    reconstructed = WorkflowMemories::Output.from_h(hash)

    assert_equal original.output_data, reconstructed.output_data
    assert_equal original.checkpoint_id, reconstructed.checkpoint_id
    assert_equal original.state, reconstructed.state
  end

  speed_profile :fast
  test "from_h uses entire hash as fallback for output_data" do
    hash = {
      result: "success",
      checkpoint_id: "abc",
      state: :complete
    }

    output = WorkflowMemories::Output.from_h(hash)
    # Should use the entire hash as output_data
    assert_equal hash, output.output_data
  end
end

