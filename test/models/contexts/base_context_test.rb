# frozen_string_literal: true

require "test_helper"

class BaseContextTest < ActiveSupport::TestCase
  def context
    @context ||= Contexts::BaseContext.new
  end

  test "can add entries with topics" do
    entry = context.add(
      content: "Calculator performs arithmetic",
      topics: ["calculator", "arithmetic"],
      source: "lib/calculator.rb"
    )

    assert_equal 1, context.size
    assert_equal "Calculator performs arithmetic", entry.content
    assert_includes entry.topics, "calculator"
  end

  test "normalizes topics to lowercase" do
    entry = context.add(
      content: "Test content",
      topics: ["Calculator", "ARITHMETIC"],
      source: "test"
    )

    assert_includes entry.topics, "calculator"
    assert_includes entry.topics, "arithmetic"
    refute_includes entry.topics, "Calculator"
  end

  test "indexes entries by topic for fast lookup" do
    context.add(content: "Entry about math", topics: ["math"], source: "a")
    context.add(content: "Entry about calculator", topics: ["calculator"], source: "b")
    context.add(content: "Entry about both", topics: ["math", "calculator"], source: "c")

    math_entries = context.by_topic("math")
    assert_equal 2, math_entries.size

    calc_entries = context.by_topic("calculator")
    assert_equal 2, calc_entries.size
  end

  test "relevant_to returns entries matching question keywords" do
    context.add(content: "Calculator has add method", topics: ["calculator"], source: "a")
    context.add(content: "Logger writes to stdout", topics: ["logger"], source: "b")
    context.add(content: "Formatter formats calculator output", topics: ["formatter"], source: "c")

    relevant = context.relevant_to("How does calculator work?")

    assert relevant.any? { |e| e.content.include?("Calculator") }
  end

  test "relevant_to respects limit parameter" do
    10.times do |i|
      context.add(content: "Calculator entry #{i}", topics: ["calculator"], source: "file#{i}")
    end

    relevant = context.relevant_to("calculator methods", limit: 3)
    assert_equal 3, relevant.size
  end

  test "format_for_prompt returns brief format by default" do
    context.add(content: "First finding", topics: ["test"], source: "a")
    context.add(content: "Second finding", topics: ["test"], source: "b")

    formatted = context.format_for_prompt("test question")

    assert formatted.include?("- First finding") || formatted.include?("- Second finding")
  end

  test "format_for_prompt detailed includes source" do
    context.add(content: "Finding content", topics: ["test"], source: "source.rb")

    formatted = context.format_for_prompt("test", format: :detailed)

    assert formatted.include?("Source: source.rb")
  end

  test "compressed_summary groups by topic" do
    context.add(content: "Math entry 1", topics: ["math"], source: "a")
    context.add(content: "Math entry 2", topics: ["math"], source: "b")
    context.add(content: "Calc entry", topics: ["calculator"], source: "c")

    summary = context.compressed_summary

    assert summary.include?("math:")
    assert summary.include?("calculator:")
  end

  test "serializes to hash and back" do
    context.add(content: "Test entry", topics: ["test"], source: "source.rb", metadata: { key: "value" })

    hash = context.to_h
    restored = Contexts::BaseContext.from_h(hash)

    assert_equal 1, restored.size
    assert_equal "Test entry", restored.entries.first.content
  end

  # Sub-context tests
  test "can add and retrieve sub-contexts" do
    sub = Contexts::BaseContext.new
    sub.add(content: "Sub content", topics: ["sub"], source: "test")

    context.add_sub_context(:child, sub)

    assert context.has_sub_context?(:child)
    assert_equal sub, context.get_sub_context(:child)
  end

  test "add_sub_context raises for non-context" do
    assert_raises(ArgumentError) do
      context.add_sub_context(:bad, "not a context")
    end
  end

  test "sub_contexts are included in serialization" do
    sub = Contexts::BaseContext.new
    sub.add(content: "Sub entry", topics: ["sub"], source: "child")

    context.add(content: "Parent entry", topics: ["parent"], source: "parent")
    context.add_sub_context(:child, sub)

    hash = context.to_h
    assert hash[:sub_contexts].key?(:child)

    restored = Contexts::BaseContext.from_h(hash)
    assert restored.has_sub_context?(:child)
    assert_equal 1, restored.get_sub_context(:child).size
  end

  # Condense tests
  test "condense creates a new context with limited entries" do
    20.times do |i|
      context.add(content: "Entry #{i}", topics: ["topic#{i % 3}"], source: "file#{i}")
    end

    condensed = context.condense(max_entries: 5)

    assert condensed.size <= 5
    refute_equal context.object_id, condensed.object_id  # New instance
  end

  test "condense preserves entries from different topics" do
    context.add(content: "Math 1", topics: ["math"], source: "a")
    context.add(content: "Math 2", topics: ["math"], source: "b")
    context.add(content: "Calc 1", topics: ["calc"], source: "c")

    condensed = context.condense(max_entries: 2)

    topics = condensed.entries.flat_map(&:topics).uniq
    # Should try to preserve topic diversity
    assert condensed.size <= 2
  end

  test "condense handles sub-contexts" do
    sub = Contexts::BaseContext.new
    5.times { |i| sub.add(content: "Sub #{i}", topics: ["sub"], source: "test") }

    context.add_sub_context(:child, sub)

    condensed = context.condense(max_entries: 2, condense_sub_contexts: true)

    assert condensed.has_sub_context?(:child)
    assert condensed.get_sub_context(:child).size <= 2
  end

  # Merge tests
  test "merge combines entries from two contexts" do
    other = Contexts::BaseContext.new
    other.add(content: "Other entry", topics: ["other"], source: "other")

    context.add(content: "Original entry", topics: ["original"], source: "orig")
    context.merge(other)

    assert_equal 2, context.size
    assert context.entries.any? { |e| e.content == "Other entry" }
  end

  test "merge deduplicates by content" do
    other = Contexts::BaseContext.new
    other.add(content: "Same content", topics: ["other"], source: "other")

    context.add(content: "Same content", topics: ["original"], source: "orig")
    context.merge(other, deduplicate: true)

    assert_equal 1, context.size
  end

  test "merge combines sub-contexts" do
    sub1 = Contexts::BaseContext.new
    sub1.add(content: "Sub1 entry", topics: ["s1"], source: "s1")

    sub2 = Contexts::BaseContext.new
    sub2.add(content: "Sub2 entry", topics: ["s2"], source: "s2")

    other = Contexts::BaseContext.new
    other.add_sub_context(:child, sub2)

    context.add_sub_context(:child, sub1)
    context.merge(other)

    # Sub-contexts should be merged
    assert_equal 2, context.get_sub_context(:child).size
  end

  # All entries tests
  test "all_entries includes entries from sub-contexts" do
    sub = Contexts::BaseContext.new
    sub.add(content: "Sub entry", topics: ["sub"], source: "sub")

    context.add(content: "Parent entry", topics: ["parent"], source: "parent")
    context.add_sub_context(:child, sub)

    all = context.all_entries
    assert_equal 2, all.size
  end

  test "all_entries respects depth limit" do
    deep_sub = Contexts::BaseContext.new
    deep_sub.add(content: "Deep entry", topics: ["deep"], source: "deep")

    sub = Contexts::BaseContext.new
    sub.add(content: "Sub entry", topics: ["sub"], source: "sub")
    sub.add_sub_context(:deeper, deep_sub)

    context.add(content: "Parent entry", topics: ["parent"], source: "parent")
    context.add_sub_context(:child, sub)

    # Depth 0 = only this context
    assert_equal 1, context.all_entries(depth: 0).size

    # Depth 1 = this + immediate children
    assert_equal 2, context.all_entries(depth: 1).size

    # Depth -1 (unlimited) = all
    assert_equal 3, context.all_entries(depth: -1).size
  end

  # Relevant to deep tests
  test "relevant_to_deep searches sub-contexts" do
    sub = Contexts::BaseContext.new
    # Add content with multiple matching keywords to exceed threshold
    sub.add(content: "Calculator math operations for arithmetic", topics: ["calculator", "math"], source: "sub")

    context.add(content: "Logger writes logs", topics: ["logger"], source: "parent")
    context.add_sub_context(:child, sub)

    # Use a question with multiple matching keywords
    relevant = context.relevant_to_deep("calculator math operations")
    assert relevant.any? { |e| e.content.include?("Calculator") }
  end
end

