# frozen_string_literal: true

module Contexts
  module Entries
    # Represents a completed translation for reference and consistency.
    # Tracks source text, translated text, and context path.
    class TranslationHistoryEntry < BaseEntry
      attr_reader :source_text, :translated_text, :context_path

      def initialize(content:, topics:, source:, metadata: {}, source_text:, translated_text:, context_path: nil)
        super(content: content, topics: topics, source: source, metadata: metadata)
        raise ArgumentError, "source_text must be a String" unless source_text.is_a?(String)
        raise ArgumentError, "translated_text must be a String" unless translated_text.is_a?(String)
        raise ArgumentError, "context_path must be a String if provided" if context_path && !context_path.is_a?(String)

        @source_text = source_text
        @translated_text = translated_text
        @context_path = context_path
      end

      def to_h
        super.merge(
          source_text: @source_text,
          translated_text: @translated_text,
          context_path: @context_path
        )
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys for TranslationHistoryEntry" unless
          hash.key?(:source_text) && hash.key?(:translated_text)

        entry = super(hash)
        entry.instance_variable_set(:@source_text, hash[:source_text])
        entry.instance_variable_set(:@translated_text, hash[:translated_text])
        entry.instance_variable_set(:@context_path, hash[:context_path])
        entry
      end
    end
  end
end

