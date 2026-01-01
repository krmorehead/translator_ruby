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
  speed_profile :fast
  test "inherits from BasePrompt" do
    assert ToolCallPrompt < BasePrompt
  end

  speed_profile :fast
  test "uses tool_calling capability model by default" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    expected = GenericLlmClient::CAPABILITIES[:tool_calling][:model_name]
    assert_equal expected, prompt.model
  end

  speed_profile :fast
  test "default_client uses tool_calling capability" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    client = prompt.send(:default_client)
    
    # Should be same as tool_calling client
    expected = GenericLlmClient.client_for(:tool_calling)
    assert_same expected, client
  end

  speed_profile :medium
  test "execute with model_override uses specified capability" do
    assert llm_configured?, "LLM must be configured for this test"
    
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

  speed_profile :fast
  test "subclasses inherit tool_calling capability" do
    # ActionDetectionPrompt should use tool_calling
    action_prompt = ActionDetectionPrompt.new(tools: @tools)
    expected = GenericLlmClient::CAPABILITIES[:tool_calling][:model_name]
    
    assert_equal expected, action_prompt.model
  end

  speed_profile :fast
  test "max_safe_context reads from capability config" do
    prompt = ActionDetectionPrompt.new(tools: @tools)
    expected = GenericLlmClient::CAPABILITIES[:tool_calling][:max_context]
    
    assert_equal expected, prompt.max_safe_context
  end

  
  def llm_configured?
    ENV["API_KEY"].to_s.strip.present? && ENV["LLM_URL"].to_s.strip.present?
  end
end
