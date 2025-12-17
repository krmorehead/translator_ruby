# frozen_string_literal: true


class ActionDetectionPrompt < BasePrompt
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
      #{serialize_tools(tools)}
    PROMPT
  end

  def response_schema
    tool_names = tools.map { |t| t.dig(:function, :name) }.compact

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

  def format_context(context)
    context ||= {}
    scene = context[:scene] || context["scene"]
    memory = context[:memory] || context["memory"]
    history = context[:recent_conversation] || context["recent_conversation"]

    sections = []
    sections << "Current scene:\n#{scene}" if scene
    sections << "Memory:\n#{JSON.pretty_generate(memory)}" if memory
    sections << "Recent conversation:\n#{JSON.pretty_generate(history)}" if history
    sections << "Available tools:\n#{serialize_tools(tools)}"
    sections.join("\n\n")
  end

  def execute(prompt:, context: {})
    result = super
    content = result[:content]
    
    return { content: [], thoughts: result[:thoughts] } if content.nil?
    return result if content.is_a?(Array)

    raise "Expected array of actions, got #{content.class}"
  end
end
