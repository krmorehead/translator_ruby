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
end

