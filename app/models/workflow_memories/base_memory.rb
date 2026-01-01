# frozen_string_literal: true

module WorkflowMemories
  # Base class for all workflow memory entries.
  # Provides common fields and behaviors for different memory types.
  class BaseMemory
    attr_reader :id, :checkpoint_id, :state, :created_at
    alias_method :timestamp, :created_at

    # @param checkpoint_id [String] Checkpoint ID at time of creation
    # @param state [Symbol] Workflow state at time of creation
    def initialize(checkpoint_id:, state:)
      raise TypeError, "checkpoint_id must be a String, got #{checkpoint_id.class}" unless checkpoint_id.is_a?(String)
      raise TypeError, "state must be a Symbol, got #{state.class}" unless state.is_a?(Symbol)
      raise ArgumentError, "checkpoint_id cannot be empty" if checkpoint_id.empty?

      @id = SecureRandom.uuid
      @checkpoint_id = checkpoint_id.freeze
      @state = state.freeze
      @created_at = Time.now.utc
    end

    # Get or generate embedding for this memory
    # Note: Embedding is lazily generated and cached in a class variable hash
    # since memory objects are frozen after creation
    # @return [Embedding] Vector embedding for similarity search
    def embedding
      @@embedding_cache ||= {}
      cache_key = "#{self.class.name}:#{@id}"
      
      @@embedding_cache[cache_key] ||= VectorizationService.new.vectorize(text: vectorizable_content)
    end

    # Calculate similarity to another memory
    # @param other [BaseMemory] Another memory object
    # @return [Float] Similarity score 0.0-1.0
    def similarity_to(other)
      raise TypeError, "other must be a WorkflowMemories::BaseMemory, got #{other.class}" unless other.is_a?(BaseMemory)
      embedding.similarity_to(other.embedding)
    end

    # Content to use for vectorization (must be overridden by subclasses)
    # @return [String] Text representation for embedding
    def vectorizable_content
      raise NotImplementedError, "Subclasses must implement #vectorizable_content"
    end

    # Serialize to hash
    # @return [Hash] Hash representation
    def to_h
      {
        id: @id,
        checkpoint_id: @checkpoint_id,
        state: @state,
        created_at: @created_at.iso8601,
        timestamp: @created_at.iso8601,
        memory_type: memory_type
      }
    end

    # Type identifier for deserialization
    # @return [String] Class name without module
    def memory_type
      self.class.name.demodulize.underscore
    end
  end
end
