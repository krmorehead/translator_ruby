# frozen_string_literal: true

require "test_helper"

class NarrativePromptTest < ActiveSupport::TestCase
  test "model comes from BasePrompt" do
    prompt = NarrativePrompt.new
    # Model should come from LLM_MODEL via BasePrompt, not a per-prompt override
    assert_equal ENV["LLM_MODEL"], prompt.model
  end

  test "system prompt sets DM voice" do
    prompt = NarrativePrompt.new
    text = prompt.system_prompt
    assert_includes text, "Dungeon Master"
    assert_includes text.downcase, "narrative"
  end

  test "response schema is nil" do
    prompt = NarrativePrompt.new
    assert_nil prompt.response_schema
  end

  test "format_context includes actions and history" do
    prompt = NarrativePrompt.new
    formatted = prompt.format_context(
      actions: [ { tool_name: "inspect_room", consequence: "You find a map." } ],
      recent_conversation: [ "Player asked about the map" ]
    )
    assert_includes formatted, "inspect_room"
    assert_includes formatted, "map"
  end

  test "execute returns narrative string" do
    prompt = NarrativePrompt.new
    result = prompt.execute(
      prompt: "Narrate the scene.",
      context: {
        actions: [ { tool_name: "inspect_room", consequence: "You spot a hidden door." } ],
        scene: "stone hallway"
      }
    )

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:thoughts)
    assert_kind_of String, result[:content]
    refute_includes result[:content].downcase, "tool"
    refute_includes result[:content].downcase, "dice"
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
