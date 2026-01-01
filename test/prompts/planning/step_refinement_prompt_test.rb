# frozen_string_literal: true

require "test_helper"

module Planning
  class StepRefinementPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with required parameters" do
      step = PlanStep.new(
        title: "Create Worker",
        intent: "Build worker class",
        details: ["Extend BaseWorker"],
        tests: ["Test initialization"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Add more details about state machine setup"
      )

      assert_not_nil prompt
      assert_equal step, prompt.step
      assert_equal "Add more details about state machine setup", prompt.feedback
      assert_nil prompt.context
    end

    speed_profile :fast
    test "initialization with optional context" do
      step = PlanStep.new(
        title: "Create Worker",
        intent: "Build worker class",
        details: ["Extend BaseWorker"],
        tests: ["Test initialization"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Add more details",
        context: "Worker should use ResearchMemoryStore"
      )

      assert_equal "Worker should use ResearchMemoryStore", prompt.context
    end

    speed_profile :fast
    test "validates step must be a PlanStep" do
      error = assert_raises(ArgumentError) do
        StepRefinementPrompt.new(
          step: "not a step",
          feedback: "Some feedback"
        )
      end
      assert_match(/step must be a PlanStep/, error.message)
    end

    speed_profile :fast
    test "validates feedback must be a String" do
      step = PlanStep.new(
        title: "Create Worker",
        intent: "Build worker class",
        details: ["Extend BaseWorker"],
        tests: ["Test initialization"]
      )

      error = assert_raises(ArgumentError) do
        StepRefinementPrompt.new(
          step: step,
          feedback: 123
        )
      end
      assert_match(/feedback must be a String/, error.message)
    end

    speed_profile :fast
    test "system_prompt explains refinement task" do
      step = PlanStep.new(
        title: "Test",
        intent: "Intent",
        details: ["detail"],
        tests: ["test"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Feedback"
      )

      system_msg = prompt.system_prompt

      assert_includes system_msg, "refin"
      assert_includes system_msg, "step"
      assert_includes system_msg, "feedback"
    end

    speed_profile :fast
    test "build_user_message includes step details" do
      step = PlanStep.new(
        title: "Create Worker Class",
        intent: "Build the main worker",
        details: ["Extend BaseWorker", "Add state machine"],
        tests: ["Test initialization", "Test state transitions"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Add more details"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "Create Worker Class"
      assert_includes user_msg, "Build the main worker"
      assert_includes user_msg, "Extend BaseWorker"
      assert_includes user_msg, "Add state machine"
      assert_includes user_msg, "Test initialization"
      assert_includes user_msg, "Test state transitions"
    end

    speed_profile :fast
    test "build_user_message includes feedback" do
      step = PlanStep.new(
        title: "Test",
        intent: "Intent",
        details: ["detail"],
        tests: ["test"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Please add more specific implementation details"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "Please add more specific implementation details"
    end

    speed_profile :fast
    test "build_user_message includes optional context" do
      step = PlanStep.new(
        title: "Test",
        intent: "Intent",
        details: ["detail"],
        tests: ["test"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Feedback",
        context: "This is additional context"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "This is additional context"
    end

    speed_profile :fast
    test "build_user_message works without optional context" do
      step = PlanStep.new(
        title: "Test",
        intent: "Intent",
        details: ["detail"],
        tests: ["test"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Feedback"
      )

      user_msg = prompt.build_user_message

      assert_not_nil user_msg
      assert user_msg.length > 0
    end

    speed_profile :fast
    test "response_schema specifies json_object format" do
      step = PlanStep.new(
        title: "Test",
        intent: "Intent",
        details: ["detail"],
        tests: ["test"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Feedback"
      )

      schema = prompt.response_schema

      assert_not_nil schema
      assert_equal "object", schema[:type]
    end

    speed_profile :fast
    test "response_schema matches PlanStep structure" do
      step = PlanStep.new(
        title: "Test",
        intent: "Intent",
        details: ["detail"],
        tests: ["test"]
      )

      prompt = StepRefinementPrompt.new(
        step: step,
        feedback: "Feedback"
      )

      schema = prompt.response_schema

      assert_includes schema[:required], "title"
      assert_includes schema[:required], "intent"
      assert_includes schema[:required], "details"
      assert_includes schema[:required], "tests"
      assert_equal "string", schema[:properties][:title][:type]
      assert_equal "string", schema[:properties][:intent][:type]
      assert_equal "array", schema[:properties][:details][:type]
      assert_equal "array", schema[:properties][:tests][:type]
    end
  end
end

