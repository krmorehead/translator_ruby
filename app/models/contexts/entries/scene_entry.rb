# frozen_string_literal: true

module Contexts
  module Entries
    # Scene-specific entry for D&D contexts.
    # Tracks locations, NPCs, objects, hazards with entity types.
    class SceneEntry < BaseEntry
      ENTITY_TYPES = [:location, :npc, :object, :hazard, :exit, :atmosphere, :description].freeze

      attr_reader :entity_type, :entity_name

      def initialize(entity_type:, name:, description:, topics: [], source: nil, metadata: {})
        raise ArgumentError, "entity_type must be a Symbol" unless entity_type.is_a?(Symbol)
        raise ArgumentError, "Invalid entity_type: #{entity_type}" unless ENTITY_TYPES.include?(entity_type)
        raise ArgumentError, "name must be a String" unless name.is_a?(String)
        raise ArgumentError, "description must be a String" unless description.is_a?(String)

        @entity_type = entity_type
        @entity_name = name

        # Build topics from entity type and name
        scene_topics = topics.dup
        scene_topics << entity_type.to_s
        scene_topics << "#{entity_type}:#{name.downcase.gsub(/\s+/, '_')}"

        content = if description.start_with?("#{name}:")
          description
        else
          "#{name}: #{description}"
        end

        super(
          content: content,
          topics: scene_topics,
          source: source || entity_type.to_s,
          metadata: metadata.merge(
            entity_type: entity_type,
            name: name
          )
        )
      end

      def to_h
        {
          **super,
          entity_type: @entity_type,
          entity_name: @entity_name
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required scene entry keys" unless
          hash.key?(:entity_type) && hash.key?(:entity_name)

        entry = allocate
        entry.instance_variable_set(:@id, hash[:id])
        entry.instance_variable_set(:@content, hash[:content])
        entry.instance_variable_set(:@topics, hash[:topics])
        entry.instance_variable_set(:@source, hash[:source])
        entry.instance_variable_set(:@timestamp, hash[:timestamp])
        entry.instance_variable_set(:@metadata, hash[:metadata] || {})
        entry.instance_variable_set(:@entity_type, hash[:entity_type])
        entry.instance_variable_set(:@entity_name, hash[:entity_name])
        entry
      end
    end
  end
end

