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

    def initialize(goal_text:)
      super()
      set_primary_goal(goal_text)
    end

    # Set the primary goal
    # @param goal_text [String] The goal description
    # @param metadata [Hash] Additional metadata
    def set_primary_goal(goal_text, metadata: {})
      raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)

      entry = add(
        content: "Primary Goal: #{goal_text}",
        topics: ["goal", "primary_goal"],
        source: "goal_context",
        metadata: { goal_text: goal_text }
      )

      @primary_goal = Goals::PrimaryGoal.new(
        goal_text: goal_text,
        entry_id: entry.id,
        metadata: metadata
      )
      @primary_goal
    end

    # Add a sub-goal
    # @param goal_text [String] The sub-goal description
    # @param priority [Integer] Priority (1 = highest)
    # @param metadata [Hash] Additional metadata
    # @return [Goals::SubGoal] The created sub-goal
    def add_sub_goal(goal_text, priority: 2, metadata: {})
      raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
      raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)
      raise TypeError, "Primary goal must be set first" unless @primary_goal

      entry = add(
        content: "Sub-goal (priority #{priority}): #{goal_text}",
        topics: ["goal", "sub_goal"],
        source: "goal_context",
        metadata: { parent_id: @primary_goal.id, priority: priority }
      )
      
      sub_goal = @primary_goal.add_sub_goal(
        goal_text: goal_text,
        entry_id: entry.id,
        priority: priority,
        metadata: metadata
      )
      
      # Update entry with sub_goal id now that we have it
      entry.metadata[:goal_id] = sub_goal.id
      
      sub_goal
    end

    def sub_goals
      raise TypeError, "Primary goal must be set first" unless @primary_goal
      @primary_goal.sub_goals_sorted
    end

    # Mark progress on a goal
    # @param goal_id [String] The goal ID
    # @param status [Symbol] New status (:not_started, :in_progress, :complete, :failed)
    # @param progress [Integer] Progress percentage (0-100)
    def mark_progress(goal_id, status, progress: nil)
      raise ArgumentError, "goal_id must be a String" unless goal_id.is_a?(String)
      raise TypeError, "Primary goal must be set first" unless @primary_goal
      
      goal = @primary_goal.find_goal(goal_id)
      raise ArgumentError, "Goal not found: #{goal_id}" unless goal

      entry = add(
        content: "Goal '#{goal.goal_text.truncate(50)}' marked as #{status}",
        topics: ["goal", "progress", status.to_s],
        source: "goal_context",
        metadata: { goal_id: goal_id, status: status, progress: progress }
      )

      goal.update_status(status: status, entry_id: entry.id, progress: progress)
    end

    # Get pending sub-goals sorted by priority
    # @return [Array<Goals::SubGoal>] Pending sub-goals
    def pending_sub_goals
      raise TypeError, "Primary goal must be set first" unless @primary_goal
      @primary_goal.sub_goals_sorted.select { |g| g.status == :not_started || g.status == :pending }
    end

    # Get completed sub-goals
    # @return [Array<Goals::SubGoal>] Completed sub-goals
    def completed_sub_goals
      raise TypeError, "Primary goal must be set first" unless @primary_goal
      @primary_goal.sub_goals_sorted.select { |g| g.status == :complete }
    end

    # Calculate overall progress based on sub-goals
    # @return [Integer] Progress percentage (0-100)
    def overall_progress
      @primary_goal.sub_goal_progress
    end

    # Check if the primary goal is achieved
    # @return [Boolean]
    def goal_achieved?
      @primary_goal.completed?
    end

    # Format for prompt output
    # @param question [String] Optional question for relevance filtering
    # @return [String] Formatted goal context
    def format_for_prompt(question = nil)
      parts = []

      if @primary_goal
        status = @primary_goal.status.to_s.tr("_", " ")
        parts << "## Primary Goal (#{status})"
        parts << @primary_goal.goal_text
        parts << ""
      end

      sorted_sub_goals = sub_goals
      if sorted_sub_goals.any?
        parts << "## Sub-goals"
        sorted_sub_goals.each do |sg|
          status_icon = case sg.status
                        when :complete then "[x]"
                        when :in_progress then "[~]"
                        when :failed then "[!]"
                        else "[ ]"
                        end
          parts << "#{status_icon} (P#{sg.priority}) #{sg.goal_text}"
        end
        parts << ""
        parts << "Progress: #{overall_progress}%"
      end

      parts.join("\n")
    end

    # Serialize to hash
    # @return [Hash]
    def to_h
      raise TypeError, "Primary goal must be set first" unless @primary_goal
      
      super.merge(
        primary_goal: @primary_goal.to_h,
        overall_progress: overall_progress
      )
    end

    # Deserialize from hash
    # @param hash [Hash] Serialized data
    # @return [GoalContext]
    def self.from_h(hash)
      raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
      raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
      raise ArgumentError, "Missing required key :primary_goal" unless hash.key?(:primary_goal)
      raise TypeError, "primary_goal must be a Hash" unless hash[:primary_goal].is_a?(Hash)

      # Reconstruct primary goal object
      primary_goal = Goals::PrimaryGoal.from_h(hash[:primary_goal])
      
      # Create context with the goal_text from the primary goal
      context = allocate
      context.instance_variable_set(:@primary_goal, primary_goal)
      context.instance_variable_set(:@entries, [])
      context.instance_variable_set(:@topic_index, Hash.new { |h, k| h[k] = Set.new })
      context.instance_variable_set(:@sub_contexts, {})

      # Restore entries as Entry objects
      load_entries_from_h(context, hash)
      load_sub_contexts_from_h(context, hash)

      context
    end
  end
end

