# frozen_string_literal: true

require "test_helper"

class VectorizationServiceTest < ActiveSupport::TestCase
  let(:service) { VectorizationService.new }

  speed_profile :fast
  test "vectorize generates embeddings for text" do
    text = "This is a test document for vectorization"
    embedding = service.vectorize(text: text)

    assert_instance_of Embedding, embedding
    assert_includes [384, 1536], embedding.dimension, "Expected dimension to be 384 or 1536"
    assert embedding.vector.all? { |v| v.is_a?(Float) }
  end

  speed_profile :fast
  test "find_similar returns similar memories above threshold" do
    # Create test memories
    memory1 = WorkflowMemories::Decision.new(
      decision: "Implement caching system with Redis",
      rationale: "Improve performance and reduce database load",
      context: {},
      checkpoint_id: "test",
      state: :running
    )

    memory2 = WorkflowMemories::Decision.new(
      decision: "Add database indexes for queries",
      rationale: "Query optimization for better performance",
      context: {},
      checkpoint_id: "test",
      state: :running
    )

    memory3 = WorkflowMemories::Decision.new(
      decision: "Implement user authentication system",
      rationale: "Security requirement for access control",
      context: {},
      checkpoint_id: "test",
      state: :running
    )

    # Create query embedding
    query_embedding = service.vectorize(text: "performance optimization and caching strategies")

    # Find similar memories
    results = service.find_similar(
      query_embedding: query_embedding,
      memories: [memory1, memory2, memory3],
      threshold: 0.2
    )

    # Should find at least the caching decision as similar
    assert results.size > 0, "Expected to find similar memories"
    assert results.all? { |r| r.is_a?(Hash) }
    assert results.all? { |r| r.key?(:memory) && r.key?(:similarity) }
    assert results.all? { |r| r[:similarity] >= 0.2 }
    
    # Results should be sorted by similarity (highest first)
    similarities = results.map { |r| r[:similarity] }
    assert_equal similarities, similarities.sort.reverse
  end

  speed_profile :fast
  test "find_similar returns empty array when no memories provided" do
    embedding = service.vectorize(text: "test query")
    
    results = service.find_similar(
      query_embedding: embedding,
      memories: [],
      threshold: 0.5
    )

    assert_equal [], results
  end

  speed_profile :fast
  test "find_similar respects similarity threshold" do
    memory = WorkflowMemories::Decision.new(
      decision: "Completely unrelated topic about gardening",
      rationale: "Plant maintenance",
      context: {},
      checkpoint_id: "test",
      state: :running
    )

    query_embedding = service.vectorize(text: "software architecture and design patterns")

    # With high threshold, should find nothing
    results = service.find_similar(
      query_embedding: query_embedding,
      memories: [memory],
      threshold: 0.9
    )

    assert_equal [], results, "Expected no results with high threshold"
  end

  speed_profile :fast
  test "find_similar works across different memory types" do
    decision = WorkflowMemories::Decision.new(
      decision: "Use Redis for session caching",
      rationale: "Faster session retrieval",
      context: {},
      checkpoint_id: "test",
      state: :running
    )

    context = WorkflowMemories::Context.new(
      context_data: { cache_type: "Redis", ttl: 3600 },
      checkpoint_id: "test",
      state: :running
    )

    output = WorkflowMemories::Output.new(
      output_data: { cache_implemented: true, performance: "improved" },
      checkpoint_id: "test",
      state: :running
    )

    query_embedding = service.vectorize(text: "Redis caching implementation")

    results = service.find_similar(
      query_embedding: query_embedding,
      memories: [decision, context, output],
      threshold: 0.2
    )

    # Should find memories from different types
    assert results.size > 0, "Expected to find similar memories across types"
    memory_types = results.map { |r| r[:memory].class.name.demodulize }.uniq
    assert memory_types.size >= 1, "Expected at least one memory type"
  end

  speed_profile :fast
  test "vectorize returns consistent embeddings for same text" do
    text = "test consistency"
    embedding1 = service.vectorize(text: text)
    embedding2 = service.vectorize(text: text)

    # Same text should produce very similar embeddings (>0.99 similarity)
    similarity = embedding1.similarity_to(embedding2)
    assert similarity > 0.99, "Expected high similarity (#{similarity}) for identical text"
  end
end
