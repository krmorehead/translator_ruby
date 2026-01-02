# frozen_string_literal: true

require "test_helper"

module Graph
  module Edges
    class ParentChildEdgeTest < ActiveSupport::TestCase
      speed_profile :fast
      test "creates parent-child edge" do
        edge = ParentChildEdge.new(
          from_node_id: "workflow_1",
          to_node_id: "worker_1"
        )

        assert_equal "workflow_1", edge.from_node_id
        assert_equal "worker_1", edge.to_node_id
        assert_equal :parent_child, edge.edge_type
      end

      speed_profile :fast
      test "creates edge with metadata" do
        metadata = { relationship: :workflow_to_worker }
        edge = ParentChildEdge.new(
          from_node_id: "workflow_1",
          to_node_id: "worker_1",
          metadata: metadata
        )

        assert_equal metadata, edge.metadata
      end

      speed_profile :fast
      test "edge type is always parent_child" do
        edge = ParentChildEdge.new(
          from_node_id: "workflow_1",
          to_node_id: "worker_1"
        )

        assert_equal :parent_child, edge.edge_type
      end
    end

    class MemorySectionEdgeTest < ActiveSupport::TestCase
      speed_profile :fast
      test "creates memory section edge" do
        edge = MemorySectionEdge.new(
          from_node_id: "worker_1",
          to_node_id: "section_1",
          section_name: :decisions
        )

        assert_equal "worker_1", edge.from_node_id
        assert_equal "section_1", edge.to_node_id
        assert_equal :memory_section, edge.edge_type
        assert_equal :decisions, edge.section_name
      end

      speed_profile :fast
      test "includes section name in metadata" do
        edge = MemorySectionEdge.new(
          from_node_id: "worker_1",
          to_node_id: "section_1",
          section_name: :decisions
        )

        assert_equal :decisions, edge.metadata[:section_name]
      end

      speed_profile :fast
      test "sets default access pattern to read" do
        edge = MemorySectionEdge.new(
          from_node_id: "worker_1",
          to_node_id: "section_1",
          section_name: :decisions
        )

        assert_equal :read, edge.access_pattern
        assert_equal :read, edge.metadata[:access_pattern]
      end

      speed_profile :fast
      test "accepts custom access pattern" do
        edge = MemorySectionEdge.new(
          from_node_id: "worker_1",
          to_node_id: "section_1",
          section_name: :decisions,
          access_pattern: :read_write
        )

        assert_equal :read_write, edge.access_pattern
      end

      speed_profile :fast
      test "validates section_name is required" do
        error = assert_raises(ArgumentError) do
          MemorySectionEdge.new(
            from_node_id: "worker_1",
            to_node_id: "section_1",
            section_name: nil
          )
        end
        assert_match(/section_name is required/, error.message)
      end
    end
  end
end
