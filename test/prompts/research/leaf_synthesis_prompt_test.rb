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
        WorkflowMemories::Finding.new(
          id: SecureRandom.uuid,
          text: "Calculator.add sums two numbers",
          pass_number: 1,
          file_path: "calculator.rb",
          relevance: "direct",
          confidence: 0.9
        ),
        WorkflowMemories::Finding.new(
          id: SecureRandom.uuid,
          text: "Add method validates numeric inputs",
          pass_number: 1,
          file_path: "calculator.rb",
          relevance: "direct",
          confidence: 0.85
        ),
        WorkflowMemories::Finding.new(
          id: SecureRandom.uuid,
          text: "Addition uses integer arithmetic",
          pass_number: 2,
          file_path: "calculator.rb",
          relevance: "direct",
          confidence: 0.8
        ),
        WorkflowMemories::Finding.new(
          id: SecureRandom.uuid,
          text: "Calculator.add handles negative numbers",
          pass_number: 2,
          file_path: "calculator.rb",
          relevance: "supporting",
          confidence: 0.75
        ),
        WorkflowMemories::Finding.new(
          id: SecureRandom.uuid,
          text: "Add returns an integer result",
          pass_number: 3,
          file_path: "calculator.rb",
          relevance: "supporting",
          confidence: 0.7
        )
      ]
    )
  end

  # ============================================================================
  # Shared Result Tests - Use one LLM call
  # OOP: All these tests share a single LLM call result, but the first test to run
  #      will make the actual call, which can take >60s. Mark all as :slow to allow 120s SLA.
  # ============================================================================
  speed_profile :slow
  test "shared: returns content" do
    result = shared_synthesis
    assert result[:content], "Should return content"
  end

  speed_profile :slow
  test "shared: has summary" do
    result = shared_synthesis
    assert result[:content][:summary], "Should have a summary"
  end

  speed_profile :slow
  test "shared: has key_findings array" do
    result = shared_synthesis
    assert result[:content][:key_findings].is_a?(Array), "Should have key_findings array"
  end

  speed_profile :slow
  test "shared: has numeric confidence" do
    result = shared_synthesis
    assert result[:content][:confidence].is_a?(Numeric), "Should have numeric confidence"
  end

  speed_profile :slow
  test "shared: has gaps array" do
    result = shared_synthesis
    assert result[:content][:gaps].is_a?(Array), "Should have gaps array"
  end

  speed_profile :slow
  test "shared: key_findings is non-empty" do
    result = shared_synthesis
    assert result[:content][:key_findings].any?, "Should have key findings"
  end

  # ============================================================================
  # Edge Case Test - Minimal LLM call
  # ============================================================================

  # OOP: LLM calls require medium profile (>10s)
  # OOP: LLM calls can take longer than medium SLA (60s), so marked as slow (120s)
  speed_profile :slow
  test "handles empty findings gracefully" do
    result = prompt.synthesize_leaf(
      sub_question: "What does empty code do?",
      findings: []
    )

    assert result[:content], "Should return content even with empty findings"
  end
end
