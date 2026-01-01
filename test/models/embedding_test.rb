# frozen_string_literal: true

require "test_helper"

class EmbeddingTest < ActiveSupport::TestCase
  speed_profile :fast
  test "initialize requires vector and text" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    
    embedding = Embedding.new(vector: vector, text: "test")
    
    assert_equal vector, embedding.vector
    assert_equal "test", embedding.text
    assert_equal Embedding::STANDARD_DIMENSION, embedding.dimension
  end

  speed_profile :fast
  test "initialize validates vector type" do
    error = assert_raises(TypeError) do
      Embedding.new(vector: "not an array", text: "test")
    end
    assert_match(/vector must be an Array/, error.message)
  end

  speed_profile :fast
  test "initialize validates text type" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    
    error = assert_raises(TypeError) do
      Embedding.new(vector: vector, text: 123)
    end
    assert_match(/text must be a String/, error.message)
  end

  speed_profile :fast
  test "initialize validates text not empty" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    
    error = assert_raises(ArgumentError) do
      Embedding.new(vector: vector, text: "")
    end
    assert_match(/text cannot be empty/, error.message)
  end

  speed_profile :fast
  test "initialize validates vector not empty" do
    error = assert_raises(ArgumentError) do
      Embedding.new(vector: [], text: "test")
    end
    assert_match(/vector cannot be empty/, error.message)
  end

  speed_profile :fast
  test "initialize validates vector contains only numbers" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { "not a number" }
    
    error = assert_raises(ArgumentError) do
      Embedding.new(vector: vector, text: "test")
    end
    assert_match(/vector must contain only Numeric/, error.message)
  end

  speed_profile :fast
  test "initialize validates vector dimension" do
    vector = [0.1, 0.2, 0.3]  # Wrong dimension
    
    error = assert_raises(ArgumentError) do
      Embedding.new(vector: vector, text: "test")
    end
    assert_match(/vector dimension must be one of/, error.message)
  end

  speed_profile :fast
  test "embedding is immutable" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    embedding = Embedding.new(vector: vector, text: "test")
    
    assert embedding.frozen?
    assert embedding.vector.frozen?
    assert embedding.text.frozen?
  end

  speed_profile :fast
  test "similarity_to calculates cosine similarity" do
    # Create two identical embeddings - should be 1.0 similarity
    vector1 = Array.new(Embedding::STANDARD_DIMENSION) { 1.0 }
    vector2 = Array.new(Embedding::STANDARD_DIMENSION) { 1.0 }
    
    emb1 = Embedding.new(vector: vector1, text: "test1")
    emb2 = Embedding.new(vector: vector2, text: "test2")
    
    similarity = emb1.similarity_to(emb2)
    assert_in_delta 1.0, similarity, 0.001
  end

  speed_profile :fast
  test "similarity_to with orthogonal vectors returns 0.0" do
    # Create orthogonal vectors - should be 0.0 similarity
    vector1 = Array.new(Embedding::STANDARD_DIMENSION) { |i| i.even? ? 1.0 : 0.0 }
    vector2 = Array.new(Embedding::STANDARD_DIMENSION) { |i| i.odd? ? 1.0 : 0.0 }
    
    emb1 = Embedding.new(vector: vector1, text: "test1")
    emb2 = Embedding.new(vector: vector2, text: "test2")
    
    similarity = emb1.similarity_to(emb2)
    assert_in_delta 0.0, similarity, 0.001
  end

  speed_profile :fast
  test "similarity_to validates parameter type" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    embedding = Embedding.new(vector: vector, text: "test")
    
    error = assert_raises(TypeError) do
      embedding.similarity_to("not an embedding")
    end
    assert_match(/other must be an Embedding/, error.message)
  end

  speed_profile :fast
  test "to_h serializes embedding" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    embedding = Embedding.new(vector: vector, text: "test")
    
    hash = embedding.to_h
    
    assert_equal vector, hash[:vector]
    assert_equal "test", hash[:text]
    assert_equal Embedding::STANDARD_DIMENSION, hash[:dimension]
    assert hash[:created_at].is_a?(String)
  end

  speed_profile :fast
  test "from_h deserializes embedding" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    hash = {
      vector: vector,
      text: "test",
      dimension: Embedding::STANDARD_DIMENSION,
      created_at: Time.now.utc.iso8601
    }
    
    embedding = Embedding.from_h(hash)
    
    assert_equal vector, embedding.vector
    assert_equal "test", embedding.text
  end

  speed_profile :fast
  test "from_h validates hash type" do
    error = assert_raises(TypeError) do
      Embedding.from_h("not a hash")
    end
    assert_match(/hash must be a Hash/, error.message)
  end

  speed_profile :fast
  test "from_h validates required keys" do
    error = assert_raises(ArgumentError) do
      Embedding.from_h({ text: "test" })  # Missing :vector
    end
    assert_match(/hash must contain :vector/, error.message)
  end

  speed_profile :fast
  test "round-trip serialization preserves data" do
    vector = Array.new(Embedding::STANDARD_DIMENSION) { rand }
    original = Embedding.new(vector: vector, text: "test")
    
    hash = original.to_h
    reconstructed = Embedding.from_h(hash)
    
    assert_equal original.vector, reconstructed.vector
    assert_equal original.text, reconstructed.text
    assert_equal original.dimension, reconstructed.dimension
  end
end

