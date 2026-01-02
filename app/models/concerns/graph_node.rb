# frozen_string_literal: true

# Concern for classes that participate in the ContextGraphService
# Classes including this concern will automatically register themselves
# and their edges when instantiated.
#
# Classes must implement:
#   - #graph_node_id - Returns unique identifier for this node
#   - #graph_node_type - Returns the type of node (:worker, :workflow, etc.)
#   - #define_graph_edges - Returns array of edge definitions
#
# Example edge definition:
#   { type: :parent_child, to: parent_id, metadata: {} }
#   { type: :memory_section, section: :decisions, metadata: {} }
module GraphNode
  extend ActiveSupport::Concern

  included do
    # Use prepend to wrap initialize
    prepend InitializeHook
  end

  module InitializeHook
    def initialize(*args, **kwargs, &block)
      # Call the original initialize from the class
      result = super
      
      # Register in graph after initialization completes (only once)
      return result if @graph_registered
      @graph_registered = true
      register_in_graph
      
      result
    end
  end

  private

  def register_in_graph
    service = ContextGraphService.instance
    
    # Create and register the node
    node = create_graph_node
    service.register_node(node)
    
    # Create and register all edges
    edges = define_graph_edges
    edges.each do |edge_def|
      edge = create_graph_edge(edge_def)
      service.add_edge(edge) if edge
    end
  end

  def create_graph_node
    case graph_node_type
    when :worker
      Graph::WorkerNode.new(
        id: graph_node_id, 
        metadata: { 
          klass_name: self.class.name,
          owner_id: respond_to?(:owner_id) ? owner_id : nil
        }
      ).tap do |node|
        node.memory_store = self
      end
    when :workflow
      Graph::WorkflowNode.new(
        id: graph_node_id, 
        metadata: { 
          klass_name: self.class.name,
          owner_id: respond_to?(:owner_id) ? owner_id : nil
        }
      ).tap do |node|
        node.workflow_memory = self
      end
    else
      raise ArgumentError, "Unknown node type: #{graph_node_type}"
    end
  end

  def create_graph_edge(edge_def)
    case edge_def[:type]
    when :parent_child
      return nil unless edge_def[:to] # No parent
      Graph::Edges::ParentChildEdge.new(
        from_node_id: graph_node_id,
        to_node_id: edge_def[:to],
        metadata: edge_def[:metadata] || {}
      )
    when :memory_section
      section_node_id = "#{graph_node_id}_#{edge_def[:section]}"
      
      # Create the memory section node directly without triggering GraphNode concern
      section_node = Graph::MemorySectionNode.allocate
      section_node.instance_variable_set(:@memory_store, self)
      section_node.instance_variable_set(:@section_name, edge_def[:section].to_sym)
      section_node.instance_variable_set(:@id, section_node_id)
      section_node.instance_variable_set(:@node_type, :memory_section)
      section_node.instance_variable_set(:@metadata, { section_name: edge_def[:section].to_sym })
      section_node.instance_variable_set(:@created_at, Time.now.utc)
      
      ContextGraphService.instance.register_node(section_node)
      
      # Create edge to the section
      Graph::Edges::MemorySectionEdge.new(
        from_node_id: graph_node_id,
        to_node_id: section_node_id,
        section_name: edge_def[:section],
        access_pattern: edge_def[:access_pattern] || :read_write,
        metadata: edge_def[:metadata] || {}
      )
    else
      raise ArgumentError, "Unknown edge type: #{edge_def[:type]}"
    end
  end

  # Methods that must be implemented by including classes
  def graph_node_id
    raise NotImplementedError, "#{self.class.name} must implement #graph_node_id"
  end

  def graph_node_type
    raise NotImplementedError, "#{self.class.name} must implement #graph_node_type"
  end

  def define_graph_edges
    raise NotImplementedError, "#{self.class.name} must implement #define_graph_edges"
  end
end

