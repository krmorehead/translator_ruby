# frozen_string_literal: true

require "test_helper"

class OutcomePromptTest < ActiveSupport::TestCase
  test "model comes from general_llm capability via BasePrompt" do
    prompt = OutcomePrompt.new
    # Model should come from general_llm capability via BasePrompt, not a per-prompt override
    assert_equal "./vllm/models/qwen3_30b_a3b_moe", prompt.model
  end

  test "response schema expects consequence" do
    prompt = OutcomePrompt.new
    schema = prompt.response_schema
    assert_equal "string", schema[:properties][:consequence][:type]
    assert_includes schema[:required], "consequence"
  end

  test "format_context includes action and result" do
    prompt = OutcomePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Library", description: "an ancient library")
    context.add_action(
      action_name: "inspect_room",
      result: "A dusty map",
      metadata: { tool_result: { success: true, result: "A dusty map" } }
    )

    formatted = prompt.format_context(context)

    # :outcome format focuses on action and result (tight context)
    assert_includes formatted, "inspect_room"
    assert_includes formatted, "dusty map"
    # Scene is included as compressed summary
    assert_includes formatted, "Library"
  end

  test "execute returns consequence hash" do
    prompt = OutcomePrompt.new
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Corridor", description: "a dark corridor")
    context.add_action(
      action_name: "inspect door",
      result: "The door opens with a creak.",
      metadata: { tool_result: { success: true, result: "The door opens with a creak." } }
    )

    result = prompt.execute(
      prompt: "Summarize the consequence.",
      context: context
    )

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:thoughts)
    assert_kind_of Hash, result[:content]
    assert result[:content][:consequence].is_a?(String)
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
