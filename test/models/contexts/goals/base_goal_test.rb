# frozen_string_literal: true

require "test_helper"

module Contexts
  module Goals
    class BaseGoalTest < ActiveSupport::TestCase
      speed_profile :fast
      test "creates a valid base goal" do
        goal = BaseGoal.new(
          goal_text: "Complete the quest",
          entry_id: "entry-123",
          status: BaseGoal::NOT_STARTED,
          metadata: { priority: 1 }
        )

        assert_equal "Complete the quest", goal.goal_text
        assert_equal "entry-123", goal.entries.first
        assert_equal :not_started, goal.status
        assert_equal 0, goal.progress
        assert_equal({ priority: 1 }, goal.metadata)
        assert_not_nil goal.id
        assert_not_nil goal.created_at
        assert_not_nil goal.updated_at
      end

      speed_profile :fast
      test "validates goal_text is a String" do
        error = assert_raises(ArgumentError) do
          BaseGoal.new(goal_text: 123, entry_id: "entry-123")
        end
        assert_match(/goal_text must be a String/, error.message)
      end

      speed_profile :fast
      test "validates entry_id is a String" do
        error = assert_raises(ArgumentError) do
          BaseGoal.new(goal_text: "Test", entry_id: 123)
        end
        assert_match(/entry_id must be a String/, error.message)
      end

      speed_profile :fast
      test "validates status is valid" do
        error = assert_raises(ArgumentError) do
          BaseGoal.new(goal_text: "Test", entry_id: "entry-123", status: :invalid)
        end
        assert_match(/Invalid status/, error.message)
      end

      speed_profile :fast
      test "update_status changes status and adds entry" do
        goal = BaseGoal.new(goal_text: "Test", entry_id: "entry-1")
        
        goal.update_status(status: BaseGoal::IN_PROGRESS, entry_id: "entry-2", progress: 50)

        assert_equal :in_progress, goal.status
        assert_equal 50, goal.progress
        assert_equal 2, goal.entries.size
        assert_includes goal.entries, "entry-2"
      end

      speed_profile :fast
      test "completed? returns true when status is complete" do
        goal = BaseGoal.new(goal_text: "Test", entry_id: "entry-1", status: BaseGoal::COMPLETE)
        assert goal.completed?

        goal2 = BaseGoal.new(goal_text: "Test", entry_id: "entry-1", status: BaseGoal::IN_PROGRESS)
        assert_not goal2.completed?
      end

      speed_profile :fast
      test "to_h serializes goal properly" do
        goal = BaseGoal.new(
          goal_text: "Test goal",
          entry_id: "entry-123",
          status: BaseGoal::IN_PROGRESS,
          metadata: { key: "value" }
        )

        hash = goal.to_h

        assert_equal goal.id, hash[:id]
        assert_equal "Test goal", hash[:goal_text]
        assert_equal :in_progress, hash[:status]
        assert_equal 0, hash[:progress]
        assert_equal ["entry-123"], hash[:entries]
        assert_equal({ key: "value" }, hash[:metadata])
        assert_not_nil hash[:created_at]
        assert_not_nil hash[:updated_at]
      end

      speed_profile :fast
      test "from_h reconstructs goal from hash" do
        original = BaseGoal.new(
          goal_text: "Test goal",
          entry_id: "entry-123",
          metadata: { test: true }
        )
        original.update_status(status: BaseGoal::IN_PROGRESS, entry_id: "entry-456", progress: 75)

        hash = original.to_h
        reconstructed = BaseGoal.from_h(hash)

        assert_equal original.id, reconstructed.id
        assert_equal original.goal_text, reconstructed.goal_text
        assert_equal original.status, reconstructed.status
        assert_equal original.progress, reconstructed.progress
        assert_equal original.entries, reconstructed.entries
        assert_equal original.metadata, reconstructed.metadata
      end

      speed_profile :fast
      test "from_h validates hash structure" do
        error = assert_raises(TypeError) do
          BaseGoal.from_h("not a hash")
        end
        assert_match(/Expected Hash/, error.message)

        error = assert_raises(ArgumentError) do
          BaseGoal.from_h({ "id" => "123" })
        end
        assert_match(/Hash keys must be symbols/, error.message)

        error = assert_raises(ArgumentError) do
          BaseGoal.from_h({ id: "123" })
        end
        assert_match(/Missing required keys/, error.message)
      end
    end
  end
end


