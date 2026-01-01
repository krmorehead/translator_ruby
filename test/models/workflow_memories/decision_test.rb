# frozen_string_literal: true

require "test_helper"

class WorkflowMemories::DecisionTest < ActiveSupport::TestCase
  speed_profile :fast

  speed_profile :fast
  test "creates decision with required parameters" do
    decision = WorkflowMemories::Decision.new(
      decision: "Implement feature X",
      rationale: "Required for user story",
      context: { story_id: "123" },
      checkpoint_id: "abc123",
      state: :planning
    )

    assert_equal "Implement feature X", decision.decision
    assert_equal "Required for user story", decision.rationale
    assert_equal({ story_id: "123" }, decision.context)
    assert_equal "abc123", decision.checkpoint_id
    assert_equal :planning, decision.state
    assert_instance_of Time, decision.timestamp
  end

  speed_profile :fast
  test "validates decision is a String" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Decision.new(
        decision: 123,
        rationale: "test",
        context: {},
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/decision must be a String/, error.message)
  end

  speed_profile :fast
  test "validates decision is not empty" do
    error = assert_raises(ArgumentError) do
      WorkflowMemories::Decision.new(
        decision: "",
        rationale: "test",
        context: {},
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/decision cannot be empty/, error.message)
  end

  speed_profile :fast
  test "validates rationale is a String" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Decision.new(
        decision: "test",
        rationale: 123,
        context: {},
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/rationale must be a String/, error.message)
  end

  speed_profile :fast
  test "validates rationale is not empty" do
    error = assert_raises(ArgumentError) do
      WorkflowMemories::Decision.new(
        decision: "test",
        rationale: "",
        context: {},
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/rationale cannot be empty/, error.message)
  end

  speed_profile :fast
  test "validates context is a Hash" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Decision.new(
        decision: "test",
        rationale: "test",
        context: "not a hash",
        checkpoint_id: "abc",
        state: :planning
      )
    end
    assert_match(/context must be a Hash/, error.message)
  end

  speed_profile :fast
  test "is frozen after creation" do
    decision = WorkflowMemories::Decision.new(
      decision: "test",
      rationale: "test",
      context: {},
      checkpoint_id: "abc",
      state: :planning
    )

    assert decision.frozen?
  end

  speed_profile :fast
  test "vectorizable_content combines decision, rationale, and state" do
    decision = WorkflowMemories::Decision.new(
      decision: "Add logging",
      rationale: "Better debugging",
      context: {},
      checkpoint_id: "abc",
      state: :executing
    )

    content = decision.vectorizable_content
    assert_includes content, "Add logging"
    assert_includes content, "Better debugging"
    assert_includes content, "executing"
  end

  speed_profile :medium
  test "generates embedding lazily" do
    decision = WorkflowMemories::Decision.new(
      decision: "test decision",
      rationale: "test rationale",
      context: {},
      checkpoint_id: "abc",
      state: :planning
    )
    
    embedding1 = decision.embedding
    embedding2 = decision.embedding # Should be memoized

    assert_equal embedding1.object_id, embedding2.object_id
    assert_instance_of Embedding, embedding1
    assert_equal 384, embedding1.dimension
  end

  speed_profile :fast
  test "serializes to hash" do
    decision = WorkflowMemories::Decision.new(
      decision: "test",
      rationale: "because",
      context: { key: "value" },
      checkpoint_id: "abc",
      state: :planning
    )

    hash = decision.to_h
    assert_equal "test", hash[:decision]
    assert_equal "because", hash[:rationale]
    assert_equal({ key: "value" }, hash[:context])
    assert_equal "abc", hash[:checkpoint_id]
    assert_equal :planning, hash[:state]
    assert_equal "decision", hash[:memory_type]
    assert_kind_of String, hash[:timestamp]
  end

  speed_profile :fast
  test "deserializes from hash" do
    original = WorkflowMemories::Decision.new(
      decision: "test",
      rationale: "because",
      context: { key: "value" },
      checkpoint_id: "abc",
      state: :planning
    )

    hash = original.to_h
    reconstructed = WorkflowMemories::Decision.from_h(hash)

    assert_equal original.decision, reconstructed.decision
    assert_equal original.rationale, reconstructed.rationale
    assert_equal original.context, reconstructed.context
    assert_equal original.checkpoint_id, reconstructed.checkpoint_id
    assert_equal original.state, reconstructed.state
  end

  speed_profile :fast
  test "from_h validates input is a Hash" do
    error = assert_raises(TypeError) do
      WorkflowMemories::Decision.from_h("not a hash")
    end
    assert_match(/hash must be a Hash/, error.message)
  end

  speed_profile :medium
  test "similarity_to compares with another decision" do
    decision1 = WorkflowMemories::Decision.new(
      decision: "Implement logging",
      rationale: "Better debugging",
      context: {},
      checkpoint_id: "abc",
      state: :planning
    )

    decision2 = WorkflowMemories::Decision.new(
      decision: "Add error tracking",
      rationale: "Improved monitoring",
      context: {},
      checkpoint_id: "def",
      state: :planning
    )
    
    similarity = decision1.similarity_to(decision2)
    assert similarity >= 0.0
    assert similarity <= 1.0
    # These decisions are related (both about code quality/monitoring)
    # so similarity should be reasonably high
    assert similarity > 0.5, "Related decisions should have similarity > 0.5, got #{similarity}"
  end

  speed_profile :fast
  test "similarity_to validates input is BaseMemory" do
    decision = WorkflowMemories::Decision.new(
      decision: "test",
      rationale: "test",
      context: {},
      checkpoint_id: "abc",
      state: :planning
    )

    error = assert_raises(TypeError) do
      decision.similarity_to("not a memory")
    end
    assert_match(/other must be a WorkflowMemories::BaseMemory/, error.message)
  end
end

