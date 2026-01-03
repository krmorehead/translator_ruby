# frozen_string_literal: true

module Contexts
  module Entries
    # Research-specific entry that tracks findings with confidence scores.
    # Used by ResearchContext to store code analysis findings.
    class ResearchEntry < BaseEntry
      attr_reader :file_path, :sub_question, :confidence

      def initialize(finding:, file_path:, sub_question:, confidence: 0.5, topics: [], source: nil, metadata: {})
        raise ArgumentError, "finding must be a String" unless finding.is_a?(String)
        raise ArgumentError, "file_path must be a String" unless file_path.is_a?(String)
        raise ArgumentError, "confidence must be a Numeric" unless confidence.is_a?(Numeric)
        raise ArgumentError, "confidence must be between 0 and 1" unless confidence.between?(0, 1)

        @file_path = file_path
        @sub_question = sub_question
        @confidence = confidence

        # Build topics from file path and sub-question
        research_topics = topics.dup
        research_topics << "file:#{File.basename(file_path, '.*')}"
        research_topics << "finding"

        super(
          content: finding,
          topics: research_topics,
          source: source || file_path,
          metadata: metadata.merge(
            type: :finding,
            file_path: file_path,
            sub_question: sub_question,
            confidence: confidence
          )
        )
      end

      def confidence_level
        case @confidence
        when 0...0.3 then :low
        when 0.3...0.7 then :medium
        else :high
        end
      end

      def to_h
        {
          **super,
          file_path: @file_path,
          sub_question: @sub_question,
          confidence: @confidence
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required research entry keys" unless
          hash.key?(:file_path) && hash.key?(:confidence)

        entry = allocate
        entry.instance_variable_set(:@id, hash[:id])
        entry.instance_variable_set(:@content, hash[:content])
        entry.instance_variable_set(:@topics, hash[:topics])
        entry.instance_variable_set(:@source, hash[:source])
        entry.instance_variable_set(:@timestamp, hash[:timestamp])
        entry.instance_variable_set(:@metadata, hash[:metadata] || {})
        entry.instance_variable_set(:@file_path, hash[:file_path])
        entry.instance_variable_set(:@sub_question, hash[:sub_question])
        entry.instance_variable_set(:@confidence, hash[:confidence])
        entry
      end
    end
  end
end








