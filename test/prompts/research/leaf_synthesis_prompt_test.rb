# frozen_string_literal: true

require "test_helper"

class LeafSynthesisPromptTest < ActiveSupport::TestCase
  # Shared synthesis result
  class << self
    attr_accessor :shared_result, :computed
  end

  def prompt
    @prompt ||= Research::LeafSynthesisPrompt.new
  end

  def shared_synthesis
    self.class.shared_result ||= prompt.synthesize_leaf(
      sub_question: "How does the Calculator.add method work?",
      findings: [
        { text: "Calculator.add sums two numbers", pass_number: 1, file_path: "calculator.rb" },
        { text: "Add method validates numeric inputs", pass_number: 1, file_path: "calculator.rb" },
        { text: "Addition uses integer arithmetic", pass_number: 2, file_path: "calculator.rb" },
        { text: "Calculator.add handles negative numbers", pass_number: 2, file_path: "calculator.rb" },
        { text: "Add returns an integer result", pass_number: 3, file_path: "calculator.rb" }
      ]
    )
  end

  # ============================================================================
  # Shared Result Tests - Use one LLM call
  # ============================================================================

  test "shared: returns content" do
    result = shared_synthesis
    assert result[:content], "Should return content"
  end

  test "shared: has summary" do
    result = shared_synthesis
    assert result[:content][:summary], "Should have a summary"
  end

  test "shared: has key_findings array" do
    result = shared_synthesis
    assert result[:content][:key_findings].is_a?(Array), "Should have key_findings array"
  end

  test "shared: has numeric confidence" do
    result = shared_synthesis
    assert result[:content][:confidence].is_a?(Numeric), "Should have numeric confidence"
  end

  test "shared: has gaps array" do
    result = shared_synthesis
    assert result[:content][:gaps].is_a?(Array), "Should have gaps array"
  end

  test "shared: key_findings is non-empty" do
    result = shared_synthesis
    assert result[:content][:key_findings].any?, "Should have key findings"
  end

  # ============================================================================
  # Edge Case Test - Minimal LLM call
  # ============================================================================

  test "handles empty findings gracefully" do
    result = prompt.synthesize_leaf(
      sub_question: "What does empty code do?",
      findings: []
    )

    assert result[:content], "Should return content even with empty findings"
  end
end
