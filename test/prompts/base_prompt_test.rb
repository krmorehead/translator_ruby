# frozen_string_literal: true

require "test_helper"
class BasePromptTest < ActiveSupport::TestCase
  def setup
    @tools = [ { type: "function", function: { name: "demo_tool", description: "demo", parameters: { type: "object", properties: {}, required: [] } } } ]
  end

  test "response_schema remains abstract" do
    prompt = BasePrompt.new
    assert_raises(NotImplementedError) { prompt.response_schema }
  end

  test "base system prompt is chat-friendly" do
    prompt = BasePrompt.new
    assert_includes prompt.system_prompt, "helpful assistant"
  end

  test "base system prompt matches constant" do
    prompt = BasePrompt.new
    assert_equal BasePrompt::BASE_SYSTEM_PROMPT, prompt.system_prompt
  end

  test "model defaults to env value" do
    with_env("LLM_MODEL", "demo-model") do
      prompt = OutcomePrompt.new
      assert_equal "demo-model", prompt.model
    end
  end

  test "tools accessor returns passed tools" do
    prompt = OutcomePrompt.new(tools: @tools)
    assert_equal @tools, prompt.tools
  end

  test "serialize_tools renders tool names" do
    prompt = OutcomePrompt.new(tools: @tools)
    serialized = prompt.serialize_tools(@tools)
    assert_includes serialized, "demo_tool"
  end

  test "format_context renders context output" do
    prompt = OutcomePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Forest", description: "a forest")
    context.add_action(action_name: "demo_tool", result: "Opened door")

    formatted = prompt.format_context(context)

    # :outcome format gives tight scene summary
    assert_includes formatted, "Scene:"
    assert_includes formatted, "Forest"  # Compressed summary uses location name
  end

  test "execute returns structured json when schema provided" do
    prompt = OutcomePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Hallway", description: "stone hallway")
    context.add_action(
      action_name: "open door",
      result: "The door opens.",
      metadata: { tool_result: { success: true, result: "The door opens." } }
    )

    result = prompt.execute(prompt: "Provide a consequence.", context: context)

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:thoughts)
    assert_kind_of Hash, result[:content]
    assert result[:content][:consequence].is_a?(String)
  end

  test "execute returns freeform text when no schema" do
    prompt = NarrativePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Hallway", description: "hallway")
    context.add_action(action_name: "demo_tool", result: "You opened the door.")

    result = prompt.execute(prompt: "Narrate briefly.", context: context)

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:thoughts)
    assert_kind_of String, result[:content]
    refute_includes result[:content].downcase, "tool"
  end

  test "execute includes thoughts field" do
    prompt = OutcomePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Test", description: "test")
    context.add_action(action_name: "test", result: "success")

    result = prompt.execute(prompt: "Provide a consequence.", context: context)

    assert result.key?(:thoughts)
    # Thoughts may be nil or string depending on LLM response
    assert [NilClass, String].include?(result[:thoughts].class)
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
