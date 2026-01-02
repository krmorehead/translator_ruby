# frozen_string_literal: true

require "test_helper"

module Graph
  class EdgeTest < ActiveSupport::TestCase
    speed_profile :fast
    test "creates edge with required parameters" do
      edge = Edge.new(
        from_node_id: "node_1",
        to_node_id: "node_2",
        edge_type: :parent_child
      )

      assert_equal "node_1", edge.from_node_id
      assert_equal "node_2", edge.to_node_id
      assert_equal :parent_child, edge.edge_type
      assert_equal({}, edge.metadata)
    end

    speed_profile :fast
    test "creates edge with metadata" do
      metadata = { relationship: :workflow_to_worker }
      edge = Edge.new(
        from_node_id: "node_1",
        to_node_id: "node_2",
        edge_type: :parent_child,
        metadata: metadata
      )

      assert_equal metadata, edge.metadata
    end

    speed_profile :fast
    test "validates from_node_id is required" do
      error = assert_raises(ArgumentError) do
        Edge.new(from_node_id: nil, to_node_id: "node_2", edge_type: :test)
      end
      assert_match(/from_node_id is required/, error.message)
    end

    speed_profile :fast
    test "validates to_node_id is required" do
      error = assert_raises(ArgumentError) do
        Edge.new(from_node_id: "node_1", to_node_id: nil, edge_type: :test)
      end
      assert_match(/to_node_id is required/, error.message)
    end

    speed_profile :fast
    test "validates edge_type is required" do
      error = assert_raises(ArgumentError) do
        Edge.new(from_node_id: "node_1", to_node_id: "node_2", edge_type: nil)
      end
      assert_match(/edge_type is required/, error.message)
    end

    speed_profile :fast
    test "validates metadata must be a Hash" do
      error = assert_raises(TypeError) do
        Edge.new(
          from_node_id: "node_1",
          to_node_id: "node_2",
          edge_type: :test,
          metadata: "not a hash"
        )
      end
      assert_match(/metadata must be a Hash/, error.message)
    end

    speed_profile :fast
    test "edge is frozen after creation" do
      edge = Edge.new(
        from_node_id: "node_1",
        to_node_id: "node_2",
        edge_type: :parent_child
      )

      assert edge.frozen?
    end

    speed_profile :fast
    test "serializes to hash" do
      edge = Edge.new(
        from_node_id: "node_1",
        to_node_id: "node_2",
        edge_type: :parent_child,
        metadata: { test: "value" }
      )
      hash = edge.to_h

      assert_equal "node_1", hash[:from_node_id]
      assert_equal "node_2", hash[:to_node_id]
      assert_equal :parent_child, hash[:edge_type]
      assert_equal({ test: "value" }, hash[:metadata])
      assert hash[:created_at].present?
    end
  end
end
