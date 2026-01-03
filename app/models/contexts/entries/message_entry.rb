# frozen_string_literal: true

module Contexts
  module Entries
    # Message entry for conversation contexts.
    # Tracks speaker and message content for D&D conversations.
    class MessageEntry < BaseEntry
      attr_reader :speaker, :message

      def initialize(speaker:, message:, topics: [], source: "conversation", metadata: {})
        raise ArgumentError, "speaker must be a String" unless speaker.is_a?(String)
        raise ArgumentError, "message must be a String" unless message.is_a?(String)

        @speaker = speaker
        @message = message

        # Build topics from speaker
        message_topics = topics.dup
        message_topics << "conversation"
        message_topics << "speaker:#{speaker.downcase}"

        super(
          content: "#{speaker}: #{message}",
          topics: message_topics,
          source: source,
          metadata: metadata.merge(
            entity_type: :message,
            speaker: speaker
          )
        )
      end

      def to_h
        {
          **super,
          speaker: @speaker,
          message: @message
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required message entry keys" unless
          hash.key?(:speaker) && hash.key?(:message)

        entry = allocate
        entry.instance_variable_set(:@id, hash[:id])
        entry.instance_variable_set(:@content, hash[:content])
        entry.instance_variable_set(:@topics, hash[:topics])
        entry.instance_variable_set(:@source, hash[:source])
        entry.instance_variable_set(:@timestamp, hash[:timestamp])
        entry.instance_variable_set(:@metadata, hash[:metadata] || {})
        entry.instance_variable_set(:@speaker, hash[:speaker])
        entry.instance_variable_set(:@message, hash[:message])
        entry
      end
    end
  end
end








