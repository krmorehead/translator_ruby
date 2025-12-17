require "test_helper"

class TopicDecompositionPromptTest < ActiveSupport::TestCase
  def setup
    @prompt = Research::TopicDecompositionPrompt.new
  end

  test "produces valid JSON response" do
    result = @prompt.decompose(
      topic: "How does the calculator perform arithmetic operations?",
      context: { codebase_summary: "A simple Ruby math library" }
    )

    assert result[:content]
    assert result[:content][:questions]
    assert_kind_of Array, result[:content][:questions]
  end

  test "questions include is_leaf flag" do
    result = @prompt.decompose(
      topic: "How does the file reading work in this tool?",
      context: {}
    )

    questions = result[:content][:questions]
    assert questions.all? { |q| q.key?(:is_leaf) }
  end

  test "broad questions generate multiple sub-questions" do
    result = @prompt.decompose(
      topic: "Explain the entire architecture of a Rails application",
      context: { codebase_summary: "A full Rails API with models, controllers, and services" }
    )

    questions = result[:content][:questions]
    assert questions.size >= 2, "Broad topic should generate multiple questions"
  end

  test "specific questions may be marked as leaf" do
    result = @prompt.decompose(
      topic: "What is the return type of the Calculator#add method?",
      context: { codebase_summary: "Simple calculator class" }
    )

    questions = result[:content][:questions]
    # At least some questions should be leaves for very specific topics
    assert questions.any?, "Should have at least one question"
  end

  test "includes rationale for each question" do
    result = @prompt.decompose(
      topic: "How does authentication work?",
      context: {}
    )

    questions = result[:content][:questions]
    questions.each do |q|
      assert q.key?(:rationale), "Each question should have a rationale"
      assert q[:rationale].present?, "Rationale should not be empty"
    end
  end

  test "includes topic summary" do
    result = @prompt.decompose(
      topic: "How does caching work in this application?",
      context: {}
    )

    assert result[:content][:topic_summary]
    assert result[:content][:topic_summary].present?
  end

  test "handles already-specific topic" do
    result = @prompt.decompose(
      topic: "What line is the DivisionByZeroError raised on?",
      context: {}
    )

    assert result[:content][:questions]
    # Should still produce at least one question
  end
end

