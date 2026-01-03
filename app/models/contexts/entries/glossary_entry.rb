# frozen_string_literal: true

module Contexts
  module Entries
    # Represents a glossary entry for consistent translations.
    # Maps source terms to preferred target translations with optional context hints.
    class GlossaryEntry < BaseEntry
      attr_reader :source_term, :target_term, :context_hint

      def initialize(content:, topics:, source:, metadata: {}, source_term:, target_term:, context_hint: nil)
        super(content: content, topics: topics, source: source, metadata: metadata)
        raise ArgumentError, "source_term must be a String" unless source_term.is_a?(String)
        raise ArgumentError, "target_term must be a String" unless target_term.is_a?(String)
        raise ArgumentError, "context_hint must be a String if provided" if context_hint && !context_hint.is_a?(String)

        @source_term = source_term
        @target_term = target_term
        @context_hint = context_hint
      end

      # Check if this glossary entry is relevant to a given text
      # @param text [String] Text to check
      # @return [Boolean] Whether the source term appears in the text
      def relevant_to?(text)
        return false unless text.is_a?(String)
        text.downcase.include?(@source_term.downcase)
      end

      def to_h
        super.merge(
          source_term: @source_term,
          target_term: @target_term,
          context_hint: @context_hint
        )
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys for GlossaryEntry" unless
          hash.key?(:source_term) && hash.key?(:target_term)

        entry = super(hash)
        entry.instance_variable_set(:@source_term, hash[:source_term])
        entry.instance_variable_set(:@target_term, hash[:target_term])
        entry.instance_variable_set(:@context_hint, hash[:context_hint])
        entry
      end
    end
  end
end








