# frozen_string_literal: true

require "test_helper"

class TopicDecompositionPromptTest < ActiveSupport::TestCase
  # Shared decomposition results - runs once for each topic type
  class << self
    attr_accessor :broad_result, :specific_result, :computed
  end

  def prompt
    @prompt ||= Research::TopicDecompositionPrompt.new
  end

  def broad_decomposition
    self.class.broad_result ||= prompt.decompose(
      topic: "How does the calculator perform arithmetic operations? Explain the architecture.",
      context: { codebase_summary: "A simple Ruby math library with Calculator, Formatter, and MathService" }
    )
  end

  def specific_decomposition
    self.class.specific_result ||= prompt.decompose(
      topic: "What is the return type of the Calculator#add method?",
      context: { codebase_summary: "Simple calculator class" }
    )
  end

  # ============================================================================
  # Broad Topic Tests - Share one LLM call
  # ============================================================================
  speed_profile :medium
  test "broad: produces valid JSON response" do
    result = broad_decomposition

    assert result[:content]
    assert result[:content][:questions]
    assert_kind_of Array, result[:content][:questions]
  end

  speed_profile :medium
  test "broad: questions include is_leaf flag" do
    result = broad_decomposition

    questions = result[:content][:questions]
    assert questions.all? { |q| q.key?(:is_leaf) }
  end

  speed_profile :medium
  test "broad: generates multiple sub-questions" do
    result = broad_decomposition

    questions = result[:content][:questions]
    assert questions.size >= 2, "Broad topic should generate multiple questions"
  end

  speed_profile :medium
  test "broad: includes rationale for each question" do
    result = broad_decomposition

    questions = result[:content][:questions]
    questions.each do |q|
      assert q.key?(:rationale), "Each question should have a rationale"
      assert q[:rationale].present?, "Rationale should not be empty"
    end
  end

  speed_profile :medium
  test "broad: includes topic summary" do
    result = broad_decomposition

    assert result[:content][:topic_summary]
    assert result[:content][:topic_summary].present?
  end

  # ============================================================================
  # Specific Topic Tests - Share one LLM call
  # ============================================================================

  speed_profile :medium
  test "specific: produces questions for specific topic" do
    result = specific_decomposition

    assert result[:content][:questions]
    assert result[:content][:questions].any?, "Should have at least one question"
  end

  speed_profile :medium
  test "specific: may mark questions as leaf" do
    result = specific_decomposition

    questions = result[:content][:questions]
    # For very specific topics, some questions might be leaves
    assert questions.any?, "Should have at least one question"
  end
end
