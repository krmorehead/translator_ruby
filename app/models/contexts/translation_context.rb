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
    attr_reader :glossary_entries, :style_guidelines, :translation_history, :protected_term_entries

    def initialize(target_language: nil, source_language: "en", formality: "formal", protected_strings: [])
      super()
      @target_language = target_language
      @source_language = source_language
      @formality = formality
      @protected_strings = Array(protected_strings)
      
      # Dedicated collections for different entry types
      @glossary_entries = []
      @style_guidelines = []
      @translation_history = []
      @protected_term_entries = []
    end

    # Add a protected term that should not be translated
    # @param term [String] The term to protect
    # @param reason [String] Why it should be protected (brand name, etc)
    # @return [Entries::ProtectedTermEntry]
    def add_protected_term(term:, reason: nil)
      @protected_strings << term unless @protected_strings.include?(term)

      entry = Entries::ProtectedTermEntry.new(
        content: reason ? "#{term}: #{reason}" : term,
        topics: ["#{TOPIC_PREFIXES[:protected]}#{term.downcase}"],
        source: "protected_terms",
        metadata: {},
        term: term,
        reason: reason
      )
      
      @protected_term_entries << entry
      @entries << entry  # Also add to general entries for topic indexing
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add a glossary entry for consistent translations
    # @param source_term [String] The term in source language
    # @param target_term [String] The preferred translation
    # @param context_hint [String] When to use this translation
    # @return [Entries::GlossaryEntry]
    def add_glossary_entry(source_term:, target_term:, context_hint: nil)
      content = "#{source_term} → #{target_term}"
      content += " (#{context_hint})" if context_hint

      entry = Entries::GlossaryEntry.new(
        content: content,
        topics: [
          "#{TOPIC_PREFIXES[:glossary]}#{source_term.downcase}",
          "#{TOPIC_PREFIXES[:term]}#{source_term.downcase}"
        ],
        source: "glossary",
        metadata: {},
        source_term: source_term,
        target_term: target_term,
        context_hint: context_hint
      )
      
      @glossary_entries << entry
      @entries << entry  # Also add to general entries for topic indexing
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add a completed translation for reference/consistency
    # @param source_text [String] Original text
    # @param translated_text [String] Translated text
    # @param context_path [String] The context path (e.g., "messages.welcome")
    # @return [Entries::TranslationHistoryEntry]
    def add_translation(source_text:, translated_text:, context_path: nil)
      entry = Entries::TranslationHistoryEntry.new(
        content: "#{source_text} → #{translated_text}",
        topics: ["#{TOPIC_PREFIXES[:translation]}#{context_path || 'general'}"],
        source: context_path || "translation",
        metadata: {},
        source_text: source_text,
        translated_text: translated_text,
        context_path: context_path
      )
      
      @translation_history << entry
      @entries << entry  # Also add to general entries for topic indexing
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add a style guideline for translations
    # @param guideline [String] The style guideline
    # @param category [String] Category of guideline (tone, grammar, etc)
    # @return [Entries::StyleGuidelineEntry]
    def add_style_guideline(guideline:, category: "general")
      entry = Entries::StyleGuidelineEntry.new(
        content: guideline,
        topics: ["#{TOPIC_PREFIXES[:style]}#{category.downcase}"],
        source: "style_guidelines",
        metadata: {},
        guideline: guideline,
        category: category
      )
      
      @style_guidelines << entry
      @entries << entry  # Also add to general entries for topic indexing
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Get glossary entries relevant to a text
    # @param text [String] Text to find glossary matches for
    # @param limit [Integer] Maximum entries
    # @return [Array<Entries::GlossaryEntry>] Relevant glossary entries
    def glossary_for(text, limit: 5)
      # Find glossary entries whose source term appears in the text
      matching = @glossary_entries.select { |entry| entry.relevant_to?(text) }
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
      if @style_guidelines.any?
        style_text = @style_guidelines.last(3).map(&:content).join(". ")
        parts << "Style: #{style_text}"
      end

      # Recent similar translations for consistency
      if @translation_history.any?
        recent = @translation_history.last(3).map(&:content).join("; ")
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
        protected_strings: @protected_strings,
        glossary_entries: @glossary_entries.map(&:to_h),
        style_guidelines: @style_guidelines.map(&:to_h),
        translation_history: @translation_history.map(&:to_h),
        protected_term_entries: @protected_term_entries.map(&:to_h)
      )
    end

    # Override from_h to restore translation-specific attributes
    def self.from_h(hash)
      raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
      raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }

      context = allocate
      context.instance_variable_set(:@target_language, hash[:target_language])
      context.instance_variable_set(:@source_language, hash[:source_language] || "en")
      context.instance_variable_set(:@formality, hash[:formality] || "formal")
      context.instance_variable_set(:@protected_strings, hash[:protected_strings] || [])
      context.instance_variable_set(:@entries, [])
      context.instance_variable_set(:@topic_index, Hash.new { |h, k| h[k] = Set.new })
      context.instance_variable_set(:@sub_contexts, {})

      # Reconstruct specialized collections
      glossary = (hash[:glossary_entries] || []).map { |e| Entries::GlossaryEntry.from_h(e) }
      styles = (hash[:style_guidelines] || []).map { |e| Entries::StyleGuidelineEntry.from_h(e) }
      history = (hash[:translation_history] || []).map { |e| Entries::TranslationHistoryEntry.from_h(e) }
      protected = (hash[:protected_term_entries] || []).map { |e| Entries::ProtectedTermEntry.from_h(e) }
      
      context.instance_variable_set(:@glossary_entries, glossary)
      context.instance_variable_set(:@style_guidelines, styles)
      context.instance_variable_set(:@translation_history, history)
      context.instance_variable_set(:@protected_term_entries, protected)

      load_entries_from_h(context, hash)
      load_sub_contexts_from_h(context, hash)
      context
    end

    
    # Boost relevance for matching source terms
    def calculate_relevance_score(entry, question_keywords)
      base_score = super

      # Boost glossary entries with matching terms
      if entry.is_a?(Entries::GlossaryEntry)
        term_keywords = extract_keywords(entry.source_term)
        term_overlap = (question_keywords & term_keywords).size
        base_score += term_overlap * 3
      end

      base_score
    end
  end
end

