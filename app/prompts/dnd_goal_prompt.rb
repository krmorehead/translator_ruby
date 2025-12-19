# frozen_string_literal: true

# Prompt for evaluating whether the player's intent has been satisfied.
# Used by the D&D agent to decide when to stop executing actions and narrate.
class DndGoalPrompt < BasePrompt
  def system_prompt
    <<~PROMPT
      You evaluate whether the player's intent has been satisfied by the completed actions.
      
      Consider:
      - Did the actions address what the player wanted to do?
      - Is there enough information to generate a narrative response?
      - Are there any obvious follow-up actions needed?
      
      Be decisive. If the core intent is addressed, respond with intent_satisfied: true.
      Don't require perfection - if the player wanted to search a room and we searched it, that's satisfied.
    PROMPT
  end

  def response_schema
    {
      type: "object",
      properties: {
        intent_satisfied: { type: "boolean" },
        reasoning: { type: "string" },
        missing_actions: {
          type: "array",
          items: { type: "string" }
        }
      },
      required: %w[intent_satisfied reasoning],
      additionalProperties: false
    }
  end

  def format_context(context, question: nil)
    context.format_for_prompt(question || "", format: :brief)
  end
end

