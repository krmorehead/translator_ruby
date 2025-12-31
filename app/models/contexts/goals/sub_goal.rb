module Contexts
  module Goals
    class SubGoal < BaseGoal
      PRIORITIES = [1, 2, 3, 4].freeze

      attr_reader :priority, :parent

      def initialize(goal_text:, entry_id:, parent:, priority:, status: NOT_STARTED, metadata: {})
        raise TypeError, "parent must be a PrimaryGoal" unless parent.is_a?(PrimaryGoal)
        raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)
        raise ArgumentError, "priority must be between 1 and 4" unless PRIORITIES.include?(priority)

        super(goal_text: goal_text, entry_id: entry_id, status: status, metadata: metadata)
        @priority = priority
        @parent = parent
      end

      def to_h
        {
          **super,
          priority: @priority,
          parent_id: @parent.id
        }
      end

      def self.from_h(hash, parent:)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise TypeError, "parent must be a PrimaryGoal" unless parent.is_a?(PrimaryGoal)
        raise ArgumentError, "Missing required keys" unless 
          hash.key?(:priority) && hash.key?(:parent_id)

        sub_goal = allocate
        sub_goal.instance_variable_set(:@id, hash[:id])
        sub_goal.instance_variable_set(:@goal_text, hash[:goal_text])
        sub_goal.instance_variable_set(:@status, hash[:status])
        sub_goal.instance_variable_set(:@entries, hash[:entries])
        sub_goal.instance_variable_set(:@progress, hash[:progress] || 0)
        sub_goal.instance_variable_set(:@created_at, hash[:created_at])
        sub_goal.instance_variable_set(:@updated_at, hash[:updated_at])
        sub_goal.instance_variable_set(:@metadata, hash[:metadata] || {})
        sub_goal.instance_variable_set(:@priority, hash[:priority])
        sub_goal.instance_variable_set(:@parent, parent)
        sub_goal
      end
    end
  end
end
