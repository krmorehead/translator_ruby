# frozen_string_literal: true

require "test_helper"

module Contexts
  module Goals
    class PrimaryGoalTest < ActiveSupport::TestCase
      test "creates a valid primary goal" do
        goal = PrimaryGoal.new(
          goal_text: "Main objective",
          entry_id: "entry-1",
          metadata: { importance: "high" }
        )

        assert_equal "Main objective", goal.goal_text
        assert_equal "entry-1", goal.entries.first
        assert_empty goal.sub_goals
        assert_empty goal.sub_goal_map
      end

      test "add_sub_goal creates and tracks sub-goal" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        
        sub_goal = primary.add_sub_goal(
          goal_text: "Sub task",
          entry_id: "entry-2",
          priority: 1,
          metadata: { type: "research" }
        )

        assert_instance_of SubGoal, sub_goal
        assert_equal "Sub task", sub_goal.goal_text
        assert_equal 1, sub_goal.priority
        assert_equal primary, sub_goal.parent
        assert_equal 1, primary.sub_goals.size
        assert_equal sub_goal, primary.sub_goal_map[sub_goal.id]
      end

      test "add_sub_goal validates parameters" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")

        error = assert_raises(ArgumentError) do
          primary.add_sub_goal(goal_text: 123, entry_id: "entry-2")
        end
        assert_match(/goal_text must be a String/, error.message)

        error = assert_raises(ArgumentError) do
          primary.add_sub_goal(goal_text: "Test", entry_id: "entry-2", priority: "high")
        end
        assert_match(/priority must be an Integer/, error.message)
      end

      test "sub_goal_progress calculates completion percentage" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        
        # Add 4 sub-goals
        sg1 = primary.add_sub_goal(goal_text: "Task 1", entry_id: "e1", priority: 1)
        sg2 = primary.add_sub_goal(goal_text: "Task 2", entry_id: "e2", priority: 2)
        sg3 = primary.add_sub_goal(goal_text: "Task 3", entry_id: "e3", priority: 3)
        sg4 = primary.add_sub_goal(goal_text: "Task 4", entry_id: "e4", priority: 4)

        # Initially 0%
        assert_equal 0, primary.sub_goal_progress

        # Complete 2 out of 4 = 50%
        sg1.update_status(status: BaseGoal::COMPLETE, entry_id: "e5")
        sg2.update_status(status: BaseGoal::COMPLETE, entry_id: "e6")

        assert_equal 50.0, primary.sub_goal_progress
      end

      test "sub_goal_progress returns 0 when no sub-goals" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        assert_equal 0, primary.sub_goal_progress
      end

      test "sub_goals_sorted returns sub-goals sorted by priority" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        
        sg1 = primary.add_sub_goal(goal_text: "Low priority", entry_id: "e1", priority: 3)
        sg2 = primary.add_sub_goal(goal_text: "High priority", entry_id: "e2", priority: 1)
        sg3 = primary.add_sub_goal(goal_text: "Medium priority", entry_id: "e3", priority: 2)

        sorted = primary.sub_goals_sorted
        assert_equal [1, 2, 3], sorted.map(&:priority)
        assert_equal ["High priority", "Medium priority", "Low priority"], sorted.map(&:goal_text)
      end

      test "find_goal returns self when matching id" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        assert_equal primary, primary.find_goal(primary.id)
      end

      test "find_goal returns sub-goal when matching sub-goal id" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        sub_goal = primary.add_sub_goal(goal_text: "Sub", entry_id: "e1", priority: 1)

        found = primary.find_goal(sub_goal.id)
        assert_equal sub_goal, found
      end

      test "find_goal returns nil for unknown id" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        assert_nil primary.find_goal("unknown-id")
      end

      test "to_h includes sub-goals" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        sub1 = primary.add_sub_goal(goal_text: "Sub 1", entry_id: "e1", priority: 1)
        sub2 = primary.add_sub_goal(goal_text: "Sub 2", entry_id: "e2", priority: 2)

        hash = primary.to_h

        assert_equal "Main", hash[:goal_text]
        assert_equal 2, hash[:sub_goals].size
        assert_equal "Sub 1", hash[:sub_goals][0][:goal_text]
        assert_equal "Sub 2", hash[:sub_goals][1][:goal_text]
      end

      test "from_h reconstructs primary goal with sub-goals" do
        primary = PrimaryGoal.new(goal_text: "Main", entry_id: "entry-1")
        sub1 = primary.add_sub_goal(goal_text: "Sub 1", entry_id: "e1", priority: 1)
        sub2 = primary.add_sub_goal(goal_text: "Sub 2", entry_id: "e2", priority: 2)

        hash = primary.to_h
        reconstructed = PrimaryGoal.from_h(hash)

        assert_equal primary.id, reconstructed.id
        assert_equal primary.goal_text, reconstructed.goal_text
        assert_equal 2, reconstructed.sub_goals.size
        assert_equal sub1.id, reconstructed.sub_goals[0].id
        assert_equal sub2.id, reconstructed.sub_goals[1].id
        assert_equal reconstructed, reconstructed.sub_goals[0].parent
      end

      test "from_h validates required keys" do
        error = assert_raises(ArgumentError) do
          PrimaryGoal.from_h({ id: "123" })
        end
        assert_match(/Missing required key/, error.message)
      end
    end
  end
end

