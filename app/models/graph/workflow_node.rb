# frozen_string_literal: true

# Node wrapping a workflow, delegates queries to WorkflowMemoryStore.
# Uses the workflow's query_context() method via the ContextGraphService.
module Graph
  class WorkflowNode < Node
    attr_accessor :workflow_memory
    
    # Alias for compatibility with code expecting memory_store
    alias_method :memory_store, :workflow_memory

    # @param id [String] Unique identifier (typically workflow_id)
    # @param metadata [Hash] Additional metadata
    def initialize(id:, metadata: {})
      @workflow_memory = nil
      super(id: id, node_type: :workflow, metadata: metadata)
    end

    # Query this workflow's memory for relevant context
    # @param context_type [Symbol] Type of context to retrieve
    # @param query_embedding [Embedding] Vector to search with
    # @param threshold [Float] Minimum similarity threshold
    # @return [Array<Hash>] Array of {memory:, similarity:, source:}
    def query_context(context_type:, query_embedding:, threshold: 0.0)
      # Get all memories from workflow
      all_memories = workflow_memory.all_memories
      return [] if all_memories.empty?

      # Get relevant sections for this context type
      sections = Graph::ContextTypeRegistry.sections_for(context_type)

      # If no specific sections, search all memories
      memories_to_search = if sections.any?
        all_memories.select { |m| sections.include?(infer_section(m)) }
      else
        all_memories
      end

      return [] if memories_to_search.empty?

      # Calculate similarity for each memory
      results = []
      memories_to_search.each do |memory|
        begin
          # Use the memory's embedding (generated lazily)
          similarity = query_embedding.similarity_to(memory.embedding)
          next if similarity < threshold

          results << {
            memory: memory,
            similarity: similarity,
            source: "workflow:#{id}:#{infer_section(memory)}"
          }
        rescue StandardError => e
          Rails.logger.warn "[WorkflowNode] Failed to process memory: #{e.message}"
          next
        end
      end

      results
    end

    private

    # Infer which section a memory belongs to based on its class
    # @param memory [Object] Memory object
    # @return [Symbol] Section name
    def infer_section(memory)
      case memory
      when WorkflowMemories::Decision
        :decisions
      when WorkflowMemories::StateTransition
        :state_transitions
      when WorkflowMemories::Context
        :workflow_context
      when WorkflowMemories::Error
        :errors
      when WorkflowMemories::Output
        :outputs
      else
        :unknown
      end
    end
  end
end

