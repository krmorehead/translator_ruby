# frozen_string_literal: true

require "test_helper"

class ContextGraphIntegrationTest < ActiveSupport::TestCase
  setup do
    # Clear the graph between tests
    service = ContextGraphService.instance
    service.instance_variable_set(:@nodes, {})
    service.instance_variable_set(:@edges, [])
    
    @temp_dir = Dir.mktmpdir
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if @temp_dir
  end

  speed_profile :fast
  test "memory stores automatically register in graph when created" do
    # Create a memory store
    store1 = MemoryStore.new(owner_id: "owner-123")
    
    # Verify it's registered
    service = ContextGraphService.instance
    nodes = service.instance_variable_get(:@nodes)
    
    assert nodes.key?(store1.id), "MemoryStore should be registered in graph"
    assert_instance_of Graph::WorkerNode, nodes[store1.id]
    assert_equal store1, nodes[store1.id].memory_store
  end

  speed_profile :fast
  test "research memory stores automatically register in graph when created" do
    # Create a research memory store using factory (OOP pattern)
    store = build(:research_memory_store)
    
    # Verify it's registered
    service = ContextGraphService.instance
    node = service.find_by_id(store.id)
    
    assert_not_nil node, "ResearchMemoryStore should be registered in graph"
    # ResearchMemoryStore inherits from WorkflowMemoryStore, so it's a WorkflowNode
    assert_instance_of Graph::WorkflowNode, node
    assert_equal store, node.workflow_memory
  end

  speed_profile :fast
  test "workflow memory stores automatically register with parent edges" do
    # Create parent memory store
    parent_store = MemoryStore.new(owner_id: "owner-123")
    
    # Create workflow memory store with parent
    workflow_store = WorkflowMemoryStore.new(
      workflow_id: SecureRandom.uuid,
      workflow_name: "test_workflow",
      parent_id: parent_store.id,
      owner_id: "owner-123"
    )
    
    # Verify both are registered
    service = ContextGraphService.instance
    nodes = service.instance_variable_get(:@nodes)
    edges = service.instance_variable_get(:@edges)
    
    assert nodes.key?(parent_store.id), "Parent store should be registered"
    assert nodes.key?(workflow_store.workflow_id), "Workflow store should be registered"
    
    # Verify edge exists from workflow to parent
    parent_edge = edges.find do |e|
      e.from_node_id == workflow_store.workflow_id && 
      e.to_node_id == parent_store.id
    end
    
    assert parent_edge, "Should have edge from workflow to parent"
    assert_instance_of Graph::Edges::ParentChildEdge, parent_edge
  end

  speed_profile :fast
  test "can query across registered nodes" do
    # Create a memory hierarchy
    parent_store = MemoryStore.new(owner_id: "owner-123")
    
    # Add some data to parent
    parent_store.update_section(
      name: :decisions,
      content: { text: "Decided to use Ruby on Rails", timestamp: Time.now.utc.iso8601 }
    )
    
    # Create workflow with parent
    workflow_id = SecureRandom.uuid
    workflow_store = WorkflowMemoryStore.new(
      workflow_id: workflow_id,
      workflow_name: "test_workflow",
      parent_id: parent_store.id,
      owner_id: "owner-123"
    )
    
    # Verify we can access both nodes
    service = ContextGraphService.instance
    nodes = service.instance_variable_get(:@nodes)
    
    # MemoryStore creates 1 node + its sections (11), WorkflowMemoryStore creates 1 node + its sections (6)
    assert nodes.size > 2, "Should have parent node, workflow node, and their section nodes"
    
    # Verify parent node
    parent_node = nodes[parent_store.id]
    assert_instance_of Graph::WorkerNode, parent_node
    assert_equal parent_store, parent_node.memory_store
    
    # Verify workflow node
    workflow_node = nodes[workflow_id]
    assert_instance_of Graph::WorkflowNode, workflow_node
    assert_equal workflow_store, workflow_node.workflow_memory
  end

  speed_profile :fast
  test "multiple memory stores all register independently" do
    # Create multiple stores
    store1 = MemoryStore.new(owner_id: "owner-1")
    store2 = MemoryStore.new(owner_id: "owner-2")
    store3 = ResearchMemoryStore.new(
      workflow_id: SecureRandom.uuid,
      workflow_name: "test_research",
      parent_id: "root",
      owner_id: "owner-3"
    )
    
    # Verify all are registered
    service = ContextGraphService.instance
    nodes = service.instance_variable_get(:@nodes)
    
    # Each memory store creates 1 node + sections, so more than 3 nodes total
    assert nodes.size > 3, "Should have all stores and their section nodes"
    assert nodes.key?(store1.id)
    assert nodes.key?(store2.id)
    assert nodes.key?(store3.id)
  end

  speed_profile :fast
  test "workflow with nested parent relationships creates proper edges" do
    # Create grandparent (worker memory)
    grandparent = MemoryStore.new(owner_id: "owner-123")
    
    # Create parent workflow
    parent_wf_id = SecureRandom.uuid
    parent_workflow = WorkflowMemoryStore.new(
      workflow_id: parent_wf_id,
      workflow_name: "parent_workflow",
      parent_id: grandparent.id,
      owner_id: "owner-123"
    )
    
    # Create child workflow
    child_wf_id = SecureRandom.uuid
    child_workflow = WorkflowMemoryStore.new(
      workflow_id: child_wf_id,
      workflow_name: "child_workflow",
      parent_id: parent_wf_id,
      owner_id: "owner-123"
    )
    
    # Verify all nodes registered
    service = ContextGraphService.instance
    nodes = service.instance_variable_get(:@nodes)
    edges = service.instance_variable_get(:@edges)
    
    # More than 3 nodes due to section nodes
    assert nodes.size > 3, "Should have all nodes and section nodes"
    
    # Verify main nodes exist
    assert nodes.key?(grandparent.id)
    assert nodes.key?(parent_wf_id)
    assert nodes.key?(child_wf_id)
    
    # Verify edges - should have parent_child edges
    parent_edges = edges.select { |e| e.is_a?(Graph::Edges::ParentChildEdge) }
    assert_equal 2, parent_edges.size, "Should have 2 parent_child edges"
    
    # Find edge from parent workflow to grandparent
    parent_edge = parent_edges.find { |e| e.from_node_id == parent_wf_id }
    assert parent_edge, "Parent workflow should have edge to grandparent"
    assert_equal grandparent.id, parent_edge.to_node_id
    
    # Find edge from child workflow to parent workflow
    child_edge = parent_edges.find { |e| e.from_node_id == child_wf_id }
    assert child_edge, "Child workflow should have edge to parent"
    assert_equal parent_wf_id, child_edge.to_node_id
  end
end

