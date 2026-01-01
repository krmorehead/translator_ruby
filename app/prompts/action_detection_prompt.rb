# frozen_string_literal: true


class ActionDetectionPrompt < ToolCallPrompt
  def initialize(tools:)
    raise ArgumentError, "tools are required for action detection" if tools.nil? || tools.empty?

    super(tools: tools)
  end

  def system_prompt
    <<~PROMPT
      You analyze the player's latest message and identify discrete actions the player wants to perform.
      Use the available tools to map each action to a specific tool call with arguments.
      Return an array of actions. If the message is purely conversational, return an empty array.
      If ambiguous, pick the single most likely action. For multi-part input, return actions in order.
      Available tools (name, description, parameters):
      #{serialize_tools}
    PROMPT
  end

  def response_schema
    # Extract tool names from Tool objects
    tool_names = tools.map(&:name)

    {
      type: "array",
      items: {
        type: "object",
        properties: {
          prompt_reference: { type: "string" },
          tool_name: { type: "string", enum: tool_names },
          arguments: { type: "object", additionalProperties: true }
        },
        required: %w[prompt_reference tool_name arguments],
        additionalProperties: false
      }
    }
  end

  def format_context(context, question: nil)
    raise ArgumentError, "context is required" if context.nil?

    # Use action_detection format for tight, focused context
    # Tools are already in the system prompt - don't duplicate
    context.format_for_prompt(question || "", format: :action_detection)
  end

  def execute(prompt:, context:)
    result = super(prompt: prompt, context: context)
    content = result[:content]
    
    return { content: [], thoughts: result[:thoughts] } if content.nil?
    return result if content.is_a?(Array)

    raise "Expected array of actions, got #{content.class}"
  end
end
