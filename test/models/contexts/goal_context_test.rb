# frozen_string_literal: true

require "test_helper"

module Contexts
  class GoalContextTest < ActiveSupport::TestCase
    speed_profile :fast
    test "creates goal context with primary goal" do
      context = GoalContext.new(goal_text: "Complete the project")

      assert_not_nil context.primary_goal
      assert_equal "Complete the project", context.primary_goal.goal_text
      assert context.primary_goal.is_a?(Goals::PrimaryGoal)
    end

    speed_profile :fast
    test "add_sub_goal creates and tracks sub-goal" do
      context = GoalContext.new(goal_text: "Main goal")
      
      sub_goal = context.add_sub_goal("Subtask 1", priority: 1, metadata: { type: "research" })

      assert_instance_of Goals::SubGoal, sub_goal
      assert_equal "Subtask 1", sub_goal.goal_text
      assert_equal 1, sub_goal.priority
      assert_equal 1, context.sub_goals.size
    end

    speed_profile :fast
    test "sub_goals returns sorted sub-goals" do
      context = GoalContext.new(goal_text: "Main")
      
      context.add_sub_goal("Low priority", priority: 3)
      context.add_sub_goal("High priority", priority: 1)
      context.add_sub_goal("Medium priority", priority: 2)

      sorted = context.sub_goals
      assert_equal [1, 2, 3], sorted.map(&:priority)
    end

    speed_profile :fast
    test "mark_progress updates goal status" do
      context = GoalContext.new(goal_text: "Main")
      sub_goal = context.add_sub_goal("Task 1", priority: 1)

      context.mark_progress(sub_goal.id, Goals::BaseGoal::IN_PROGRESS, progress: 50)

      assert_equal :in_progress, sub_goal.status
      assert_equal 50, sub_goal.progress
    end

    speed_profile :fast
    test "mark_progress validates goal exists" do
      context = GoalContext.new(goal_text: "Main")

      error = assert_raises(ArgumentError) do
        context.mark_progress("nonexistent-id", :complete)
      end
      assert_match(/Goal not found/, error.message)
    end

    speed_profile :fast
    test "pending_sub_goals returns not started goals" do
      context = GoalContext.new(goal_text: "Main")
      
      sg1 = context.add_sub_goal("Task 1", priority: 1)
      sg2 = context.add_sub_goal("Task 2", priority: 2)
      sg3 = context.add_sub_goal("Task 3", priority: 3)

      context.mark_progress(sg2.id, Goals::BaseGoal::COMPLETE)

      pending = context.pending_sub_goals
      assert_equal 2, pending.size
      assert_includes pending.map(&:id), sg1.id
      assert_includes pending.map(&:id), sg3.id
    end

    speed_profile :fast
    test "completed_sub_goals returns completed goals" do
      context = GoalContext.new(goal_text: "Main")
      
      sg1 = context.add_sub_goal("Task 1", priority: 1)
      sg2 = context.add_sub_goal("Task 2", priority: 2)
      
      context.mark_progress(sg1.id, Goals::BaseGoal::COMPLETE)

      completed = context.completed_sub_goals
      assert_equal 1, completed.size
      assert_equal sg1.id, completed.first.id
    end

    speed_profile :fast
    test "overall_progress calculates completion percentage" do
      context = GoalContext.new(goal_text: "Main")
      
      sg1 = context.add_sub_goal("Task 1", priority: 1)
      sg2 = context.add_sub_goal("Task 2", priority: 2)
      sg3 = context.add_sub_goal("Task 3", priority: 3)
      sg4 = context.add_sub_goal("Task 4", priority: 4)

      assert_equal 0, context.overall_progress

      context.mark_progress(sg1.id, Goals::BaseGoal::COMPLETE)
      context.mark_progress(sg2.id, Goals::BaseGoal::COMPLETE)

      assert_equal 50.0, context.overall_progress
    end

    speed_profile :fast
    test "goal_achieved? returns true when primary goal is complete" do
      context = GoalContext.new(goal_text: "Main")
      
      assert_not context.goal_achieved?

      context.mark_progress(context.primary_goal.id, Goals::BaseGoal::COMPLETE)

      assert context.goal_achieved?
    end

    speed_profile :fast
    test "format_for_prompt displays goal hierarchy" do
      context = GoalContext.new(goal_text: "Complete project")
      context.add_sub_goal("Design system", priority: 1)
      context.add_sub_goal("Implement features", priority: 2)

      formatted = context.format_for_prompt

      assert formatted.include?("Complete project")
      assert formatted.include?("Design system")
      assert formatted.include?("Implement features")
    end

    speed_profile :fast
    test "to_h serializes goal context" do
      context = GoalContext.new(goal_text: "Main goal")
      context.add_sub_goal("Sub 1", priority: 1)
      context.add_sub_goal("Sub 2", priority: 2)

      hash = context.to_h

      assert_equal "Main goal", hash[:primary_goal][:goal_text]
      assert_equal 2, hash[:primary_goal][:sub_goals].size
      assert hash[:overall_progress].is_a?(Numeric)
    end

    speed_profile :fast
    test "from_h reconstructs goal context" do
      original = GoalContext.new(goal_text: "Original")
      original.add_sub_goal("Sub 1", priority: 1)
      original.add_sub_goal("Sub 2", priority: 2)

      hash = original.to_h
      reconstructed = GoalContext.from_h(hash)

      assert_equal original.primary_goal.goal_text, reconstructed.primary_goal.goal_text
      assert_equal 2, reconstructed.sub_goals.size
    end
  end
end








