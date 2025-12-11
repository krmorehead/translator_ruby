# frozen_string_literal: true

require_relative "base_prompt"

class NarrativePrompt < BasePrompt
  CONTEXT_TOKEN_MAX = 8000

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
    compressed = context[:compressed_context] || context["compressed_context"]
    sections = context[:sections] || context["sections"]

    current = context[:current_context] || context["current_context"] || {}
    scene = current[:scene] || current["scene"] || context[:scene] || context["scene"]
    history = current[:recent_conversation] || current["recent_conversation"] || context[:recent_conversation] || context["recent_conversation"]
    people = current[:people] || current["people"]
    quest = current[:current_quest] || current["current_quest"]

    parts = []
    parts << "Completed actions:\n#{JSON.pretty_generate(actions)}" if actions.any?
    if compressed
      parts << "Compressed context:\n#{compressed}"
      parts << "Section summaries:\n#{JSON.pretty_generate(sections)}" if sections
    else
      parts << "Scene:\n#{scene}" if scene
      parts << "Current quest:\n#{quest}" if quest
      parts << "People:\n#{JSON.pretty_generate(people)}" if people
      parts << "Recent conversation:\n#{JSON.pretty_generate(history)}" if history
    end
    parts.join("\n\n")
  end

  def execute(prompt:, context: {})
    super.to_s
  end
end
