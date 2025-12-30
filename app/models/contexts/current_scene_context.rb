# frozen_string_literal: true

module Contexts
  # Scene-specific context with location, NPCs, environmental details.
  # Optimized for providing immersive scene information to prompts.
  #
  # Key features:
  # - Tracks location, atmosphere, NPCs present, environmental hazards
  # - Scene-specific topic prefixes for granular filtering
  # - Custom formatting that emphasizes sensory details
  class CurrentSceneContext < BaseContext
    # Scene-specific topic prefixes
    TOPIC_PREFIXES = {
      location: "loc:",
      atmosphere: "atm:",
      npc: "npc:",
      hazard: "hazard:",
      object: "obj:",
      exit: "exit:",
      description: "desc:"
    }.freeze

    attr_accessor :location_name, :atmosphere

    def initialize(location_name: nil, atmosphere: nil)
      super()
      @location_name = location_name
      @atmosphere = atmosphere
    end

    # Set the current location
    # @param name [String] Location name
    # @param description [String] Location description
    # @param metadata [Hash] Additional metadata (type, region, etc)
    # @return [Entry]
    def set_location(name:, description:, metadata: {})
      @location_name = name

      add(
        content: description,
        topics: ["#{TOPIC_PREFIXES[:location]}#{name.downcase.gsub(/\s+/, '_')}"],
        source: "location",
        metadata: metadata.merge(entity_type: :location, location_name: name, is_primary: true)
      )
    end

    # Set the scene atmosphere
    # @param description [String] Atmospheric description (lighting, sounds, smells)
    # @param mood [String] Overall mood (tense, peaceful, eerie, etc)
    # @return [Entry]
    def set_atmosphere(description:, mood: nil)
      @atmosphere = mood

      add(
        content: description,
        topics: ["#{TOPIC_PREFIXES[:atmosphere]}#{mood&.downcase || 'general'}"],
        source: "atmosphere",
        metadata: { entity_type: :atmosphere, mood: mood }
      )
    end

    # Add an NPC present in the scene
    # @param name [String] NPC name
    # @param description [String] NPC appearance/behavior
    # @param disposition [String] How they feel toward players (friendly, hostile, neutral)
    # @return [Entry]
    def add_npc(name:, description:, disposition: "neutral")
      add(
        content: "#{name}: #{description}",
        topics: ["#{TOPIC_PREFIXES[:npc]}#{name.downcase}"],
        source: "npcs",
        metadata: { entity_type: :npc, name: name, disposition: disposition }
      )
    end

    # Add an environmental hazard
    # @param name [String] Hazard name
    # @param description [String] Hazard description
    # @param severity [String] How dangerous (minor, moderate, severe)
    # @return [Entry]
    def add_hazard(name:, description:, severity: "moderate")
      add(
        content: "[HAZARD - #{severity.upcase}] #{name}: #{description}",
        topics: ["#{TOPIC_PREFIXES[:hazard]}#{name.downcase.gsub(/\s+/, '_')}"],
        source: "hazards",
        metadata: { entity_type: :hazard, name: name, severity: severity }
      )
    end

    # Add an interactive object in the scene
    # @param name [String] Object name
    # @param description [String] Object description
    # @param interactable [Boolean] Whether players can interact with it
    # @return [Entry]
    def add_object(name:, description:, interactable: true)
      add(
        content: "#{name}: #{description}",
        topics: ["#{TOPIC_PREFIXES[:object]}#{name.downcase.gsub(/\s+/, '_')}"],
        source: "objects",
        metadata: { entity_type: :object, name: name, interactable: interactable }
      )
    end

    # Add an exit/passage from the scene
    # @param direction [String] Direction or name of exit
    # @param destination [String] Where it leads
    # @param description [String] Exit description
    # @return [Entry]
    def add_exit(direction:, destination:, description: nil)
      content = description || "#{direction.capitalize} leads to #{destination}"

      add(
        content: content,
        topics: ["#{TOPIC_PREFIXES[:exit]}#{direction.downcase}"],
        source: "exits",
        metadata: { entity_type: :exit, direction: direction, destination: destination }
      )
    end

    # Get all NPCs currently in the scene
    # @return [Array<Entry>] NPC entries
    def npcs
      @entries.select { |e| e.metadata[:entity_type] == :npc }
    end

    # Get all hazards in the scene
    # @return [Array<Entry>] Hazard entries
    def hazards
      @entries.select { |e| e.metadata[:entity_type] == :hazard }
    end

    # Get all exits from the scene
    # @return [Array<Entry>] Exit entries
    def exits
      @entries.select { |e| e.metadata[:entity_type] == :exit }
    end

    # Get the primary location description
    # @return [Entry, nil] The primary location entry
    def location
      @entries.find { |e| e.metadata[:is_primary] && e.metadata[:entity_type] == :location }
    end

    # Format as an immersive scene description
    # @return [String] Formatted scene description
    def format_immersive
      parts = []

      # Location first
      loc = location
      parts << loc.content if loc

      # Atmosphere
      atm_entries = @entries.select { |e| e.metadata[:entity_type] == :atmosphere }
      parts << atm_entries.last&.content if atm_entries.any?

      # NPCs present
      npc_list = npcs
      if npc_list.any?
        npc_text = npc_list.map(&:content).join(". ")
        parts << "Present: #{npc_text}"
      end

      # Notable objects
      objects = @entries.select { |e| e.metadata[:entity_type] == :object && e.metadata[:interactable] }
      if objects.any?
        obj_text = objects.map { |o| o.content.split(":").first }.join(", ")
        parts << "You notice: #{obj_text}"
      end

      # Hazards (if any)
      hazard_list = hazards
      if hazard_list.any?
        hazard_text = hazard_list.map(&:content).join(". ")
        parts << "Dangers: #{hazard_text}"
      end

      parts.compact.join("\n\n")
    end

    # Format as a brief tactical summary
    # @return [String] Tactical summary
    def format_tactical
      parts = []

      parts << "Location: #{@location_name}" if @location_name
      parts << "Mood: #{@atmosphere}" if @atmosphere

      npc_list = npcs
      if npc_list.any?
        npc_summary = npc_list.map do |n|
          "#{n.metadata[:name]} (#{n.metadata[:disposition]})"
        end.join(", ")
        parts << "NPCs: #{npc_summary}"
      end

      hazard_list = hazards
      parts << "Hazards: #{hazard_list.size}" if hazard_list.any?

      exit_list = exits
      if exit_list.any?
        exit_summary = exit_list.map { |e| e.metadata[:direction] }.join(", ")
        parts << "Exits: #{exit_summary}"
      end

      parts.join(" | ")
    end

    # Override format_for_prompt for scene-specific formats
    # @param question [String] The question/context
    # @param format [Symbol] Output format (:immersive, :tactical, :brief, :detailed)
    # @return [String] Formatted context
    def format_for_prompt(question, format: :brief)
      case format
      when :immersive
        format_immersive
      when :tactical
        format_tactical
      else
        super
      end
    end

    # Override to_h to include scene-specific attributes
    def to_h
      super.merge(
        location_name: @location_name,
        atmosphere: @atmosphere
      )
    end

    # Override from_h to restore scene-specific attributes
    def self.from_h(data, context_registry: nil)
      context = new(
        location_name: data[:location_name] || data["location_name"],
        atmosphere: data[:atmosphere] || data["atmosphere"]
      )
      load_entries_from_h(context, data)
      load_sub_contexts_from_h(context, data, context_registry)
      context
    end

    
    # Boost relevance for location and NPC mentions
    def calculate_relevance_score(entry, question_keywords)
      base_score = super

      # Boost for entity names mentioned in question
      if entry.metadata[:name]
        name_words = extract_keywords(entry.metadata[:name])
        name_overlap = (question_keywords & name_words).size
        base_score += name_overlap * 2
      end

      base_score
    end
  end
end

