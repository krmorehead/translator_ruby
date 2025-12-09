# frozen_string_literal: true

# Builds standardized OpenAI chat parameters for the DnD tools workflow.
# Ensures a consistent system prompt and includes the registered tool schemas.
class DndChatWorkflow
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a DnD assistant with access to tools (memory, inventory, dice, skill checks, etc.). Always respond by calling one tool; do not reply in prose. Persist story state in memory/inventory tools so the inspector view can show progress. Do not invent dice results; use the dice_roll or skill_check tools instead of hard-coding outcomes.

    Rules:
    - If no current_scene or main_quest exists, create a fresh scenario + main quest using the memory tool with varied, creative content (do not reuse prior seeds).
    - If the player asks for scene context or story setup, first call memory tool to write to :recent_conversation and :current_scene with a short DM narration.
    - When narrating outcomes, call memory tool to append to :recent_conversation; keep entries concise (<= 2 sentences).
    - When the player acquires/uses items, call inventory tool to adjust quantities.
    - For actions requiring uncertainty, call dice_roll or skill_check as appropriate.
    - Return ONLY valid JSON matching the response_format schema: {"tool": "<tool_name>", "arguments": { ... }} with required arguments populated.
  PROMPT

  def initialize(tool_call_service: ToolCallService)
    @tool_call_service = tool_call_service
  end

  # Returns a parameter hash suitable for OpenAI::Client#chat
  def chat_parameters(user_prompt:, model: ENV["LLM_MODEL"] || "qwen30b", extra_system_prompt: nil, tools: @tool_call_service.available_dnd_tools)
    tool_names = tools.map { |t| t[:function][:name] }
    {
      model: model,
      messages: [
        { role: "system", content: system_prompt(extra_system_prompt) },
        { role: "user", content: user_prompt }
      ],
      tools: tools,
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

