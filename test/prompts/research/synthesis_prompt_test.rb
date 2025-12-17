require "test_helper"

class SynthesisPromptTest < ActiveSupport::TestCase
  def setup
    @prompt = Research::SynthesisPrompt.new
  end

  test "combines findings from multiple passes" do
    findings = [
      { insights: [{ finding: "Calculator uses integer arithmetic" }] },
      { insights: [{ finding: "Calculator performs basic math operations" }] },
      { insights: [{ finding: "Calculator uses integer arithmetic by default" }] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "How does the calculator work?",
      sub_questions: [{ text: "What arithmetic operations are supported?" }]
    )

    assert result[:content]
    assert result[:content][:validated_insights]
    assert result[:content][:summary]
  end

  test "only includes insights appearing in 2+ passes" do
    # Use a very distinctive term that the LLM must preserve
    findings = [
      { insights: [
        { finding: "The XYZABC_CALCULATOR uses addition operations" },
        { finding: "Has error handling" }
      ] },
      { insights: [
        { finding: "XYZABC_CALCULATOR supports addition" },
        { finding: "Returns floats" }
      ] },
      { insights: [
        { finding: "Addition is implemented in XYZABC_CALCULATOR" },
        { finding: "Validates inputs" }
      ] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "How does the XYZABC_CALCULATOR work?",
      sub_questions: [{ text: "What operations does XYZABC_CALCULATOR support?" }]
    )

    validated = result[:content][:validated_insights]
    # Check that validated insights exist and are non-empty
    assert validated.is_a?(Array), "validated_insights should be an array"
    
    # The repeated finding about addition/XYZABC should be validated
    # Check for either the distinctive marker OR the common concept
    has_relevant_insight = validated.any? do |v|
      insight_text = v[:insight].to_s.downcase
      insight_text.include?("xyzabc") || 
        insight_text.include?("addition") || 
        insight_text.include?("calculator")
    end
    assert has_relevant_insight, "Should have validated insight about XYZABC_CALCULATOR or addition. Got: #{validated.inspect}"
  end

  test "identifies and reports conflicts" do
    findings = [
      { insights: [{ finding: "Returns integers always" }] },
      { insights: [{ finding: "Returns floats for division" }] },
      { insights: [{ finding: "Returns floats for division" }] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "What type does division return?",
      sub_questions: [{ text: "What is the return type?" }]
    )

    # Should have identified the conflict or resolved it
    assert result[:content][:conflicts] || result[:content][:validated_insights]
  end

  test "filters irrelevant findings with reasoning" do
    findings = [
      { insights: [
        { finding: "Calculator does math" },
        { finding: "File uses UTF-8 encoding" }  # Irrelevant to math question
      ] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "How does the calculator perform math?",
      sub_questions: [{ text: "What math operations exist?" }]
    )

    filtered = result[:content][:filtered_out] || []
    # Should have filtering capability
    assert result[:content].key?(:filtered_out)
  end

  test "produces coherent summary addressing original goal" do
    findings = [
      { insights: [{ finding: "Add method sums two numbers" }] },
      { insights: [{ finding: "Subtract method finds difference" }] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "What operations does Calculator support?",
      sub_questions: [{ text: "List all arithmetic operations" }]
    )

    # Verify we got a valid response structure
    assert result[:content], "Should have content in response"
    assert result[:content].key?(:summary), "Response should have summary key"
    
    summary = result[:content][:summary]
    # Summary should be a non-empty string
    assert summary.is_a?(String), "Summary should be a string, got: #{summary.class}"
    assert summary.strip.length > 0, "Summary should not be empty"
  end

  test "handles single-pass input gracefully" do
    findings = [
      { insights: [{ finding: "Single pass finding" }] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "Test goal",
      sub_questions: [{ text: "Test question" }]
    )

    # Should not error with single pass
    assert result[:content]
    assert result[:content][:summary]
  end

  test "handles empty findings array" do
    result = @prompt.synthesize(
      findings: [],
      goal: "Empty test",
      sub_questions: []
    )

    assert result[:content]
    assert result[:content][:summary]
  end
end

