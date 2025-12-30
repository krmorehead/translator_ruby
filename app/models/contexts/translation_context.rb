# frozen_string_literal: true

module Contexts
  # Translation-specific context that tracks translation settings, protected terms,
  # and provides relevant context for translation prompts.
  #
  # Key features:
  # - Tracks language pairs, formality, protected strings
  # - Maintains translation history for consistency
  # - Provides context-aware formatting for translation prompts
  #
  # Note: This is separate from the legacy TranslationContext class (app/models/translation_context.rb)
  # which is a simple data holder. This Context provides smart relevance filtering.
  class TranslationContext < BaseContext
    # Translation-specific topic prefixes
    TOPIC_PREFIXES = {
      term: "term:",
      protected: "protected:",
      glossary: "glossary:",
      translation: "translation:",
      style: "style:"
    }.freeze

    attr_accessor :target_language, :source_language, :formality, :protected_strings

    def initialize(target_language: nil, source_language: "en", formality: "formal", protected_strings: [])
      super()
      @target_language = target_language
      @source_language = source_language
      @formality = formality
      @protected_strings = Array(protected_strings)
    end

    # Add a protected term that should not be translated
    # @param term [String] The term to protect
    # @param reason [String] Why it should be protected (brand name, etc)
    # @return [Entry]
    def add_protected_term(term:, reason: nil)
      @protected_strings << term unless @protected_strings.include?(term)

      add(
        content: reason ? "#{term}: #{reason}" : term,
        topics: ["#{TOPIC_PREFIXES[:protected]}#{term.downcase}"],
        source: "protected_terms",
        metadata: { entity_type: :protected_term, term: term, reason: reason }
      )
    end

    # Add a glossary entry for consistent translations
    # @param source_term [String] The term in source language
    # @param target_term [String] The preferred translation
    # @param context_hint [String] When to use this translation
    # @return [Entry]
    def add_glossary_entry(source_term:, target_term:, context_hint: nil)
      content = "#{source_term} → #{target_term}"
      content += " (#{context_hint})" if context_hint

      add(
        content: content,
        topics: [
          "#{TOPIC_PREFIXES[:glossary]}#{source_term.downcase}",
          "#{TOPIC_PREFIXES[:term]}#{source_term.downcase}"
        ],
        source: "glossary",
        metadata: {
          entity_type: :glossary_entry,
          source_term: source_term,
          target_term: target_term,
          context_hint: context_hint
        }
      )
    end

    # Add a completed translation for reference/consistency
    # @param source_text [String] Original text
    # @param translated_text [String] Translated text
    # @param context_path [String] The context path (e.g., "messages.welcome")
    # @return [Entry]
    def add_translation(source_text:, translated_text:, context_path: nil)
      add(
        content: "#{source_text} → #{translated_text}",
        topics: ["#{TOPIC_PREFIXES[:translation]}#{context_path || 'general'}"],
        source: context_path || "translation",
        metadata: {
          entity_type: :translation,
          source_text: source_text,
          translated_text: translated_text,
          context_path: context_path
        }
      )
    end

    # Add a style guideline for translations
    # @param guideline [String] The style guideline
    # @param category [String] Category of guideline (tone, grammar, etc)
    # @return [Entry]
    def add_style_guideline(guideline:, category: "general")
      add(
        content: guideline,
        topics: ["#{TOPIC_PREFIXES[:style]}#{category.downcase}"],
        source: "style_guidelines",
        metadata: { entity_type: :style_guideline, category: category }
      )
    end

    # Get glossary entries relevant to a text
    # @param text [String] Text to find glossary matches for
    # @param limit [Integer] Maximum entries
    # @return [Array<Entry>] Relevant glossary entries
    def glossary_for(text, limit: 5)
      text_lower = text.downcase
      glossary_entries = @entries.select { |e| e.metadata[:entity_type] == :glossary_entry }

      # Find glossary entries whose source term appears in the text
      matching = glossary_entries.select do |entry|
        source_term = entry.metadata[:source_term]&.downcase
        source_term && text_lower.include?(source_term)
      end

      matching.last(limit)
    end

    # Get all protected terms
    # @return [Array<String>] Protected term strings
    def all_protected_terms
      @protected_strings.dup
    end

    # Format context for translation prompts
    # Includes language settings, protected terms, glossary, style, and recent translations
    # @param text_to_translate [String] The text being translated
    # @return [String] Formatted context
    def format_for_translation(text_to_translate)
      parts = []

      # Language settings
      parts << "Language: #{@source_language} → #{@target_language}"
      parts << "Formality: #{@formality}"

      # Protected terms
      if @protected_strings.any?
        parts << "Protected terms (do not translate): #{@protected_strings.join(', ')}"
      end

      # Relevant glossary entries
      glossary = glossary_for(text_to_translate)
      if glossary.any?
        glossary_text = glossary.map(&:content).join("; ")
        parts << "Glossary: #{glossary_text}"
      end

      # Style guidelines
      style_entries = @entries.select { |e| e.metadata[:entity_type] == :style_guideline }
      if style_entries.any?
        style_text = style_entries.last(3).map(&:content).join(". ")
        parts << "Style: #{style_text}"
      end

      # Recent similar translations for consistency
      relevant = relevant_to(text_to_translate || "", limit: 3)
      translation_entries = relevant.select { |e| e.metadata[:entity_type] == :translation }
      if translation_entries.any?
        recent = translation_entries.map(&:content).join("; ")
        parts << "Recent translations: #{recent}"
      end

      parts.join("\n")
    end

    # Override format_for_prompt for translation-specific formatting
    # Default format is :translation which includes language, protected terms, glossary
    # @param question [String] The text to translate
    # @param format [Symbol] Output format (:translation, :brief, :detailed)
    # @return [String] Formatted context
    def format_for_prompt(question, format: :translation)
      case format
      when :translation
        format_for_translation(question)
      else
        super(question, format: format)
      end
    end

    # Convert to a hash suitable for TranslationPrompt context parameter
    # @return [Hash] Context hash for prompts
    def to_prompt_hash
      {
        target_language: @target_language,
        source_language: @source_language,
        formality: @formality,
        protected_strings: @protected_strings
      }
    end

    # Override to_h to include translation-specific attributes
    def to_h
      super.merge(
        target_language: @target_language,
        source_language: @source_language,
        formality: @formality,
        protected_strings: @protected_strings
      )
    end

    # Override from_h to restore translation-specific attributes
    def self.from_h(data, context_registry: nil)
      context = new(
        target_language: data[:target_language] || data["target_language"],
        source_language: data[:source_language] || data["source_language"] || "en",
        formality: data[:formality] || data["formality"] || "formal",
        protected_strings: data[:protected_strings] || data["protected_strings"] || []
      )
      load_entries_from_h(context, data)
      load_sub_contexts_from_h(context, data, context_registry)
      context
    end

    
    # Boost relevance for matching source terms
    def calculate_relevance_score(entry, question_keywords)
      base_score = super

      # Boost glossary entries with matching terms
      if entry.metadata[:source_term]
        term_keywords = extract_keywords(entry.metadata[:source_term])
        term_overlap = (question_keywords & term_keywords).size
        base_score += term_overlap * 3
      end

      base_score
    end
  end
end

