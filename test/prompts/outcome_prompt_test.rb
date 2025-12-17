# frozen_string_literal: true

require "test_helper"

class OutcomePromptTest < ActiveSupport::TestCase
  test "model comes from BasePrompt" do
    prompt = OutcomePrompt.new
    # Model should come from LLM_MODEL via BasePrompt, not a per-prompt override
    assert_equal ENV["LLM_MODEL"], prompt.model
  end

  test "response schema expects consequence" do
    prompt = OutcomePrompt.new
    schema = prompt.response_schema
    assert_equal "string", schema[:properties][:consequence][:type]
    assert_includes schema[:required], "consequence"
  end

  test "format_context includes action and result" do
    prompt = OutcomePrompt.new
    formatted = prompt.format_context(
      action: { tool_name: "inspect_room", arguments: { target: "table" } },
      result: { success: true, result: "A dusty map" },
      scene: "an ancient library"
    )
    assert_includes formatted, "inspect_room"
    assert_includes formatted, "ancient library"
  end

  test "execute returns consequence hash" do
    prompt = OutcomePrompt.new
    result = prompt.execute(
      prompt: "Summarize the consequence.",
      context: {
        action: { tool_name: "inspect_room", arguments: { target: "door" }, prompt_reference: "inspect door" },
        result: { success: true, result: "The door opens with a creak." },
        scene: "a dark corridor"
      }
    )

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:thoughts)
    assert_kind_of Hash, result[:content]
    assert result[:content][:consequence].is_a?(String)
  end

  private

  def llm_configured?
    ENV["API_KEY"].to_s.strip.present? && ENV["LLM_URL"].to_s.strip.present?
  end

  def with_env(key, value)
    original = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = original
  end
end
