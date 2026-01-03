# frozen_string_literal: true

# Base class for graph edges representing relationships between nodes.
# Edges connect nodes in the context graph and enable traversal during queries.
module Graph
  class Edge
    attr_reader :from_node_id, :to_node_id, :edge_type, :metadata

    # @param from_node_id [String] Source node ID
    # @param to_node_id [String] Target node ID
    # @param edge_type [Symbol] Type of relationship (:parent_child, :memory_section)
    # @param metadata [Hash] Additional metadata about the relationship
    def initialize(from_node_id:, to_node_id:, edge_type:, metadata: {})
      raise ArgumentError, "from_node_id is required" if from_node_id.nil? || from_node_id.to_s.empty?
      raise ArgumentError, "to_node_id is required" if to_node_id.nil? || to_node_id.to_s.empty?
      raise ArgumentError, "edge_type is required" if edge_type.nil?
      raise TypeError, "metadata must be a Hash" unless metadata.is_a?(Hash)

      @from_node_id = from_node_id.to_s
      @to_node_id = to_node_id.to_s
      @edge_type = edge_type.to_sym
      @metadata = metadata
      @created_at = Time.now.utc
      freeze
    end

    def to_h
      {
        from_node_id: @from_node_id,
        to_node_id: @to_node_id,
        edge_type: @edge_type,
        metadata: @metadata,
        created_at: @created_at.iso8601
      }
    end
  end
end








