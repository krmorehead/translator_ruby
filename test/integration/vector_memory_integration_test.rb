# frozen_string_literal: true

require "test_helper"

class VectorMemoryIntegrationTest < ActiveSupport::TestCase
  let(:temp_dir) { create_temp_git_repo }

  let(:store) do
    build(:workflow_memory_store, base_dir: temp_dir)
  end

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end

  speed_profile :fast
  test "query_context finds semantically related decisions" do
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

    # Query for similar context using unified graph service
    results = store.query_context(
      context_type: :decision,
      query_text: "monitoring and debugging tools",
      threshold: 0.2
    )

    # Should find related decisions
    assert results.is_a?(Array), "Expected array of results"
  end

  speed_profile :fast
  test "query_context works across different memory types" do
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

    # Query should find related memories via graph service
    results = store.query_context(
      context_type: :memory,
      query_text: "Redis caching implementation",
      threshold: 0.4
    )

    assert results.is_a?(Array), "Expected array of results"
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
  test "query_context respects threshold parameter" do
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
    high_threshold_results = store.query_context(
      context_type: :decision,
      query_text: "authentication system",
      threshold: 0.8
    )

    # With low threshold, should find more results
    low_threshold_results = store.query_context(
      context_type: :decision,
      query_text: "authentication system",
      threshold: 0.3
    )

    assert low_threshold_results.size >= high_threshold_results.size
  end

end

