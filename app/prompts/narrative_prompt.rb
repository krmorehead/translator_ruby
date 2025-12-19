# frozen_string_literal: true


class NarrativePrompt < BasePrompt
  CONTEXT_TOKEN_MAX = 8000

  def system_prompt
    <<~PROMPT
      You are the Dungeon Master narrating the story.
      Weave the player's completed actions and their consequences into an immersive, concise narrative (2-4 sentences).
      Keep the focus on storytelling. Never mention tools, dice rolls, DCs, files, or other mechanics.
      Maintain continuity with the existing scene and recent conversation.
    PROMPT
  end

  def response_schema
    nil
  end

  def format_context(context, question: nil)
    raise ArgumentError, "context is required" if context.nil?

    # Use narrative format for story-focused context
    context.format_for_prompt(question || "", format: :narrative)
  end

  def execute(prompt:, context: {})
    result = super
    { content: result[:content].to_s, thoughts: result[:thoughts] }
  end
end
