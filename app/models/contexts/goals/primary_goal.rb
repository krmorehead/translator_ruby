module Contexts
  module Goals
    class PrimaryGoal < BaseGoal
      attr_reader :sub_goals, :sub_goal_map

      def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
        super(goal_text: goal_text, entry_id: entry_id, status: status, metadata: metadata)
        @sub_goals = []
        @sub_goal_map = {}
      end

      def add_sub_goal(goal_text:, entry_id:, priority: 2, metadata: {})
        raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)

        sub_goal = SubGoal.new(
          goal_text: goal_text,
          priority: priority,
          status: Goals::BaseGoal::NOT_STARTED,
          entry_id: entry_id,
          parent: self,
          metadata: metadata
        )
        @sub_goals << sub_goal
        @sub_goal_map[sub_goal.id] = sub_goal
        sub_goal
      end

      def sub_goal_progress
        return 0 if @sub_goals.empty?
        
        total_sub_goals = @sub_goals.size
        completed_sub_goals = @sub_goals.select(&:completed?).size
        (completed_sub_goals / total_sub_goals.to_f * 100).round(2)
      end

      def sub_goals_sorted
        @sub_goals.sort_by(&:priority)
      end

      def find_goal(id)
        raise ArgumentError, "id must be a String" unless id.is_a?(String)
        return self if id == @id
        find_sub_goal(id)
      end

      def find_sub_goal(id)
        raise ArgumentError, "id must be a String" unless id.is_a?(String)
        @sub_goal_map[id]
      end

      def to_h
        {
          **super,
          sub_goals: @sub_goals.map(&:to_h)
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required key :sub_goals" unless hash.key?(:sub_goals)
        raise TypeError, "sub_goals must be an Array" unless hash[:sub_goals].is_a?(Array)

        # First reconstruct the base goal
        primary_goal = allocate
        primary_goal.instance_variable_set(:@id, hash[:id])
        primary_goal.instance_variable_set(:@goal_text, hash[:goal_text])
        primary_goal.instance_variable_set(:@status, hash[:status])
        primary_goal.instance_variable_set(:@entries, hash[:entries])
        primary_goal.instance_variable_set(:@progress, hash[:progress] || 0)
        primary_goal.instance_variable_set(:@created_at, hash[:created_at])
        primary_goal.instance_variable_set(:@updated_at, hash[:updated_at])
        primary_goal.instance_variable_set(:@metadata, hash[:metadata] || {})

        # Then reconstruct sub-goals
        sub_goals = hash[:sub_goals].map { |sg_hash| SubGoal.from_h(sg_hash, parent: primary_goal) }
        sub_goal_map = sub_goals.each_with_object({}) { |sg, map| map[sg.id] = sg }
        
        primary_goal.instance_variable_set(:@sub_goals, sub_goals)
        primary_goal.instance_variable_set(:@sub_goal_map, sub_goal_map)
        
        primary_goal
      end
    end
  end
end
