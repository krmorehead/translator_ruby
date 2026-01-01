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
  speed_profile :fast
  test "initializes with translation settings" do
    assert_equal "Spanish", context.target_language
    assert_equal "en", context.source_language
    assert_equal "formal", context.formality
    assert_includes context.protected_strings, "Brightwheel"
  end

  speed_profile :fast
  test "add_protected_term adds to protected_strings and creates entry" do
    entry = context.add_protected_term(term: "CompanyName", reason: "Brand name")

    assert_includes context.protected_strings, "CompanyName"
    assert_instance_of Contexts::Entries::ProtectedTermEntry, entry
    assert_equal "CompanyName", entry.term
    assert_equal 1, context.protected_term_entries.size
    assert_equal 1, context.size
  end

  speed_profile :fast
  test "add_glossary_entry creates searchable glossary" do
    entry = context.add_glossary_entry(
      source_term: "child",
      target_term: "niño",
      context_hint: "when referring to students"
    )

    assert_instance_of Contexts::Entries::GlossaryEntry, entry
    assert entry.content.include?("child → niño")
    assert entry.topics.any? { |t| t.include?("glossary:") }
    assert_equal "child", entry.source_term
    assert_equal "niño", entry.target_term
    assert_equal 1, context.glossary_entries.size
  end

  speed_profile :fast
  test "add_translation records translation history" do
    entry = context.add_translation(
      source_text: "Hello",
      translated_text: "Hola",
      context_path: "greetings.welcome"
    )

    assert_instance_of Contexts::Entries::TranslationHistoryEntry, entry
    assert_equal "Hello", entry.source_text
    assert_equal "Hola", entry.translated_text
    assert_equal 1, context.translation_history.size
  end

  speed_profile :fast
  test "add_style_guideline creates style entry" do
    entry = context.add_style_guideline(
      guideline: "Use formal 'usted' form",
      category: "formality"
    )

    assert_instance_of Contexts::Entries::StyleGuidelineEntry, entry
    assert_equal "Use formal 'usted' form", entry.guideline
    assert_equal "formality", entry.category
    assert_equal 1, context.style_guidelines.size
  end

  speed_profile :fast
  test "glossary_for finds relevant glossary entries" do
    context.add_glossary_entry(source_term: "child", target_term: "niño")
    context.add_glossary_entry(source_term: "parent", target_term: "padre")

    results = context.glossary_for("The child is playing")
    assert_equal 1, results.size
    assert results.first.content.include?("child")
  end

  speed_profile :fast
  test "all_protected_terms returns copy of protected strings" do
    terms = context.all_protected_terms
    assert_includes terms, "Brightwheel"

    # Modifying return value shouldn't affect original
    terms << "NewTerm"
    refute_includes context.protected_strings, "NewTerm"
  end

  speed_profile :fast
  test "format_for_translation includes language and protected terms" do
    formatted = context.format_for_translation("Hello world")

    assert formatted.include?("en → Spanish")
    assert formatted.include?("formal")
    assert formatted.include?("Brightwheel")
  end

  speed_profile :fast
  test "format_for_translation includes relevant glossary" do
    context.add_glossary_entry(source_term: "hello", target_term: "hola")

    formatted = context.format_for_translation("Say hello to everyone")

    assert formatted.include?("Glossary")
    assert formatted.include?("hello → hola")
  end

  speed_profile :fast
  test "format_for_prompt with :translation format" do
    formatted = context.format_for_prompt("translate this", format: :translation)

    assert formatted.include?("Spanish")
    assert formatted.include?("formal")
  end

  speed_profile :fast
  test "to_prompt_hash returns settings hash" do
    hash = context.to_prompt_hash

    assert_equal "Spanish", hash[:target_language]
    assert_equal "en", hash[:source_language]
    assert_equal "formal", hash[:formality]
  end

  speed_profile :fast
  test "serializes with translation settings" do
    context.add_glossary_entry(source_term: "test", target_term: "prueba")

    hash = context.to_h
    assert_equal "Spanish", hash[:target_language]
    assert_includes hash[:protected_strings], "Brightwheel"
  end

  speed_profile :fast
  test "deserializes with translation settings" do
    context.add_glossary_entry(source_term: "demo", target_term: "demostración")

    hash = context.to_h
    restored = Contexts::TranslationContext.from_h(hash)

    assert_equal "Spanish", restored.target_language
    assert_equal "en", restored.source_language
    assert_equal 1, restored.size
  end
end

