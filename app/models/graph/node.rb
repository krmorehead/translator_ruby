# frozen_string_literal: true

# Base class for graph nodes representing queryable entities in the context graph.
# Each node can be queried for context using vector similarity search.
module Graph
  class Node
    attr_reader :id, :node_type, :metadata

    # @param id [String] Unique identifier for this node
    # @param node_type [Symbol] Type of node (:worker, :workflow, :memory_section)
    # @param metadata [Hash] Additional metadata about the node
    def initialize(id:, node_type:, metadata: {})
      raise ArgumentError, "id is required" if id.nil? || id.to_s.empty?
      raise ArgumentError, "node_type is required" if node_type.nil?
      raise TypeError, "metadata must be a Hash" unless metadata.is_a?(Hash)

      @id = id.to_s
      @node_type = node_type.to_sym
      @metadata = metadata
      @created_at = Time.now.utc
      # Don't freeze - allow subclasses to set their own attributes
    end

    # Query this node for relevant context.
    # Subclasses must implement this method to perform actual queries.
    #
    # @param context_type [Symbol] Type of context to retrieve
    # @param query_embedding [Embedding] Vector to search with
    # @param threshold [Float] Minimum similarity threshold (0.0-1.0)
    # @return [Array<Hash>] Array of {memory:, similarity:, source:}
    def query_context(context_type:, query_embedding:, threshold: 0.0)
      raise NotImplementedError, "#{self.class} must implement #query_context"
    end

    def to_h
      {
        id: @id,
        node_type: @node_type,
        metadata: @metadata,
        created_at: @created_at.iso8601
      }
    end
  end
end

