# frozen_string_literal: true

module Contexts
  module Entries
    # Base class for all context entries.
    # Provides common functionality for storing and serializing context information.
    #
    # Entries are immutable after creation except through controlled methods.
    # Each entry has an ID, content, topics for indexing, source tracking, and metadata.
    class BaseEntry
      attr_reader :id, :content, :topics, :source, :timestamp, :metadata

      def initialize(content:, topics:, source:, metadata: {})
        raise ArgumentError, "content must be a String" unless content.is_a?(String)
        raise ArgumentError, "topics must be an Array" unless topics.is_a?(Array)
        raise ArgumentError, "source must be a String" unless source.is_a?(String)
        raise TypeError, "metadata must be a Hash" unless metadata.is_a?(Hash)

        @id = SecureRandom.uuid
        @content = content
        @topics = normalize_topics(topics)
        @source = source
        @timestamp = Time.now.utc.iso8601
        @metadata = metadata
      end

      def to_h
        {
          id: @id,
          content: @content,
          topics: @topics,
          source: @source,
          timestamp: @timestamp,
          metadata: @metadata
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys" unless 
          hash.key?(:id) && hash.key?(:content) && hash.key?(:topics) && 
          hash.key?(:source) && hash.key?(:timestamp)

        entry = allocate
        entry.instance_variable_set(:@id, hash[:id])
        entry.instance_variable_set(:@content, hash[:content])
        entry.instance_variable_set(:@topics, hash[:topics])
        entry.instance_variable_set(:@source, hash[:source])
        entry.instance_variable_set(:@timestamp, hash[:timestamp])
        entry.instance_variable_set(:@metadata, hash[:metadata] || {})
        entry
      end

      private

      def normalize_topics(topics)
        Array(topics).map { |t| t.to_s.downcase.strip }.reject(&:empty?).uniq
      end
    end
  end
end


