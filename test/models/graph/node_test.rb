# frozen_string_literal: true

require "test_helper"

module Graph
  class NodeTest < ActiveSupport::TestCase
    speed_profile :fast
    test "creates node with required parameters" do
      node = Node.new(id: "test_1", node_type: :worker)

      assert_equal "test_1", node.id
      assert_equal :worker, node.node_type
      assert_equal({}, node.metadata)
    end

    speed_profile :fast
    test "creates node with metadata" do
      metadata = { owner_id: "owner_123" }
      node = Node.new(id: "test_1", node_type: :worker, metadata: metadata)

      assert_equal metadata, node.metadata
    end

    speed_profile :fast
    test "validates id is required" do
      error = assert_raises(ArgumentError) do
        Node.new(id: nil, node_type: :worker)
      end
      assert_match(/id is required/, error.message)
    end

    speed_profile :fast
    test "validates id is not empty" do
      error = assert_raises(ArgumentError) do
        Node.new(id: "", node_type: :worker)
      end
      assert_match(/id is required/, error.message)
    end

    speed_profile :fast
    test "validates node_type is required" do
      error = assert_raises(ArgumentError) do
        Node.new(id: "test_1", node_type: nil)
      end
      assert_match(/node_type is required/, error.message)
    end

    speed_profile :fast
    test "validates metadata must be a Hash" do
      error = assert_raises(TypeError) do
        Node.new(id: "test_1", node_type: :worker, metadata: "not a hash")
      end
      assert_match(/metadata must be a Hash/, error.message)
    end

    speed_profile :fast
    test "node is not frozen to allow subclass attribute setting" do
      node = Node.new(id: "test_1", node_type: :worker)

      refute node.frozen?
    end

    speed_profile :fast
    test "serializes to hash" do
      node = Node.new(id: "test_1", node_type: :worker, metadata: { test: "value" })
      hash = node.to_h

      assert_equal "test_1", hash[:id]
      assert_equal :worker, hash[:node_type]
      assert_equal({ test: "value" }, hash[:metadata])
      assert hash[:created_at].present?
    end

    speed_profile :fast
    test "query_context raises NotImplementedError in base class" do
      node = Node.new(id: "test_1", node_type: :worker)

      error = assert_raises(NotImplementedError) do
        node.query_context(
          context_type: :test,
          query_embedding: nil,
          threshold: 0.7
        )
      end
      assert_match(/must implement #query_context/, error.message)
    end
  end
end
