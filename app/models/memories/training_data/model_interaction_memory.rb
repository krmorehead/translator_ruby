# frozen_string_literal: true

module Memories
  module TrainingData
    class ModelInteractionMemory < BaseMemory
      def self.section_name
        MemoryKinds::MODEL_INTERACTIONS
      end

      def self.default
        []
      end

      # Weight is 0.0 because this is metadata for training, not narrative content
      def self.weight
        0.0
      end

      # Append a new model interaction to the store
      # @param store [MemoryStore] The memory store
      # @param interaction [Hash] The interaction data
      #   - timestamp: ISO8601 timestamp
      #   - request: { model:, messages:, parameters: }
      #   - response: { content:, finish_reason: }
      #   - thoughts: extracted think content or nil
      def self.append(store:, interaction:)
        entry = normalize_entry(interaction)
        store.update_section(name: section_name, content: entry, append: true)
      end

      # Return array of all recorded interactions
      def self.to_h(store:)
        store.get_section(section_name) || default
      end

      # Summarize returns count of interactions
      def self.summarize(store:)
        interactions = to_h(store: store)
        {
          section: section_name,
          summary: "#{interactions.size} model interaction(s) recorded"
        }
      end
    end
  end
end

