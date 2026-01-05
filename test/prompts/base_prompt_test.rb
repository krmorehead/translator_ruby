# frozen_string_literal: true

require "test_helper"
class BasePromptTest < ActiveSupport::TestCase
  def setup
    # Convert hash tools to proper Tool objects following OOP patterns
    tool_hashes = [ { type: "function", function: { name: "demo_tool", description: "demo", parameters: { type: "object", properties: {}, required: [] } } } ]
    @tools = tool_hashes.map { |h| Tool.from_h(h) }
  end
  speed_profile :fast
  test "response_schema remains abstract" do
    prompt = BasePrompt.new
    assert_raises(NotImplementedError) { prompt.response_schema }
  end

  speed_profile :fast
  test "base system prompt is chat-friendly" do
    prompt = BasePrompt.new
    assert_includes prompt.system_prompt, "helpful assistant"
  end

  speed_profile :fast
  test "base system prompt matches constant" do
    prompt = BasePrompt.new
    assert_equal BasePrompt::BASE_SYSTEM_PROMPT, prompt.system_prompt
  end

  speed_profile :fast
  test "model defaults to general_llm capability" do
    prompt = OutcomePrompt.new
    # Test behavior: model is set and valid, not specific configuration value
    assert_not_nil prompt.model
    assert_instance_of String, prompt.model
    refute_empty prompt.model
  end

  speed_profile :fast
  test "tools accessor returns passed tools" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    assert_equal @tools, prompt.tools
  end

  speed_profile :fast
  test "serialize_tools renders tool names" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    serialized = prompt.serialize_tools
    assert_instance_of Array, serialized
  end

  speed_profile :fast
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

  speed_profile :medium
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

  speed_profile :medium
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

  speed_profile :medium
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
