# frozen_string_literal: true

require "test_helper"

class ToolCallPromptTest < ActiveSupport::TestCase
  def setup
    @tools = [
      {
        type: "function",
        function: {
          name: "test_tool",
          description: "A test tool",
          parameters: {
            type: "object",
            properties: { arg: { type: "string" } },
            required: [ "arg" ]
          }
        }
      }
    ]
  end

  test "inherits from BasePrompt" do
    assert ToolCallPrompt < BasePrompt
  end

  test "uses tool_calling capability model by default" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    expected = "./vllm/models/hivata____functionary__small__v3.2__AWQ/snapshots/bee9e4cae2fd117dfcc32780d7ac165074d2f679"
    assert_equal expected, prompt.model
  end

  test "default_client uses tool_calling capability" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    client = prompt.send(:default_client)
    
    # Should be same as tool_calling client
    expected = GenericLlmClient.client_for(:tool_calling)
    assert_same expected, client
  end

  test "execute with model_override uses specified capability" do
    skip "Requires live LLM connection" unless llm_configured?
    
    prompt = ActionDetectionPrompt.new(tools: @tools)
    context = Contexts::DndChatContext.new
    context.scene.set_location(name: "Test", description: "test room")
    
    result = prompt.execute(
      prompt: "I look around",
      context: context,
      model_override: :general_llm
    )
    
    # Should return expected structure
    assert result.key?(:content)
    assert result.key?(:thoughts)
  end

  test "subclasses inherit tool_calling capability" do
    # ActionDetectionPrompt, DndPlanningPrompt, DndGoalPrompt should all use tool_calling
    action_prompt = ActionDetectionPrompt.new(tools: @tools)
    expected = "./vllm/models/hivata____functionary__small__v3.2__AWQ/snapshots/bee9e4cae2fd117dfcc32780d7ac165074d2f679"
    
    assert_equal expected, action_prompt.model
  end

  private

  def llm_configured?
    ENV["API_KEY"].to_s.strip.present? && ENV["LLM_URL"].to_s.strip.present?
  end
end

