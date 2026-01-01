# frozen_string_literal: true

require "test_helper"

module Execution
  # Basic tests for all remaining execution prompts
  
  class StepPlanningPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initializes and validates parameters" do
      step = Planning::Step.new(milestone_number: 1, step_number: 1, title: "Test", intent: "Test", details: ["d"], tests: ["t"])
      prompt = StepPlanningPrompt.new(step: step, available_tools: [], assembled_context: {})
      assert_not_nil prompt.system_prompt
      assert_not_nil prompt.response_schema
    end
  end

  class ToolValidationPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initializes and validates parameters" do
      tool_call = { tool: "write_file", params: {}, rationale: "test" }
      prompt = ToolValidationPrompt.new(tool_call: tool_call, context: {})
      assert_not_nil prompt.system_prompt
      assert_not_nil prompt.response_schema
    end
  end

  class StepExecutionPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initializes and validates parameters" do
      step = Planning::Step.new(milestone_number: 1, step_number: 1, title: "Test", intent: "Test", details: ["d"], tests: ["t"])
      prompt = StepExecutionPrompt.new(step: step, context: {}, available_tools: [])
      assert_not_nil prompt.system_prompt
      assert_nil prompt.response_schema  # Uses tool calling
    end
  end

  class StepEvaluationPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initializes and validates parameters" do
      step = Planning::Step.new(milestone_number: 1, step_number: 1, title: "Test", intent: "Test", details: ["d"], tests: ["t"])
      result = { step_id: "1.1", success: true, actions_taken: [], files_changed: [], diffs: {} }
      prompt = StepEvaluationPrompt.new(step: step, step_result: result, context: {})
      assert_not_nil prompt.system_prompt
      assert_not_nil prompt.response_schema
    end
  end

  class ErrorRecoveryPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initializes and validates parameters" do
      step = Planning::Step.new(milestone_number: 1, step_number: 1, title: "Test", intent: "Test", details: ["d"], tests: ["t"])
      result = { step_id: "1.1", actions_taken: [] }
      prompt = ErrorRecoveryPrompt.new(step: step, error: "Test error", step_result: result)
      assert_not_nil prompt.system_prompt
      assert_not_nil prompt.response_schema
    end
  end
end

