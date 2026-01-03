# frozen_string_literal: true

module Contexts
  module Entries
    # Represents a style guideline for translations.
    # Provides guidance on tone, grammar, formatting, etc.
    class StyleGuidelineEntry < BaseEntry
      attr_reader :guideline, :category

      def initialize(content:, topics:, source:, metadata: {}, guideline:, category: "general")
        super(content: content, topics: topics, source: source, metadata: metadata)
        raise ArgumentError, "guideline must be a String" unless guideline.is_a?(String)
        raise ArgumentError, "category must be a String" unless category.is_a?(String)

        @guideline = guideline
        @category = category
      end

      def to_h
        super.merge(
          guideline: @guideline,
          category: @category
        )
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required key :guideline for StyleGuidelineEntry" unless hash.key?(:guideline)

        entry = super(hash)
        entry.instance_variable_set(:@guideline, hash[:guideline])
        entry.instance_variable_set(:@category, hash[:category] || "general")
        entry
      end
    end
  end
end








