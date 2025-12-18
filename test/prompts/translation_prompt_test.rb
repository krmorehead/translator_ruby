require "test_helper"

class TranslationPromptTest < ActiveSupport::TestCase
  test "includes protected strings in system prompt" do
    prompt = TranslationPrompt.new(
      protected_strings: [ "Brightwheel", "CustomApp" ],
      target_language: "Spanish",
      source_language: "English",
      formality: "formal"
    )

    system_prompt = prompt.system_prompt

    assert_includes system_prompt, "CustomApp"
    assert_includes system_prompt, "Brightwheel"
    assert_includes system_prompt, "Spanish"
  end

  test "response schema requires translation" do
    schema = TranslationPrompt.new(
      protected_strings: [],
      target_language: "Spanish",
      source_language: "English",
      formality: "formal"
    ).response_schema

    assert_equal "object", schema[:type]
    assert_equal [ "translation" ], schema[:required]
    assert_equal "string", schema[:properties][:translation][:type]
  end

  test "model falls back to translation-specific env or default" do
    ENV.delete("TRANSLATION_MODEL")
    prompt = TranslationPrompt.new(
      protected_strings: [],
      target_language: "Spanish",
      source_language: "English",
      formality: "formal"
    )

    assert_equal ENV["LLM_MODEL"].presence || "gpt-4o-mini", prompt.model
  end

  test "format_context includes provided metadata" do
    prompt = TranslationPrompt.new(
      protected_strings: [ "Brightwheel" ],
      target_language: "Spanish",
      source_language: "English",
      formality: "formal",
      context_path: "greeting.hello"
    )

    context = Contexts::TranslationContext.new(
      target_language: "Spanish",
      source_language: "English",
      formality: "formal",
      protected_strings: [ "Brightwheel" ]
    )

    formatted = prompt.format_context(context)

    assert_includes formatted, "Spanish"
    assert_includes formatted, "English"
    assert_includes formatted, "formal"
  end
end
