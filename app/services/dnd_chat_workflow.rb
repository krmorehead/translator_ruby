# frozen_string_literal: true

# Builds standardized OpenAI chat parameters for the DnD tools workflow.
# Ensures a consistent system prompt and includes the registered tool schemas.
class DndChatWorkflow
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a DnD assistant with access to tools. Always respond by calling one or more tools; never answer directly without using a tool call.
    Return ONLY valid JSON that matches the response_format schema:
    {
      "tool": "<tool_name>",
      "arguments": { ...all required arguments for that tool... }
    }
    Do not include prose outside the JSON. Include all required arguments for the chosen tool.
  PROMPT

  def initialize(tool_call_service: ToolCallService)
    @tool_call_service = tool_call_service
  end

  # Returns a parameter hash suitable for OpenAI::Client#chat
  def chat_parameters(user_prompt:, model: ENV["LLM_MODEL"] || "qwen30b", extra_system_prompt: nil)
    tool_names = @tool_call_service.available_tools.map { |t| t[:function][:name] }

    {
      model: model,
      messages: [
        { role: "system", content: system_prompt(extra_system_prompt) },
        { role: "user", content: user_prompt }
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "tool_call",
          strict: true,
          schema: {
            type: "object",
            properties: {
              tool: { type: "string", enum: tool_names },
              arguments: { type: "object", additionalProperties: true }
            },
            required: %w[tool arguments],
            additionalProperties: false
          }
        }
      }
    }
  end

  private

  def system_prompt(extra)
    return DEFAULT_SYSTEM_PROMPT unless extra&.strip&.length&.positive?

    "#{DEFAULT_SYSTEM_PROMPT}\n\n#{extra}".strip
  end
end

