# frozen_string_literal: true

module Contexts
  # DnD-specific context that aggregates scene, people, quests, and conversation.
  # Provides DnD-aware relevance filtering and formatting for prompts.
  #
  # Key features:
  # - Aggregates multiple sub-contexts (scene, people, quests, conversation)
  # - DnD-specific topic prefixes for better indexing
  # - Custom formatting for narrative and action detection prompts
  class DndChatContext < BaseContext
    # DnD-specific topic prefixes for better indexing
    TOPIC_PREFIXES = {
      scene: "scene:",
      person: "person:",
      quest: "quest:",
      action: "action:",
      conversation: "conv:",
      item: "item:",
      location: "loc:"
    }.freeze

    # Sub-context names
    SUB_CONTEXT_NAMES = [:scene, :people, :quests, :conversation, :actions].freeze

    def initialize
      super
      # Initialize standard sub-contexts
      @sub_contexts[:scene] = CurrentSceneContext.new
      @sub_contexts[:people] = BaseContext.new
      @sub_contexts[:quests] = BaseContext.new
      @sub_contexts[:conversation] = BaseContext.new
      @sub_contexts[:actions] = BaseContext.new
    end

    # Convenience accessor for scene sub-context
    # @return [CurrentSceneContext]
    def scene
      @sub_contexts[:scene]
    end

    # Convenience accessor for people sub-context
    # @return [BaseContext]
    def people
      @sub_contexts[:people]
    end

    # Convenience accessor for quests sub-context
    # @return [BaseContext]
    def quests
      @sub_contexts[:quests]
    end

    # Convenience accessor for conversation sub-context
    # @return [BaseContext]
    def conversation
      @sub_contexts[:conversation]
    end

    # Convenience accessor for actions sub-context
    # @return [BaseContext]
    def actions
      @sub_contexts[:actions]
    end

    # Add a person to the people context
    # @param name [String] The person's name
    # @param description [String] Description of the person
    # @param metadata [Hash] Additional metadata (role, disposition, etc)
    # @return [Entry]
    def add_person(name:, description:, metadata: {})
      people.add(
        content: "#{name}: #{description}",
        topics: ["#{TOPIC_PREFIXES[:person]}#{name.downcase}"],
        source: "people",
        metadata: metadata.merge(entity_type: :person, name: name)
      )
    end

    # Add a quest to the quests context
    # @param title [String] The quest title
    # @param description [String] Quest description
    # @param status [String] Quest status (active, completed, failed)
    # @param metadata [Hash] Additional metadata
    # @return [Entry]
    def add_quest(title:, description:, status: "active", metadata: {})
      quests.add(
        content: "[#{status.upcase}] #{title}: #{description}",
        topics: ["#{TOPIC_PREFIXES[:quest]}#{title.downcase.gsub(/\s+/, '_')}"],
        source: "quests",
        metadata: metadata.merge(entity_type: :quest, title: title, status: status)
      )
    end

    # Add a conversation message
    # @param speaker [String] Who said it (player, dm, npc name)
    # @param message [String] The message content
    # @param metadata [Hash] Additional metadata
    # @return [Entry]
    def add_message(speaker:, message:, metadata: {})
      conversation.add(
        content: "#{speaker}: #{message}",
        topics: ["#{TOPIC_PREFIXES[:conversation]}#{speaker.downcase}"],
        source: "conversation",
        metadata: metadata.merge(entity_type: :message, speaker: speaker)
      )
    end

    # Add a completed action
    # @param action_name [String] Name of the action
    # @param result [String] Result of the action
    # @param metadata [Hash] Additional metadata (tool_name, success, etc)
    # @return [Entry]
    def add_action(action_name:, result:, metadata: {})
      actions.add(
        content: "#{action_name}: #{result}",
        topics: ["#{TOPIC_PREFIXES[:action]}#{action_name.downcase}"],
        source: "actions",
        metadata: metadata.merge(entity_type: :action, action_name: action_name)
      )
    end

    # Format context for action detection prompts
    # Emphasizes scene, available actions, and recent conversation
    # @return [String] Formatted context
    def format_for_action_detection
      parts = []

      # Current scene is most important for action detection
      scene_summary = scene.compressed_summary
      parts << "Current scene:\n#{scene_summary}" unless scene_summary.empty?

      # Recent conversation for context
      recent_conv = conversation.entries.last(5)
      unless recent_conv.empty?
        conv_text = recent_conv.map(&:content).join("\n")
        parts << "Recent conversation:\n#{conv_text}"
      end

      # Active quests may inform actions
      active_quests = quests.entries.select { |e| e.metadata[:status] == "active" }
      unless active_quests.empty?
        quest_text = active_quests.map(&:content).join("\n")
        parts << "Active quests:\n#{quest_text}"
      end

      parts.join("\n\n")
    end

    # Format context for narrative prompts
    # Emphasizes completed actions, scene, and story continuity
    # Uses actions from the context's actions sub-context
    # @return [String] Formatted context
    def format_for_narrative
      parts = []

      # Completed actions are the focus of narrative - get from actions sub-context
      action_entries = actions.entries
      unless action_entries.empty?
        actions_text = action_entries.map do |entry|
          action_name = entry.metadata[:action_name] || "action"
          "- #{action_name}: #{entry.content}"
        end.join("\n")
        parts << "Completed actions:\n#{actions_text}"
      end

      # Scene provides setting
      scene_summary = scene.compressed_summary
      parts << "Scene:\n#{scene_summary}" unless scene_summary.empty?

      # People in scene
      people_in_scene = people.entries.last(3)
      unless people_in_scene.empty?
        people_text = people_in_scene.map(&:content).join("\n")
        parts << "People present:\n#{people_text}"
      end

      # Current quest for story context
      current_quest = quests.entries.find { |e| e.metadata[:status] == "active" }
      parts << "Current quest:\n#{current_quest.content}" if current_quest

      parts.join("\n\n")
    end

    # Format context for outcome/consequence prompts
    # Focuses on the most recent action and scene for determining consequences
    # @return [String] Formatted context
    def format_for_outcome
      parts = []

      # Most recent action is the focus
      recent_action = actions.entries.last
      if recent_action
        parts << "Action: #{recent_action.content}"
        if recent_action.metadata[:tool_result]
          parts << "Tool result:\n#{JSON.pretty_generate(recent_action.metadata[:tool_result])}"
        end
      end

      # Scene context for determining consequences
      scene_summary = scene.format_for_prompt("", format: :tactical)
      parts << "Scene: #{scene_summary}" unless scene_summary.blank?

      parts.join("\n\n")
    end

    # Override format_for_prompt to provide DnD-specific formatting
    # Default format includes all relevant context from sub-contexts
    # @param question [String] The question/context for relevance
    # @param format [Symbol] Output format (:action_detection, :narrative, :outcome, :brief, :detailed)
    # @return [String] Formatted context
    def format_for_prompt(question, format: :brief)
      case format
      when :action_detection
        format_for_action_detection
      when :narrative
        format_for_narrative
      when :outcome
        format_for_outcome
      else
        # Default: comprehensive format including all sub-contexts
        format_comprehensive
      end
    end

    # Comprehensive format including all relevant sub-context data
    # @return [String] Formatted context
    def format_comprehensive
      parts = []

      # Scene
      scene_summary = scene.compressed_summary
      parts << "Scene:\n#{scene_summary}" unless scene_summary.empty?

      # Actions
      action_entries = actions.entries
      unless action_entries.empty?
        actions_text = action_entries.map do |entry|
          "- #{entry.metadata[:action_name] || 'action'}: #{entry.content}"
        end.join("\n")
        parts << "Actions:\n#{actions_text}"
      end

      # People
      people_entries = people.entries.last(5)
      unless people_entries.empty?
        parts << "People:\n#{people_entries.map(&:content).join("\n")}"
      end

      # Quests
      active_quests = quests.entries.select { |e| e.metadata[:status] == "active" }
      unless active_quests.empty?
        parts << "Quests:\n#{active_quests.map(&:content).join("\n")}"
      end

      # Conversation
      recent = conversation.entries.last(5)
      unless recent.empty?
        parts << "Conversation:\n#{recent.map(&:content).join("\n")}"
      end

      parts.join("\n\n")
    end

    
    # Override to boost relevance for DnD-specific keywords
    def calculate_relevance_score(entry, question_keywords)
      base_score = super

      # Boost for DnD-specific terms
      dnd_boost_words = %w[attack cast spell roll dice check save throw damage heal]
      dnd_overlap = (question_keywords & dnd_boost_words).size

      base_score + dnd_overlap
    end

    # Override to include sub-context entries in candidates
    def candidates_for_relevance
      all_candidates = super

      # Include recent entries from each sub-context
      @sub_contexts.each_value do |sub_ctx|
        all_candidates.concat(sub_ctx.entries.last(5))
      end

      all_candidates.last(MAX_CANDIDATE_ENTRIES)
    end
  end
end

