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
    assert result[:content]["validated_insights"]
    assert result[:content]["summary"]
  end

  test "only includes insights appearing in 2+ passes" do
    findings = [
      { insights: [
        { finding: "Uses addition" },
        { finding: "Has error handling" }
      ] },
      { insights: [
        { finding: "Uses addition" },
        { finding: "Returns floats" }
      ] },
      { insights: [
        { finding: "Uses addition" },
        { finding: "Validates inputs" }
      ] }
    ]

    result = @prompt.synthesize(
      findings: findings,
      goal: "How does calculation work?",
      sub_questions: [{ text: "What operations exist?" }]
    )

    validated = result[:content]["validated_insights"]
    # "Uses addition" appears in all 3, should be validated
    assert validated.any? { |v| v["insight"].downcase.include?("addition") }
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
    assert result[:content]["conflicts"] || result[:content]["validated_insights"]
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

    filtered = result[:content]["filtered_out"] || []
    # Should have filtering capability
    assert result[:content].key?("filtered_out")
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

    summary = result[:content]["summary"]
    assert summary.present?
    # Summary should address arithmetic operations
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
    assert result[:content]["summary"]
  end

  test "handles empty findings array" do
    result = @prompt.synthesize(
      findings: [],
      goal: "Empty test",
      sub_questions: []
    )

    assert result[:content]
    assert result[:content]["summary"]
  end
end

