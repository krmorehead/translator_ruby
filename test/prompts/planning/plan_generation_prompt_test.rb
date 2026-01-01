# frozen_string_literal: true

require "test_helper"

module Planning
  class PlanGenerationPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with required parameters" do
      analysis_results = {
        relevant_files: ["app/workers/base_worker.rb"],
        patterns: ["Use state machines"],
        constraints: ["Follow OOP"]
      }

      prompt = PlanGenerationPrompt.new(
        goal: "Create a PlanAgentWorker",
        analysis_results: analysis_results
      )

      assert_not_nil prompt
      assert_equal "Create a PlanAgentWorker", prompt.goal
      assert_equal analysis_results, prompt.analysis_results
      assert_nil prompt.context
    end

    speed_profile :fast
    test "initialization with optional context" do
      analysis_results = { relevant_files: [] }
      
      prompt = PlanGenerationPrompt.new(
        goal: "Create a PlanAgentWorker",
        analysis_results: analysis_results,
        context: "Additional context info"
      )

      assert_equal "Additional context info", prompt.context
    end

    speed_profile :fast
    test "validates goal must be a String" do
      error = assert_raises(ArgumentError) do
        PlanGenerationPrompt.new(
          goal: 123,
          analysis_results: {}
        )
      end
      assert_match(/goal must be a String/, error.message)
    end

    speed_profile :fast
    test "validates analysis_results must be a Hash" do
      error = assert_raises(ArgumentError) do
        PlanGenerationPrompt.new(
          goal: "Test goal",
          analysis_results: "not a hash"
        )
      end
      assert_match(/analysis_results must be a Hash/, error.message)
    end

    speed_profile :fast
    test "system_prompt includes plan structure guidance" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      system_msg = prompt.system_prompt

      assert_includes system_msg, "execution plan"
      assert_includes system_msg, "milestone"
      assert_includes system_msg, "step"
    end

    speed_profile :fast
    test "system_prompt emphasizes small testable incremental steps" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      system_msg = prompt.system_prompt

      assert_includes system_msg.downcase, "small"
      assert_includes system_msg.downcase, "testable"
      assert_includes system_msg.downcase, "incremental"
    end

    speed_profile :fast
    test "build_user_message includes goal" do
      prompt = PlanGenerationPrompt.new(
        goal: "Create a PlanAgentWorker",
        analysis_results: {}
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "Create a PlanAgentWorker"
    end

    speed_profile :fast
    test "build_user_message includes analysis results" do
      analysis_results = {
        relevant_files: ["app/workers/base_worker.rb", "app/workflows/base_workflow.rb"],
        patterns: ["Use state machines", "Follow OOP patterns"],
        constraints: ["Must write tests first"]
      }

      prompt = PlanGenerationPrompt.new(
        goal: "Create a PlanAgentWorker",
        analysis_results: analysis_results
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "app/workers/base_worker.rb"
      assert_includes user_msg, "app/workflows/base_workflow.rb"
      assert_includes user_msg, "Use state machines"
      assert_includes user_msg, "Follow OOP patterns"
      assert_includes user_msg, "Must write tests first"
    end

    speed_profile :fast
    test "build_user_message includes optional context when provided" do
      prompt = PlanGenerationPrompt.new(
        goal: "Create a PlanAgentWorker",
        analysis_results: {},
        context: "This is additional context"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "This is additional context"
    end

    speed_profile :fast
    test "build_user_message works without optional context" do
      prompt = PlanGenerationPrompt.new(
        goal: "Create a PlanAgentWorker",
        analysis_results: {}
      )

      user_msg = prompt.build_user_message

      assert_not_nil user_msg
      assert user_msg.length > 0
    end

    speed_profile :fast
    test "response_schema specifies json_object format" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      schema = prompt.response_schema

      assert_not_nil schema
      assert_equal "object", schema[:type]
    end

    speed_profile :fast
    test "response_schema requires milestones array" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      schema = prompt.response_schema

      assert_includes schema[:required], "milestones"
      assert_equal "array", schema[:properties][:milestones][:type]
    end

    speed_profile :fast
    test "response_schema defines milestone structure" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      schema = prompt.response_schema
      milestone_schema = schema[:properties][:milestones][:items]

      assert_equal "object", milestone_schema[:type]
      assert_includes milestone_schema[:required], "title"
      assert_includes milestone_schema[:required], "description"
      assert_includes milestone_schema[:required], "steps"
    end

    speed_profile :fast
    test "response_schema defines step structure" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      schema = prompt.response_schema
      milestone_schema = schema[:properties][:milestones][:items]
      step_schema = milestone_schema[:properties][:steps][:items]

      assert_equal "object", step_schema[:type]
      assert_includes step_schema[:required], "title"
      assert_includes step_schema[:required], "intent"
      assert_includes step_schema[:required], "details"
      assert_includes step_schema[:required], "tests"
    end

    speed_profile :fast
    test "response_schema includes optional fields" do
      prompt = PlanGenerationPrompt.new(
        goal: "Test goal",
        analysis_results: {}
      )

      schema = prompt.response_schema

      # Optional top-level fields
      assert schema[:properties].key?(:constraints)
      assert schema[:properties].key?(:assumptions)
      assert schema[:properties].key?(:risks)
    end
  end
end

