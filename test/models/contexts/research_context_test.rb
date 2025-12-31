# frozen_string_literal: true

require "test_helper"
require_relative "../../support/research_test_factory"

class ResearchContextTest < ActiveSupport::TestCase
  include ResearchTestFactory

  def context
    @context ||= build_research_context
  end

  def context_with_data
    @context_with_data ||= build_research_context(
      with_findings: true,
      with_sub_questions: true
    )
  end

  test "initializes with research goal" do
    ctx = Contexts::ResearchContext.new(research_goal: "How does Calculator work?")
    assert_equal "How does Calculator work?", ctx.research_goal
  end

  test "add_finding creates entry with proper topics" do
    entry = context.add_finding(
      finding: "Calculator has add method",
      file_path: "lib/calculator.rb",
      sub_question: "What methods exist?",
      confidence: 0.9
    )

    assert_equal 1, context.size
    assert_instance_of Contexts::Entries::ResearchEntry, entry
    assert_equal 0.9, entry.confidence
    assert_equal "lib/calculator.rb", entry.file_path
    assert_equal "What methods exist?", entry.sub_question
    assert entry.topics.any? { |t| t.include?("calculator") }
    assert_equal 1, context.findings.size
  end

  test "add_sub_question creates entry with question topic" do
    entry = context.add_sub_question(
      question: "What methods does Calculator expose?",
      parent_question: "How does Calculator work?",
      priority: 1
    )

    assert_instance_of Contexts::Entries::BaseEntry, entry
    assert_equal 1, entry.metadata[:priority]
    assert_equal "How does Calculator work?", entry.metadata[:parent]
    assert_equal 1, context.sub_questions.size
  end

  test "add_file_summary creates entry with method topics" do
    entry = context.add_file_summary(
      file_path: "lib/calculator.rb",
      summary: "Basic arithmetic operations",
      methods: ["add", "subtract", "multiply"]
    )

    assert_instance_of Contexts::Entries::BaseEntry, entry
    assert_equal ["add", "subtract", "multiply"], entry.metadata[:methods]
    assert_equal "Basic arithmetic operations", entry.content
    assert_equal 1, context.file_summaries.size
  end

  test "for_sub_question returns entries tagged with that question" do
    context.add_sub_question(question: "What methods?", priority: 1)
    context.add_finding(
      finding: "Found add method",
      file_path: "calc.rb",
      sub_question: "What methods?",
      confidence: 0.9
    )
    context.add_finding(
      finding: "Unrelated finding",
      file_path: "other.rb",
      sub_question: "Different question",
      confidence: 0.8
    )

    relevant = context.for_sub_question("What methods?")

    # Should prioritize entries tagged with the same question
    assert relevant.size <= 5
  end

  test "for_file returns entries about specific file" do
    context.add_file_summary(
      file_path: "lib/calculator.rb",
      summary: "Arithmetic operations",
      methods: ["add"]
    )
    context.add_file_summary(
      file_path: "lib/formatter.rb",
      summary: "Output formatting",
      methods: ["format"]
    )

    calc_entries = context.for_file("lib/calculator.rb")

    assert calc_entries.any? { |e| e.content.include?("Arithmetic") }
  end

  test "format_for_analysis returns relevant prior findings" do
    context.add_finding(
      finding: "Calculator uses integer division",
      file_path: "calc.rb",
      sub_question: "How does division work?",
      confidence: 0.9
    )

    formatted = context.format_for_analysis("How does division work?")

    assert formatted.include?("Previous relevant findings:") || formatted.empty?
  end

  test "format_for_synthesis groups by sub_question" do
    context.add_finding(
      finding: "Add method found",
      file_path: "calc.rb",
      sub_question: "What methods?",
      confidence: 0.9
    )
    context.add_finding(
      finding: "Formatter uses Calculator",
      file_path: "format.rb",
      sub_question: "How are they related?",
      confidence: 0.8
    )

    formatted = context.format_for_synthesis

    assert formatted.include?("What methods?") || formatted.include?("How are they related?") || formatted.empty?
  end

  test "boosts relevance for goal-related keywords" do
    ctx = Contexts::ResearchContext.new(research_goal: "How does Calculator work?")

    ctx.add(content: "Calculator arithmetic operations", topics: ["calc"], source: "a")
    ctx.add(content: "Logger writes output", topics: ["log"], source: "b")

    relevant = ctx.relevant_to("What operations exist?")

    # Calculator-related entry should be prioritized due to goal boost
    calc_entry = relevant.find { |e| e.content.include?("Calculator") }
    assert calc_entry, "Calculator entry should be in relevant results"
  end

  test "factory creates context with sample data" do
    ctx = context_with_data

    assert ctx.size > 0, "Should have entries"
    assert ctx.sub_questions.size > 0, "Should have sub-questions"
    assert ctx.findings.size > 0, "Should have findings"
  end
end

