# frozen_string_literal: true

# Node wrapping a worker, delegates queries to its MemoryStore.
# Queries relevant memory sections and returns vector similarity results.
module Graph
  class WorkerNode < Node
    attr_accessor :memory_store

    # @param id [String] Unique identifier (typically worker's owner_id)
    # @param metadata [Hash] Additional metadata
    def initialize(id:, metadata: {})
      @memory_store = nil
      super(id: id, node_type: :worker, metadata: metadata)
    end

    # Query this worker's memory for relevant context
    # @param context_type [Symbol] Type of context to retrieve
    # @param query_embedding [Embedding] Vector to search with
    # @param threshold [Float] Minimum similarity threshold
    # @return [Array<Hash>] Array of {memory:, similarity:, source:}
    def query_context(context_type:, query_embedding:, threshold: 0.0)
      sections = Graph::ContextTypeRegistry.sections_for(context_type)
      return [] if sections.empty?

      service = VectorizationService.new
      results = []

      sections.each do |section_name|
        section_data = memory_store.get_section(section_name)
        next unless section_data&.any?

        # Query each entry in the section
        section_data.each do |entry|
          memory_obj = ensure_memory_object(entry, section_name)
          next unless memory_obj

          # Get or generate embedding for this memory
          begin
            memory_embedding = memory_obj.respond_to?(:embedding) ? memory_obj.embedding : service.vectorize(text: memory_obj.to_s)
            similarity = query_embedding.similarity_to(memory_embedding)
            next if similarity < threshold

            results << {
              memory: memory_obj,
              similarity: similarity,
              source: "worker:#{id}:#{section_name}"
            }
          rescue StandardError => e
            Rails.logger.warn "[WorkerNode] Failed to process memory: #{e.message}"
            next
          end
        end
      end

      results
    end

    private

    # Ensure entry is a memory object with proper interface
    # @param entry [Object] Entry from memory section
    # @param section_name [Symbol] Section this entry came from
    # @return [Object, nil] Memory object or nil if conversion failed
    def ensure_memory_object(entry, section_name)
      # If it's already a proper memory object, return it
      return entry if entry.respond_to?(:to_s)

      # Try to convert hash to memory object if registry knows about this section
      if entry.is_a?(Hash) && defined?(Memories::Registry)
        memory_class = Memories::Registry.for(section_name)
        return nil unless memory_class&.respond_to?(:from_h)

        memory_class.from_h(entry)
      else
        entry
      end
    rescue StandardError => e
      Rails.logger.warn "[WorkerNode] Failed to convert entry to memory object: #{e.message}"
      nil
    end
  end
end

