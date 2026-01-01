# frozen_string_literal: true

# Service for generating vector embeddings from text using LLM.
# Returns Embedding domain objects for semantic similarity comparisons.
#
# @example Generate embedding for a memory
#   service = VectorizationService.new
#   embedding = service.vectorize(text: "User decided to implement feature X")
#   embedding.vector  # => [0.123, -0.456, 0.789, ...]
#
# @example Compare similarity between embeddings
#   similarity = embedding1.similarity_to(embedding2)
#   # => 0.87 (87% similar)
class VectorizationService
  # Minimum similarity threshold for considering memories related
  DEFAULT_SIMILARITY_THRESHOLD = 0.70

  def initialize
    @llm_client = GenericLlmClient.client_for(:embeddings)
  end

  # Generate an embedding for the given text
  #
  # @param text [String] The text to vectorize
  # @return [Embedding] Embedding object containing vector and metadata
  def vectorize(text:)
    @llm_client.embed(text: text)    
  end

  # Find memories above similarity threshold
  #
  # @param query_embedding [Embedding] The query embedding
  # @param memories [Array] Collection of memory objects with #embedding method
  # @param threshold [Float] Minimum similarity (0.0-1.0)
  # @return [Array<Hash>] Sorted array of {memory:, similarity:} hashes
  def find_similar(query_embedding:, memories:, threshold: DEFAULT_SIMILARITY_THRESHOLD)
    results = memories.filter_map do |memory|
      memory_embedding = memory.embedding
      similarity = query_embedding.similarity_to(memory_embedding)
      { memory: memory, similarity: similarity } if similarity >= threshold
    end

    results.sort_by { |r| -r[:similarity] }
  end
end

