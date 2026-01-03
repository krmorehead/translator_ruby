# frozen_string_literal: true

require "test_helper"

module Planning
  class PlanGenerationPromptTest < ActiveSupport::TestCase
    setup do
      @goal = "Create a PlanAgentWorker"
      @path = Rails.root.join("test/fixtures/example_codebase").to_s
    end

    speed_profile :fast
    test "initialization with required parameters" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      assert_not_nil prompt
      assert_equal @goal, prompt.goal
      assert_equal @path, prompt.path
      assert_nil prompt.context
    end

    speed_profile :fast
    test "initialization with optional context" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path,
        context: "Additional context info"
      )

      assert_equal "Additional context info", prompt.context
    end

    speed_profile :fast
    test "validates goal must be a String" do
      error = assert_raises(ArgumentError) do
        PlanGenerationPrompt.new(
          goal: 123,
          path: @path
        )
      end
      assert_match(/goal must be a String/, error.message)
    end

    speed_profile :fast
    test "validates path must be a String" do
      error = assert_raises(ArgumentError) do
        PlanGenerationPrompt.new(
          goal: @goal,
          path: 123
        )
      end
      assert_match(/path must be a String/, error.message)
    end

    speed_profile :fast
    test "system_message includes codebase exploration guidance" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      system_msg = prompt.system_message

      assert_includes system_msg, "explore"
      assert_includes system_msg, "codebase"
      assert_includes system_msg, "tools"
    end

    speed_profile :fast
    test "system_message mentions available tools" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      system_msg = prompt.system_message

      assert_includes system_msg, "file_tree"
      assert_includes system_msg, "grep"
      assert_includes system_msg, "read_file"
    end

    speed_profile :fast
    test "system_message emphasizes exploring before planning" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      system_msg = prompt.system_message

      assert_includes system_msg.downcase, "explore"
      assert_includes system_msg.downcase, "understand"
    end

    speed_profile :fast
    test "user_message includes goal" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      user_msg = prompt.user_message

      assert_includes user_msg, @goal
    end

    speed_profile :fast
    test "user_message includes path" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      user_msg = prompt.user_message

      assert_includes user_msg, @path
    end

    speed_profile :fast
    test "user_message includes optional context when provided" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path,
        context: "This is additional context"
      )

      user_msg = prompt.user_message

      assert_includes user_msg, "This is additional context"
    end

    speed_profile :fast
    test "user_message works without optional context" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      user_msg = prompt.user_message

      assert_not_nil user_msg
      assert user_msg.length > 0
    end

    speed_profile :fast
    test "user_message instructs to explore then plan" do
      prompt = PlanGenerationPrompt.new(
        goal: @goal,
        path: @path
      )

      user_msg = prompt.user_message

      assert_includes user_msg.downcase, "explore"
      assert_includes user_msg.downcase, "plan"
    end
  end
end
