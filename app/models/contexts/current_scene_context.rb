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
    attr_reader :npcs_list, :hazards_list, :exits_list, :objects_list, :location_entry, :atmosphere_entries

    def initialize(location_name: nil, atmosphere: nil)
      super()
      @location_name = location_name
      @atmosphere = atmosphere
      
      # Dedicated collections for scene entities
      @npcs_list = []
      @hazards_list = []
      @exits_list = []
      @objects_list = []
      @location_entry = nil
      @atmosphere_entries = []
    end

    # Set the current location
    # @param name [String] Location name
    # @param description [String] Location description
    # @param metadata [Hash] Additional metadata (type, region, etc)
    # @return [Entries::SceneEntry]
    def set_location(name:, description:, metadata: {})
      @location_name = name

      entry = Entries::SceneEntry.new(
        entity_type: :location,
        name: name,
        description: description,
        topics: ["#{TOPIC_PREFIXES[:location]}#{name.downcase.gsub(/\s+/, '_')}"],
        source: "location",
        metadata: metadata.merge(is_primary: true)
      )
      
      @location_entry = entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Set the scene atmosphere
    # @param description [String] Atmospheric description (lighting, sounds, smells)
    # @param mood [String] Overall mood (tense, peaceful, eerie, etc)
    # @return [Entries::SceneEntry]
    def set_atmosphere(description:, mood: nil)
      @atmosphere = mood

      entry = Entries::SceneEntry.new(
        entity_type: :atmosphere,
        name: mood || "general",
        description: description,
        topics: ["#{TOPIC_PREFIXES[:atmosphere]}#{mood&.downcase || 'general'}"],
        source: "atmosphere",
        metadata: { mood: mood }
      )
      
      @atmosphere_entries << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add an NPC present in the scene
    # @param name [String] NPC name
    # @param description [String] NPC appearance/behavior
    # @param disposition [String] How they feel toward players (friendly, hostile, neutral)
    # @return [Entries::SceneEntry]
    def add_npc(name:, description:, disposition: "neutral")
      entry = Entries::SceneEntry.new(
        entity_type: :npc,
        name: name,
        description: description,
        topics: ["#{TOPIC_PREFIXES[:npc]}#{name.downcase}"],
        source: "npcs",
        metadata: { disposition: disposition }
      )
      
      @npcs_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add an environmental hazard
    # @param name [String] Hazard name
    # @param description [String] Hazard description
    # @param severity [String] How dangerous (minor, moderate, severe)
    # @return [Entries::SceneEntry]
    def add_hazard(name:, description:, severity: "moderate")
      entry = Entries::SceneEntry.new(
        entity_type: :hazard,
        name: name,
        description: "[HAZARD - #{severity.upcase}] #{description}",
        topics: ["#{TOPIC_PREFIXES[:hazard]}#{name.downcase.gsub(/\s+/, '_')}"],
        source: "hazards",
        metadata: { severity: severity }
      )
      
      @hazards_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add an interactive object in the scene
    # @param name [String] Object name
    # @param description [String] Object description
    # @param interactable [Boolean] Whether players can interact with it
    # @return [Entries::SceneEntry]
    def add_object(name:, description:, interactable: true)
      entry = Entries::SceneEntry.new(
        entity_type: :object,
        name: name,
        description: description,
        topics: ["#{TOPIC_PREFIXES[:object]}#{name.downcase.gsub(/\s+/, '_')}"],
        source: "objects",
        metadata: { interactable: interactable }
      )
      
      @objects_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Add an exit/passage from the scene
    # @param direction [String] Direction or name of exit
    # @param destination [String] Where it leads
    # @param description [String] Exit description
    # @return [Entries::SceneEntry]
    def add_exit(direction:, destination:, description: nil)
      desc = description || "leads to #{destination}"

      entry = Entries::SceneEntry.new(
        entity_type: :exit,
        name: direction,
        description: desc,
        topics: ["#{TOPIC_PREFIXES[:exit]}#{direction.downcase}"],
        source: "exits",
        metadata: { destination: destination }
      )
      
      @exits_list << entry
      @entries << entry
      
      # Index by topics
      entry.topics.each do |topic|
        @topic_index[topic].add(entry.id)
      end
      
      entry
    end

    # Get all NPCs currently in the scene
    # @return [Array<Entries::SceneEntry>] NPC entries
    def npcs
      @npcs_list
    end

    # Get all hazards in the scene
    # @return [Array<Entries::SceneEntry>] Hazard entries
    def hazards
      @hazards_list
    end

    # Get all exits from the scene
    # @return [Array<Entries::SceneEntry>] Exit entries
    def exits
      @exits_list
    end
    
    # Get all objects in the scene
    # @return [Array<Entries::SceneEntry>] Object entries
    def objects
      @objects_list
    end

    # Get the primary location description
    # @return [Entries::SceneEntry, nil] The primary location entry
    def location
      @location_entry
    end

    # Format as an immersive scene description
    # @return [String] Formatted scene description
    def format_immersive
      parts = []

      # Location first
      loc = location
      parts << loc.content if loc

      # Atmosphere
      parts << @atmosphere_entries.last&.content if @atmosphere_entries.any?

      # NPCs present
      npc_list = npcs
      if npc_list.any?
        npc_text = npc_list.map(&:content).join(". ")
        parts << "Present: #{npc_text}"
      end

      # Notable objects
      interactable_objects = @objects_list.select { |o| o.metadata[:interactable] }
      if interactable_objects.any?
        obj_text = interactable_objects.map { |o| o.entity_name }.join(", ")
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
          "#{n.entity_name} (#{n.metadata[:disposition]})"
        end.join(", ")
        parts << "NPCs: #{npc_summary}"
      end

      hazard_list = hazards
      parts << "Hazards: #{hazard_list.size}" if hazard_list.any?

      exit_list = exits
      if exit_list.any?
        exit_summary = exit_list.map { |e| e.entity_name }.join(", ")
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
    def self.from_h(hash)
      raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
      raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }

      context = allocate
      context.instance_variable_set(:@location_name, hash[:location_name])
      context.instance_variable_set(:@atmosphere, hash[:atmosphere])
      context.instance_variable_set(:@entries, [])
      context.instance_variable_set(:@topic_index, Hash.new { |h, k| h[k] = Set.new })
      context.instance_variable_set(:@sub_contexts, {})

      load_entries_from_h(context, hash)
      load_sub_contexts_from_h(context, hash)
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

