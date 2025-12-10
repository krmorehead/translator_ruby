# frozen_string_literal: true

require_relative "base_prompt"

class NarrativePrompt < BasePrompt
  def model
    ENV["NARRATIVE_MODEL"].presence || super
  end

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

  def format_context(context)
    context ||= {}
    actions = context[:actions] || context["actions"] || []
    scene = context[:scene] || context["scene"]
    history = context[:recent_conversation] || context["recent_conversation"]

    parts = []
    parts << "Completed actions:\n#{JSON.pretty_generate(actions)}" if actions.any?
    parts << "Scene:\n#{scene}" if scene
    parts << "Recent conversation:\n#{JSON.pretty_generate(history)}" if history
    parts.join("\n\n")
  end

  def execute(prompt:, context: {})
    super.to_s
  end
end
