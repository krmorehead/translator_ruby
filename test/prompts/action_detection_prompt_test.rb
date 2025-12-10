# frozen_string_literal: true

require "test_helper"

class ActionDetectionPromptTest < ActiveSupport::TestCase
  def setup
    @tools = [
      {
        type: "function",
        function: {
          name: "inspect_room",
          description: "Inspect the room for details",
          parameters: {
            type: "object",
            properties: {
              target: { type: "string", description: "object to inspect" }
            },
            required: [ "target" ],
            additionalProperties: false
          }
        }
      },
      {
        type: "function",
        function: {
          name: "pickup_item",
          description: "Pick up an item",
          parameters: {
            type: "object",
            properties: {
              item: { type: "string" }
            },
            required: [ "item" ],
            additionalProperties: false
          }
        }
      }
    ]
  end

  test "requires tools" do
    assert_raises(ArgumentError) { ActionDetectionPrompt.new(tools: nil) }
    assert_raises(ArgumentError) { ActionDetectionPrompt.new(tools: []) }
  end

  test "system prompt mentions tools" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    text = prompt.system_prompt
    assert_includes text, "inspect_room"
    assert_includes text, "pickup_item"
  end

  test "response schema limits tool names" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    enum = prompt.response_schema.dig(:items, :properties, :tool_name, :enum)
    assert_equal [ "inspect_room", "pickup_item" ], enum
  end

  test "format_context includes scene and tools" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    formatted = prompt.format_context({ scene: "a dim tavern", memory: { quest: "find key" } })
    assert_includes formatted, "dim tavern"
    assert_includes formatted, "inspect_room"
  end

  test "execute returns array of actions" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    result = prompt.execute(
      prompt: "I look around the room and pick up the sword.",
      context: { scene: "a candle-lit armory" }
    )

    assert_kind_of Array, result
    unless result.empty?
      first = result.first
      assert first.key?("tool_name")
      assert_includes [ "inspect_room", "pickup_item" ], first["tool_name"]
      assert first.key?("arguments")
      assert first.key?("prompt_reference")
    end
  end

  private

  def llm_configured?
    ENV["API_KEY"].to_s.strip.present? && ENV["LLM_URL"].to_s.strip.present?
  end
end
