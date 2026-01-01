# frozen_string_literal: true

require "test_helper"

class VectorMemoryIntegrationTest < ActiveSupport::TestCase
  let(:temp_dir) { create_temp_git_repo }

  let(:store) do
    path = File.join(temp_dir, "vector_store.json")
    WorkflowMemoryStore.new(
      owner_id: SecureRandom.uuid,
      workflow_id: SecureRandom.uuid,
      workflow_name: "vector_test",
      path: path
    )
  end

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end

  speed_profile :fast
  test "query_similar_memories finds semantically related decisions" do
    # Record several decisions
    store.record_decision(
      decision: "Implement comprehensive logging for debugging",
      rationale: "Better debugging and monitoring capabilities",
      context: { priority: "high" }
    )

    store.record_decision(
      decision: "Add error tracking and monitoring",
      rationale: "Improve observability and debugging",
      context: { priority: "high" }
    )

    store.record_decision(
      decision: "Refactor database schema",
      rationale: "Performance optimization",
      context: { priority: "medium" }
    )

    # Query for similar memories with a reasonable threshold
    results = store.query_similar_memories(
      query_text: "monitoring and debugging tools",
      threshold: 0.2
    )

    # Should find at least 2 related decisions (logging and error tracking)
    assert results.size >= 2, "Expected at least 2 results, got #{results.size}"
    assert results.all? { |r| r[:memory].is_a?(WorkflowMemories::Decision) }
    assert results.all? { |r| r[:similarity] >= 0.2 }
    
    # Results should be sorted by similarity (highest first)
    if results.size >= 2
      assert results[0][:similarity] >= results[1][:similarity]
    end
    
    # The most similar decision should contain monitoring/debugging terms
    top_decision = results.first[:memory].decision.downcase
    assert(top_decision.include?("monitoring") || top_decision.include?("debugging") || 
           top_decision.include?("logging") || top_decision.include?("tracking"),
           "Top result should be related to monitoring/debugging: #{top_decision}")
  end

  speed_profile :fast
  test "query_similar_memories works across different memory types" do
    store.record_decision(
      decision: "Use Redis for caching",
      rationale: "Faster response times",
      context: {}
    )

    store.record_context(
      context_data: { cache_strategy: "Redis", ttl: 3600 }
    )

    store.record_output(
      output_data: { cache_implementation: "complete", performance_gain: "40%" }
    )

    # Query should find related memories across types
    results = store.query_similar_memories(
      query_text: "Redis caching implementation",
      threshold: 0.4
    )

    # Should find memories from multiple types
    memory_types = results.map { |r| r[:memory].class.name.demodulize }.uniq
    assert memory_types.size > 1, "Expected multiple memory types, got: #{memory_types}"
  end

  speed_profile :fast
  test "all_memories returns combined memories from all sections" do
    store.record_decision(decision: "test1", rationale: "test", context: {})
    store.record_state_transition(from: :pending, to: :running, event: :start)
    store.record_context(context_data: { key: "value" })
    store.record_error(StandardError.new("test error"))
    store.record_output(output_data: { result: "success" })

    memories = store.all_memories
    
    assert_equal 5, memories.size
    assert memories.all? { |m| m.is_a?(WorkflowMemories::BaseMemory) }
    
    # Check all types are present
    types = memories.map { |m| m.class.name.demodulize }
    assert_includes types, "Decision"
    assert_includes types, "StateTransition"
    assert_includes types, "Context"
    assert_includes types, "Error"
    assert_includes types, "Output"
  end

  speed_profile :fast
  test "query_similar_memories respects threshold parameter" do
    store.record_decision(
      decision: "Implement authentication",
      rationale: "Security requirement",
      context: {}
    )

    store.record_decision(
      decision: "Add logging",
      rationale: "Debugging support",
      context: {}
    )

    # With high threshold, should find fewer results
    high_threshold_results = store.query_similar_memories(
      query_text: "authentication system",
      threshold: 0.8
    )

    # With low threshold, should find more results
    low_threshold_results = store.query_similar_memories(
      query_text: "authentication system",
      threshold: 0.3
    )

    assert low_threshold_results.size >= high_threshold_results.size
  end

  speed_profile :fast
  test "query_similar_memories validates query_text" do
    error = assert_raises(ArgumentError) do
      store.query_similar_memories(query_text: "")
    end
    assert_match(/query_text cannot be empty/, error.message)
  end
end

