# frozen_string_literal: true

require "test_helper"
class BasePromptTest < ActiveSupport::TestCase
  def setup
    @tools = [{ type: "function", function: { name: "demo_tool", description: "demo", parameters: { type: "object", properties: {}, required: [] } } }]
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

  test "format_context renders pretty json" do
    prompt = OutcomePrompt.new
    formatted = prompt.format_context({ action: { tool_name: "demo_tool" }, scene: "a forest" })
    assert_includes formatted, "Scene:"
    assert_includes formatted, "forest"
  end

  test "execute returns structured json when schema provided" do
    skip "LLM credentials not configured" unless llm_configured?

    prompt = OutcomePrompt.new
    result = prompt.execute(
      prompt: "Provide a consequence.",
      context: {
        action: { tool_name: "demo_tool", arguments: { target: "door" }, prompt_reference: "open door" },
        result: { success: true, result: "The door opens." },
        scene: "stone hallway"
      }
    )

    assert_kind_of Hash, result
    assert result["consequence"].is_a?(String)
  end

  test "execute returns freeform text when no schema" do
    skip "LLM credentials not configured" unless llm_configured?

    prompt = NarrativePrompt.new
    result = prompt.execute(
      prompt: "Narrate briefly.",
      context: { actions: [{ tool_name: "demo_tool", consequence: "You opened the door." }], scene: "hallway" }
    )

    assert_kind_of String, result
    refute_includes result.downcase, "tool"
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

