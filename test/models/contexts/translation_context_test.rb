# frozen_string_literal: true

require "test_helper"

class Contexts::TranslationContextTest < ActiveSupport::TestCase
  def context
    @context ||= Contexts::TranslationContext.new(
      target_language: "Spanish",
      source_language: "en",
      formality: "formal",
      protected_strings: ["Brightwheel"]
    )
  end

  test "initializes with translation settings" do
    assert_equal "Spanish", context.target_language
    assert_equal "en", context.source_language
    assert_equal "formal", context.formality
    assert_includes context.protected_strings, "Brightwheel"
  end

  test "add_protected_term adds to protected_strings and creates entry" do
    context.add_protected_term(term: "CompanyName", reason: "Brand name")

    assert_includes context.protected_strings, "CompanyName"
    assert_equal 1, context.size
  end

  test "add_glossary_entry creates searchable glossary" do
    context.add_glossary_entry(
      source_term: "child",
      target_term: "niño",
      context_hint: "when referring to students"
    )

    entry = context.entries.first
    assert entry.content.include?("child → niño")
    assert entry.topics.any? { |t| t.include?("glossary:") }
  end

  test "add_translation records translation history" do
    context.add_translation(
      source_text: "Hello",
      translated_text: "Hola",
      context_path: "greetings.welcome"
    )

    entry = context.entries.first
    assert_equal :translation, entry.metadata[:entity_type]
  end

  test "add_style_guideline creates style entry" do
    context.add_style_guideline(
      guideline: "Use formal 'usted' form",
      category: "formality"
    )

    entry = context.entries.first
    assert_equal :style_guideline, entry.metadata[:entity_type]
  end

  test "glossary_for finds relevant glossary entries" do
    context.add_glossary_entry(source_term: "child", target_term: "niño")
    context.add_glossary_entry(source_term: "parent", target_term: "padre")

    results = context.glossary_for("The child is playing")
    assert_equal 1, results.size
    assert results.first.content.include?("child")
  end

  test "all_protected_terms returns copy of protected strings" do
    terms = context.all_protected_terms
    assert_includes terms, "Brightwheel"

    # Modifying return value shouldn't affect original
    terms << "NewTerm"
    refute_includes context.protected_strings, "NewTerm"
  end

  test "format_for_translation includes language and protected terms" do
    formatted = context.format_for_translation("Hello world")

    assert formatted.include?("en → Spanish")
    assert formatted.include?("formal")
    assert formatted.include?("Brightwheel")
  end

  test "format_for_translation includes relevant glossary" do
    context.add_glossary_entry(source_term: "hello", target_term: "hola")

    formatted = context.format_for_translation("Say hello to everyone")

    assert formatted.include?("Glossary")
    assert formatted.include?("hello → hola")
  end

  test "format_for_prompt with :translation format" do
    formatted = context.format_for_prompt("translate this", format: :translation)

    assert formatted.include?("Spanish")
    assert formatted.include?("formal")
  end

  test "to_prompt_hash returns settings hash" do
    hash = context.to_prompt_hash

    assert_equal "Spanish", hash[:target_language]
    assert_equal "en", hash[:source_language]
    assert_equal "formal", hash[:formality]
  end

  test "serializes with translation settings" do
    context.add_glossary_entry(source_term: "test", target_term: "prueba")

    hash = context.to_h
    assert_equal "Spanish", hash[:target_language]
    assert_includes hash[:protected_strings], "Brightwheel"
  end

  test "deserializes with translation settings" do
    context.add_glossary_entry(source_term: "demo", target_term: "demostración")

    hash = context.to_h
    restored = Contexts::TranslationContext.from_h(hash)

    assert_equal "Spanish", restored.target_language
    assert_equal "en", restored.source_language
    assert_equal 1, restored.size
  end
end

