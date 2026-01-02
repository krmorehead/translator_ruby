# frozen_string_literal: true

# Edge from worker/workflow to a specific memory section.
# Carries metadata about the section type and access patterns.
module Graph
  module Edges
    class MemorySectionEdge < Graph::Edge
      attr_reader :section_name, :access_pattern

      # @param from_node_id [String] Owner node ID (worker or workflow)
      # @param to_node_id [String] Memory section node ID
      # @param section_name [Symbol, String] Name of the memory section
      # @param access_pattern [Symbol] How the section is accessed (:read, :write, :read_write)
      # @param metadata [Hash] Additional metadata about the relationship
      def initialize(from_node_id:, to_node_id:, section_name:, access_pattern: :read, metadata: {})
        raise ArgumentError, "section_name is required" if section_name.nil?

        @section_name = section_name.to_sym
        @access_pattern = access_pattern.to_sym

        super(
          from_node_id: from_node_id,
          to_node_id: to_node_id,
          edge_type: :memory_section,
          metadata: metadata.merge(
            section_name: @section_name,
            access_pattern: @access_pattern
          )
        )
      end
    end
  end
end

