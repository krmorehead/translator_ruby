# frozen_string_literal: true

require "test_helper"

class ContextGraphServiceTest < ActiveSupport::TestCase
  setup do
    @service = ContextGraphService.instance
    # Clear graph between tests
    @service.instance_variable_set(:@nodes, {})
    @service.instance_variable_set(:@edges, [])
  end

  speed_profile :fast
  test "registers nodes in the graph" do
    node = Graph::Node.new(id: "test_1", node_type: :test)
    @service.register_node(node)

    nodes = @service.nodes
    assert_equal 1, nodes.size
    assert_equal "test_1", nodes.first.id
  end

  speed_profile :fast
  test "adds edges between nodes" do
    node1 = Graph::Node.new(id: "node_1", node_type: :test)
    node2 = Graph::Node.new(id: "node_2", node_type: :test)
    @service.register_node(node1)
    @service.register_node(node2)

    edge = Graph::Edge.new(
      from_node_id: "node_1",
      to_node_id: "node_2",
      edge_type: :test_edge
    )
    @service.add_edge(edge)

    edges = @service.edges
    assert_equal 1, edges.size
    assert_equal "node_1", edges.first.from_node_id
    assert_equal "node_2", edges.first.to_node_id
  end

  speed_profile :fast
  test "calculates degradation correctly" do
    service = @service

    # Distance 0 = 1.0
    assert_in_delta 1.0, service.send(:calculate_degradation, 0), 0.01

    # Distance 1 = 0.77
    assert_in_delta 0.77, service.send(:calculate_degradation, 1), 0.01

    # Distance 2 = 0.625
    assert_in_delta 0.625, service.send(:calculate_degradation, 2), 0.01

    # Distance 3 = 0.526
    assert_in_delta 0.526, service.send(:calculate_degradation, 3), 0.01
  end

  speed_profile :fast
  test "calculates max distance for threshold" do
    service = @service

    # With threshold 0.7, max distance should be 1
    assert_equal 2, service.send(:calculate_max_distance, 0.7)

    # With threshold 0.5, max distance should be 3
    assert_equal 4, service.send(:calculate_max_distance, 0.5)

    # With threshold 0.9, max distance should be 0
    assert_equal 1, service.send(:calculate_max_distance, 0.9)
  end

  speed_profile :fast
  test "unregisters nodes and removes related edges" do
    node1 = Graph::Node.new(id: "node_1", node_type: :test)
    node2 = Graph::Node.new(id: "node_2", node_type: :test)
    @service.register_node(node1)
    @service.register_node(node2)

    edge = Graph::Edge.new(
      from_node_id: "node_1",
      to_node_id: "node_2",
      edge_type: :test_edge
    )
    @service.add_edge(edge)

    @service.unregister_node("node_1")

    assert_equal 1, @service.nodes.size
    assert_equal 0, @service.edges.size
  end

  speed_profile :fast
  test "validates node type when registering" do
    error = assert_raises(TypeError) do
      @service.register_node("not a node")
    end
    assert_match(/must be a Graph::Node/, error.message)
  end

  speed_profile :fast
  test "validates edge type when adding" do
    error = assert_raises(TypeError) do
      @service.add_edge("not an edge")
    end
    assert_match(/must be a Graph::Edge/, error.message)
  end
end
