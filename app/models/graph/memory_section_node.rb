# frozen_string_literal: true

# Node representing a specific memory section.
# Used when creating fine-grained access control to memory sections.
module Graph
  class MemorySectionNode < Node
    attr_reader :memory_store, :section_name

    # @param id [String] Unique identifier for this section node
    # @param memory_store [MemoryStore, WorkflowMemoryStore, ResearchMemoryStore] The parent store
    # @param section_name [Symbol, String] Name of the memory section
    def initialize(id:, memory_store:, section_name:)
      raise ArgumentError, "section_name is required" if section_name.nil?

      @memory_store = memory_store
      @section_name = section_name.to_sym
      
      super(
        id: id,
        node_type: :memory_section,
        metadata: { section_name: @section_name }
      )
    end

    # Query this memory section for relevant context
    # @param context_type [Symbol] Type of context to retrieve
    # @param query_embedding [Embedding] Vector to search with
    # @param threshold [Float] Minimum similarity threshold
    # @return [Array<Hash>] Array of {memory:, similarity:, source:}
    def query_context(context_type:, query_embedding:, threshold: 0.0)
      # Check if this section matches the requested context type
      sections = Graph::ContextTypeRegistry.sections_for(context_type)
      return [] unless sections.include?(@section_name)

      # Get section data (may be a Proc that needs to be called)
      data = @section_data.respond_to?(:call) ? @section_data.call : @section_data
      return [] unless data&.any?

      service = VectorizationService.new
      results = []

      data.each do |entry|
        next unless entry

        begin
          # Get or generate embedding
          entry_embedding = if entry.respond_to?(:embedding)
            entry.embedding
          else
            service.vectorize(text: entry.to_s)
          end

          similarity = query_embedding.similarity_to(entry_embedding)
          next if similarity < threshold

          results << {
            memory: entry,
            similarity: similarity,
            source: "section:#{section_name}"
          }
        rescue StandardError => e
          Rails.logger.warn "[MemorySectionNode] Failed to process entry: #{e.message}"
          next
        end
      end

      results
    end
  end
end

