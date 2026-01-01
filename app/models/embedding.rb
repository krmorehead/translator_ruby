# frozen_string_literal: true

# Domain object representing a vector embedding.
# Immutable value object containing a dense vector representation of text.
# Supports variable dimensions based on the embedding model used.
#
# @example
#   embedding = Embedding.new(vector: [0.123, -0.456, 0.789, ...], text: "User decided X")
#   embedding.dimension  # => 384 or 1536
#   embedding.vector     # => [0.123, -0.456, ...]
class Embedding
  # Standard dimension for OpenAI text-embedding-3-small
  STANDARD_DIMENSION = 1536
  
  # Dimension for all-MiniLM-L6-v2
  MINI_DIMENSION = 384
  
  # Supported embedding dimensions
  SUPPORTED_DIMENSIONS = [MINI_DIMENSION, STANDARD_DIMENSION].freeze

  attr_reader :vector, :text, :dimension, :created_at

  # @param vector [Array<Float>] The embedding vector
  # @param text [String] The original text that was embedded
  # @raise [TypeError] If parameters are wrong type
  # @raise [ArgumentError] If vector has wrong dimension
  def initialize(vector:, text:)
    raise TypeError, "vector must be an Array, got #{vector.class}" unless vector.is_a?(Array)
    raise TypeError, "text must be a String, got #{text.class}" unless text.is_a?(String)
    raise ArgumentError, "text cannot be empty" if text.empty?
    raise ArgumentError, "vector cannot be empty" if vector.empty?
    raise ArgumentError, "vector must contain only Numeric values" unless vector.all? { |v| v.is_a?(Numeric) }
    raise ArgumentError, "vector dimension must be one of #{SUPPORTED_DIMENSIONS.join(', ')}, got #{vector.length}" unless SUPPORTED_DIMENSIONS.include?(vector.length)

    @vector = vector.freeze
    @text = text.freeze
    @dimension = vector.length
    @created_at = Time.now.utc.freeze
    freeze
  end

  # Calculate cosine similarity with another embedding
  # Embeddings must have the same dimension
  #
  # @param other [Embedding] Another embedding to compare with
  # @return [Float] Similarity score between 0.0 and 1.0
  # @raise [TypeError] If other is not an Embedding
  # @raise [ArgumentError] If dimensions don't match
  def similarity_to(other)
    raise TypeError, "other must be an Embedding, got #{other.class}" unless other.is_a?(Embedding)
    raise ArgumentError, "Cannot compare embeddings of different dimensions: #{@dimension} vs #{other.dimension}" unless @dimension == other.dimension

    dot_product = @vector.zip(other.vector).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(@vector.sum { |a| a * a })
    magnitude2 = Math.sqrt(other.vector.sum { |a| a * a })

    return 0.0 if magnitude1.zero? || magnitude2.zero?

    dot_product / (magnitude1 * magnitude2)
  end

  # Serialize to hash for storage
  #
  # @return [Hash] Serialized representation
  def to_h
    {
      vector: @vector,
      text: @text,
      dimension: @dimension,
      created_at: @created_at.iso8601
    }
  end

  # Deserialize from hash
  #
  # @param hash [Hash] Serialized embedding
  # @return [Embedding] Reconstructed embedding
  # @raise [TypeError] If hash is not a Hash
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
    raise ArgumentError, "hash must contain :vector key" unless hash.key?(:vector)
    raise ArgumentError, "hash must contain :text key" unless hash.key?(:text)

    new(
      vector: hash[:vector],
      text: hash[:text]
    )
  end
end

