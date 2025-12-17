# frozen_string_literal: true


class OutcomePrompt < BasePrompt
  def system_prompt
    <<~PROMPT
      You determine the narrative consequence of an action.
      Consider the action performed, the tool result, and current story context.
      Return a brief consequence (1-2 sentences) that is story-focused, not mechanical.
      If the tool failed, describe what went wrong in narrative terms.
    PROMPT
  end

  def response_schema
    {
      type: "object",
      properties: {
        consequence: { type: "string" }
      },
      required: [ "consequence" ],
      additionalProperties: false
    }
  end

  def format_context(context)
    context ||= {}
    action = context[:action]
    result = context[:result]
    scene = context[:scene]

    sections = []
    sections << "Action:\n#{JSON.pretty_generate(action)}" if action
    sections << "Tool result:\n#{JSON.pretty_generate(result)}" if result
    sections << "Scene:\n#{scene}" if scene
    sections.join("\n\n")
  end
end
