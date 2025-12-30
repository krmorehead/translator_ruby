# frozen_string_literal: true

module Contexts
  # Context for managing goals and sub-goals.
  # Reusable across D&D quests, agent research goals, and any goal-oriented workflow.
  #
  # Goals have:
  # - text: The goal description
  # - priority: Importance level (1 = highest)
  # - status: pending, in_progress, completed, failed
  # - sub_goals: Nested goals that contribute to this goal
  #
  # @example Agent research goal
  #   context = GoalContext.new
  #   context.set_primary_goal("How does authentication work?")
  #   context.add_sub_goal("Where is the auth module defined?")
  #   context.add_sub_goal("What are the auth methods?")
  #   context.mark_progress(context.sub_goals.first[:id], :completed)
  #
  # @example D&D quest
  #   context = GoalContext.new
  #   context.set_primary_goal("Defeat the dragon")
  #   context.add_sub_goal("Find the dragon's lair", priority: 1)
  #   context.add_sub_goal("Gather fire resistance potions", priority: 2)
  #
  class GoalContext < BaseContext
    VALID_STATUSES = %i[pending in_progress completed failed].freeze

    attr_reader :primary_goal, :sub_goals

    def initialize(goal_text: nil)
      super()
      @primary_goal = nil
      @sub_goals = []

      set_primary_goal(goal_text) if goal_text
    end

    # Set the primary goal
    # @param text [String] The goal description
    # @param metadata [Hash] Additional metadata
    def set_primary_goal(text, metadata: {})
      @primary_goal = {
        id: SecureRandom.uuid,
        text: text,
        status: :in_progress,
        progress: 0,
        created_at: Time.now.utc.iso8601,
        metadata: metadata
      }

      add(
        content: "Primary Goal: #{text}",
        topics: ["goal", "primary_goal"],
        source: "goal_context",
        metadata: { goal_id: @primary_goal[:id] }
      )

      @primary_goal
    end

    # Add a sub-goal
    # @param text [String] The sub-goal description
    # @param priority [Integer] Priority (1 = highest)
    # @param parent_id [String] Parent goal ID (defaults to primary goal)
    # @param metadata [Hash] Additional metadata
    # @return [Hash] The created sub-goal
    def add_sub_goal(text, priority: 1, parent_id: nil, metadata: {})
      parent = parent_id || @primary_goal&.dig(:id)

      sub_goal = {
        id: SecureRandom.uuid,
        text: text,
        priority: priority,
        status: :pending,
        parent_id: parent,
        created_at: Time.now.utc.iso8601,
        metadata: metadata
      }

      @sub_goals << sub_goal
      @sub_goals.sort_by! { |g| g[:priority] }

      add(
        content: "Sub-goal (priority #{priority}): #{text}",
        topics: ["goal", "sub_goal"],
        source: "goal_context",
        metadata: { goal_id: sub_goal[:id], parent_id: parent }
      )

      sub_goal
    end

    # Mark progress on a goal
    # @param goal_id [String] The goal ID
    # @param status [Symbol] New status (:pending, :in_progress, :completed, :failed)
    # @param progress [Integer] Progress percentage (0-100)
    def mark_progress(goal_id, status, progress: nil)
      raise ArgumentError, "Invalid status: #{status}" unless VALID_STATUSES.include?(status)

      goal = find_goal(goal_id)
      raise ArgumentError, "Goal not found: #{goal_id}" unless goal

      goal[:status] = status
      goal[:progress] = progress if progress
      goal[:updated_at] = Time.now.utc.iso8601

      add(
        content: "Goal '#{goal[:text].truncate(50)}' marked as #{status}",
        topics: ["goal", "progress", status.to_s],
        source: "goal_context",
        metadata: { goal_id: goal_id, status: status, progress: progress }
      )
    end

    # Get pending sub-goals sorted by priority
    # @return [Array<Hash>] Pending sub-goals
    def pending_sub_goals
      @sub_goals.select { |g| g[:status] == :pending }
    end

    # Get completed sub-goals
    # @return [Array<Hash>] Completed sub-goals
    def completed_sub_goals
      @sub_goals.select { |g| g[:status] == :completed }
    end

    # Calculate overall progress based on sub-goals
    # @return [Integer] Progress percentage (0-100)
    def overall_progress
      return 0 if @sub_goals.empty?

      completed = @sub_goals.count { |g| g[:status] == :completed }
      ((completed.to_f / @sub_goals.size) * 100).round
    end

    # Check if the primary goal is achieved
    # @return [Boolean]
    def goal_achieved?
      return false unless @primary_goal

      @primary_goal[:status] == :completed ||
        (@sub_goals.any? && @sub_goals.all? { |g| g[:status] == :completed })
    end

    # Format for prompt output
    # @param question [String] Optional question for relevance filtering
    # @return [String] Formatted goal context
    def format_for_prompt(question = nil)
      parts = []

      if @primary_goal
        status = @primary_goal[:status].to_s.tr("_", " ")
        parts << "## Primary Goal (#{status})"
        parts << @primary_goal[:text]
        parts << ""
      end

      if @sub_goals.any?
        parts << "## Sub-goals"
        @sub_goals.each do |sg|
          status_icon = case sg[:status]
                        when :completed then "[x]"
                        when :in_progress then "[~]"
                        when :failed then "[!]"
                        else "[ ]"
                        end
          parts << "#{status_icon} (P#{sg[:priority]}) #{sg[:text]}"
        end
        parts << ""
        parts << "Progress: #{overall_progress}%"
      end

      parts.join("\n")
    end

    # Serialize to hash
    # @return [Hash]
    def to_h
      super.merge(
        primary_goal: @primary_goal,
        sub_goals: @sub_goals,
        overall_progress: overall_progress
      )
    end

    # Deserialize from hash
    # @param hash [Hash] Serialized data
    # @return [GoalContext]
    def self.from_h(hash)
      context = new
      context.instance_variable_set(:@primary_goal, hash[:primary_goal] || hash["primary_goal"])
      context.instance_variable_set(:@sub_goals, hash[:sub_goals] || hash["sub_goals"] || [])

      # Restore entries
      entries_data = hash[:entries] || hash["entries"] || []
      entries_data.each do |entry_data|
        context.add(
          content: entry_data[:content] || entry_data["content"],
          topics: entry_data[:topics] || entry_data["topics"] || [],
          source: entry_data[:source] || entry_data["source"],
          metadata: entry_data[:metadata] || entry_data["metadata"] || {}
        )
      end

      context
    end

    
    def find_goal(goal_id)
      return @primary_goal if @primary_goal && @primary_goal[:id] == goal_id

      @sub_goals.find { |g| g[:id] == goal_id }
    end
  end
end

