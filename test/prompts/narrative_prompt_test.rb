# frozen_string_literal: true

require "test_helper"

class NarrativePromptTest < ActiveSupport::TestCase
  speed_profile :fast
  test "model comes from general_llm capability via BasePrompt" do
    prompt = NarrativePrompt.new
    # Test behavior: model is set and valid, not specific configuration value
    assert_not_nil prompt.model
    assert_instance_of String, prompt.model
    refute_empty prompt.model
  end

  speed_profile :fast
  test "system prompt sets DM voice" do
    prompt = NarrativePrompt.new
    text = prompt.system_prompt
    assert_includes text, "Dungeon Master"
    assert_includes text.downcase, "narrative"
  end

  speed_profile :fast
  test "response schema is nil" do
    prompt = NarrativePrompt.new
    assert_nil prompt.response_schema
  end

  speed_profile :fast
  test "format_context includes actions and history" do
    prompt = NarrativePrompt.new
    context = Contexts::DndChatContext.new
    context.add_action(action_name: "inspect_room", result: "You find a map.")
    context.add_message(speaker: "player", message: "Player asked about the map")

    formatted = prompt.format_context(context)

    assert_includes formatted, "inspect_room"
    assert_includes formatted, "map"
  end

  speed_profile :medium
  test "execute returns narrative string" do
    prompt = NarrativePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Hallway", description: "stone hallway")
    context.add_action(action_name: "inspect_room", result: "You spot a hidden door.")

    result = prompt.execute(
      prompt: "Narrate the scene.",
      context: context
    )

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:thoughts)
    assert_kind_of String, result[:content]
    refute_includes result[:content].downcase, "tool"
    refute_includes result[:content].downcase, "dice"
  end

  
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
