# frozen_string_literal: true

require "test_helper"

module Contexts
  module Goals
    class SubGoalTest < ActiveSupport::TestCase
      setup do
        @parent = PrimaryGoal.new(goal_text: "Parent goal", entry_id: "entry-1")
      end

      test "creates a valid sub-goal" do
        sub_goal = SubGoal.new(
          goal_text: "Sub task",
          entry_id: "entry-2",
          parent: @parent,
          priority: 2,
          metadata: { type: "implementation" }
        )

        assert_equal "Sub task", sub_goal.goal_text
        assert_equal "entry-2", sub_goal.entries.first
        assert_equal @parent, sub_goal.parent
        assert_equal 2, sub_goal.priority
        assert_equal({ type: "implementation" }, sub_goal.metadata)
      end

      test "validates parent is a PrimaryGoal" do
        error = assert_raises(TypeError) do
          SubGoal.new(
            goal_text: "Test",
            entry_id: "entry-1",
            parent: "not a goal",
            priority: 1
          )
        end
        assert_match(/parent must be a PrimaryGoal/, error.message)
      end

      test "validates priority is an Integer" do
        error = assert_raises(ArgumentError) do
          SubGoal.new(
            goal_text: "Test",
            entry_id: "entry-1",
            parent: @parent,
            priority: "high"
          )
        end
        assert_match(/priority must be an Integer/, error.message)
      end

      test "validates priority is in valid range" do
        error = assert_raises(ArgumentError) do
          SubGoal.new(
            goal_text: "Test",
            entry_id: "entry-1",
            parent: @parent,
            priority: 5
          )
        end
        assert_match(/priority must be between 1 and 4/, error.message)
      end

      test "allows all valid priority values" do
        [1, 2, 3, 4].each do |priority|
          sub_goal = SubGoal.new(
            goal_text: "Test #{priority}",
            entry_id: "entry-#{priority}",
            parent: @parent,
            priority: priority
          )
          assert_equal priority, sub_goal.priority
        end
      end

      test "to_h includes priority and parent_id" do
        sub_goal = SubGoal.new(
          goal_text: "Test",
          entry_id: "entry-1",
          parent: @parent,
          priority: 3
        )

        hash = sub_goal.to_h

        assert_equal "Test", hash[:goal_text]
        assert_equal 3, hash[:priority]
        assert_equal @parent.id, hash[:parent_id]
      end

      test "from_h reconstructs sub-goal with parent" do
        sub_goal = SubGoal.new(
          goal_text: "Original",
          entry_id: "entry-1",
          parent: @parent,
          priority: 2
        )

        hash = sub_goal.to_h
        reconstructed = SubGoal.from_h(hash, parent: @parent)

        assert_equal sub_goal.id, reconstructed.id
        assert_equal sub_goal.goal_text, reconstructed.goal_text
        assert_equal sub_goal.priority, reconstructed.priority
        assert_equal @parent, reconstructed.parent
      end

      test "from_h validates parent parameter" do
        hash = {
          id: "123",
          goal_text: "Test",
          status: :not_started,
          entries: ["e1"],
          priority: 1,
          parent_id: "parent-123",
          created_at: Time.now.utc.iso8601,
          updated_at: Time.now.utc.iso8601,
          metadata: {}
        }

        error = assert_raises(TypeError) do
          SubGoal.from_h(hash, parent: "not a goal")
        end
        assert_match(/parent must be a PrimaryGoal/, error.message)
      end

      test "from_h validates required keys" do
        error = assert_raises(ArgumentError) do
          SubGoal.from_h({ id: "123" }, parent: @parent)
        end
        assert_match(/Missing required keys/, error.message)
      end
    end
  end
end

