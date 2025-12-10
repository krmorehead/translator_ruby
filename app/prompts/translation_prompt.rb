# frozen_string_literal: true

# Prompt that performs structured translations while preserving variables and protected terms.
class TranslationPrompt < BasePrompt
  def initialize(protected_strings:, target_language:, source_language:, formality:, context_path: nil)
    super(tools: [])
    @protected_strings = protected_strings || []
    @target_language = target_language
    @source_language = source_language
    @formality = formality
    @context_path = context_path
  end

  def system_prompt
    protected_list = @protected_strings.any? ? @protected_strings.join(", ") : "Brightwheel"

    <<~PROMPT
      You are a translation engine. Translate the user text into #{@target_language}.
      Preserve templated variables like {user_name} or {{count}} exactly as provided.
      Keep these protected terms unchanged: #{protected_list}.
      Return only JSON shaped as {"translation": "result"} with no extra commentary.
      Honor the requested formality and source language when provided.
    PROMPT
  end

  # Allow per-prompt model override with sensible fallback.
  def model
    ENV["TRANSLATION_MODEL"].presence || super || "gpt-4o-mini"
  end

  def response_schema
    {
      type: "object",
      properties: {
        translation: {
          type: "string",
          description: "Translated text with variables and protected terms preserved"
        }
      },
      required: ["translation"],
      additionalProperties: false
    }
  end

  # Include translation context in a structured way for the LLM.
  def format_context(context)
    data = {
      target_language: @target_language,
      source_language: @source_language,
      formality: @formality,
      context_path: @context_path
    }.merge(context || {}).compact

    return "" if data.empty?

    "Context:\n#{JSON.pretty_generate(data)}"
  end
end


