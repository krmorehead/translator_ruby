# frozen_string_literal: true

module Contexts
  module Entries
    # Represents a protected term that should not be translated.
    # Examples: brand names, technical terms, proper nouns.
    class ProtectedTermEntry < BaseEntry
      attr_reader :term, :reason

      def initialize(content:, topics:, source:, metadata: {}, term:, reason: nil)
        super(content: content, topics: topics, source: source, metadata: metadata)
        raise ArgumentError, "term must be a String" unless term.is_a?(String)
        raise ArgumentError, "reason must be a String if provided" if reason && !reason.is_a?(String)

        @term = term
        @reason = reason
      end

      def to_h
        super.merge(
          term: @term,
          reason: @reason
        )
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required key :term for ProtectedTermEntry" unless hash.key?(:term)

        entry = super(hash)
        entry.instance_variable_set(:@term, hash[:term])
        entry.instance_variable_set(:@reason, hash[:reason])
        entry
      end
    end
  end
end

