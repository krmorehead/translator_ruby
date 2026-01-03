# frozen_string_literal: true

# Generic parent-child edge for workflow→worker OR workflow→workflow relationships.
# This single edge type handles all hierarchical relationships in the graph.
module Graph
  module Edges
    class ParentChildEdge < Graph::Edge
      # @param from_node_id [String] Child node ID (workflow)
      # @param to_node_id [String] Parent node ID (worker or workflow)
      # @param metadata [Hash] Additional relationship metadata
      # @option metadata [Symbol] :relationship Type of relationship (:workflow_to_worker, :workflow_to_workflow)
      def initialize(from_node_id:, to_node_id:, metadata: {})
        super(
          from_node_id: from_node_id,
          to_node_id: to_node_id,
          edge_type: :parent_child,
          metadata: metadata
        )
      end
    end
  end
end








