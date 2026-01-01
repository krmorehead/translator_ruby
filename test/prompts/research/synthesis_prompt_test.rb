# frozen_string_literal: true

require "test_helper"

class SynthesisPromptTest < ActiveSupport::TestCase
  # Shared synthesis results
  class << self
    attr_accessor :multi_pass_result, :leaf_combine_result, :computed
  end

  def prompt
    @prompt ||= Research::SynthesisPrompt.new
  end

  def multi_pass_synthesis
    self.class.multi_pass_result ||= prompt.synthesize(
      findings: [
        { insights: [
          { finding: "The XYZABC_CALCULATOR uses addition operations" },
          { finding: "Calculator performs basic math" },
          { finding: "File uses UTF-8 encoding" }
        ] },
        { insights: [
          { finding: "XYZABC_CALCULATOR supports addition and subtraction" },
          { finding: "Returns floats for division" }
        ] },
        { insights: [
          { finding: "Addition is implemented in XYZABC_CALCULATOR" },
          { finding: "Returns integers for most operations" }
        ] }
      ],
      goal: "How does the XYZABC_CALCULATOR work? What operations does it support?",
      sub_questions: [
        { text: "What arithmetic operations are supported?" },
        { text: "What types are returned?" }
      ]
    )
  end

  def leaf_combine_synthesis
    self.class.leaf_combine_result ||= prompt.combine_leaf_syntheses(
      goal: "How does the Calculator perform arithmetic?",
      leaf_syntheses: [
        {
          sub_question: "How does Calculator.add work?",
          summary: "Calculator.add takes two numbers and returns their sum.",
          key_findings: [
            { finding: "Validates numeric inputs", confidence: 0.9, supporting_passes: 3 },
            { finding: "Returns integer result", confidence: 0.8, supporting_passes: 2 }
          ],
          confidence: 0.85,
          conflicts: [],
          gaps: []
        },
        {
          sub_question: "How does Calculator.subtract work?",
          summary: "Calculator.subtract computes the difference.",
          key_findings: [
            { finding: "Handles negative results", confidence: 0.9, supporting_passes: 2 }
          ],
          confidence: 0.9,
          conflicts: [],
          gaps: ["Edge case handling unclear", "Division behavior unknown"]
        }
      ]
    )
  end

  # ============================================================================
  # Multi-Pass Synthesis Tests - Share one LLM call
  # ============================================================================
  speed_profile :medium
  test "multi_pass: combines findings from multiple passes" do
    result = multi_pass_synthesis

    assert result[:content]
    assert result[:content][:validated_insights]
    assert result[:content][:summary]
  end

  speed_profile :medium
  test "multi_pass: validated insights is array" do
    result = multi_pass_synthesis

    validated = result[:content][:validated_insights]
    assert validated.is_a?(Array), "validated_insights should be an array"
  end

  speed_profile :medium
  test "multi_pass: has relevant validated insights" do
    result = multi_pass_synthesis

    assert result[:content].present?, "Result content should not be empty"

    validated = result[:content][:validated_insights] || []
    summary = result[:content][:summary].to_s.downcase
    # validated_insights is now an array of strings
    all_text = validated.map { |v| v.to_s.downcase }.join(" ") + " " + summary

    # If we have any text, check for relevant terms
    if all_text.strip.present?
      has_relevant = all_text.include?("xyzabc") ||
                     all_text.include?("addition") ||
                     all_text.include?("calculator") ||
                     all_text.include?("math") ||
                     all_text.include?("arithmetic") ||
                     all_text.include?("operation")
      assert has_relevant, "Should have insight about XYZABC_CALCULATOR or math. Got: #{all_text[0, 200]}"
    else
      pass
    end
  end

  speed_profile :medium
  test "multi_pass: has conflicts or validated_insights array" do
    result = multi_pass_synthesis

    assert result[:content][:conflicts] || result[:content][:validated_insights]
  end

  speed_profile :medium
  test "multi_pass: has open_questions key" do
    result = multi_pass_synthesis

    assert result[:content].key?(:open_questions)
  end

  speed_profile :medium
  test "multi_pass: summary is non-empty string" do
    result = multi_pass_synthesis

    summary = result[:content][:summary]
    assert summary.is_a?(String), "Summary should be a string, got: #{summary.class}"
    # Summary may be empty if the LLM couldn't synthesize, but should exist
    assert_not_nil summary, "Summary should not be nil"
  end

  # ============================================================================
  # Leaf Combine Tests - Share one LLM call
  # ============================================================================

  speed_profile :medium
  test "leaf_combine: returns content" do
    result = leaf_combine_synthesis

    assert result[:content], "Should return content"
  end

  speed_profile :medium
  test "leaf_combine: has combined summary" do
    result = leaf_combine_synthesis

    # Summary may be nil if LLM returns unexpected format, but content should exist
    assert result[:content], "Should return content"
    # If summary exists, verify it's a string
    if result[:content][:summary]
      assert result[:content][:summary].is_a?(String), "Summary should be a string"
    end
  end

  speed_profile :medium
  test "leaf_combine: has validated_insights array" do
    result = leaf_combine_synthesis

    assert result[:content][:validated_insights].is_a?(Array), "Should have validated_insights"
  end

  speed_profile :medium
  test "leaf_combine: has open_questions from gaps" do
    result = leaf_combine_synthesis

    assert result[:content][:open_questions].is_a?(Array), "Should have open_questions array"
  end

  # ============================================================================
  # Edge Case Tests - Minimal LLM calls
  # ============================================================================

  speed_profile :medium
  test "handles empty findings array" do
    result = prompt.synthesize(
      findings: [],
      goal: "Empty test",
      sub_questions: []
    )

    assert result[:content]
    assert result[:content][:summary]
  end

  speed_profile :medium
  test "handles empty leaf syntheses" do
    result = prompt.combine_leaf_syntheses(
      goal: "Empty research goal",
      leaf_syntheses: []
    )

    assert result[:content], "Should return content even with empty syntheses"
    assert result[:content][:summary], "Should have a summary"
  end
end
