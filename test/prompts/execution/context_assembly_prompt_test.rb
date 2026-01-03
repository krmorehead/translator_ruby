# frozen_string_literal: true

require "test_helper"

module Execution
  class ContextAssemblyPromptTest < ActiveSupport::TestCase
    def setup
      @step = create_test_step
      @codebase_root = "/path/to/code"
    end

    def create_test_step
      Planning::Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create User Model",
        intent: "Define user entity",
        details: ["Add email field"],
        tests: ["Test user creation"]
      )
    end
    speed_profile :fast
    test "initializes with required parameters" do
      prompt = ContextAssemblyPrompt.new(
        step: @step,
        codebase_root: @codebase_root
      )

      assert_equal @step, prompt.step
      assert_equal @codebase_root, prompt.codebase_root
    end

    speed_profile :fast
    test "initializes with file_tree_summary" do
      prompt = ContextAssemblyPrompt.new(
        step: @step,
        codebase_root: @codebase_root,
        file_tree_summary: "app/, config/"
      )

      assert_equal "app/, config/", prompt.file_tree_summary
    end

    speed_profile :fast
    test "validates step is Planning::Step" do
      error = assert_raises(TypeError) do
        ContextAssemblyPrompt.new(step: "not a step", codebase_root: @codebase_root)
      end

      assert_match(/step must be a Planning::Step/, error.message)
    end

    speed_profile :fast
    test "validates codebase_root is non-empty String" do
      error = assert_raises(ArgumentError) do
        ContextAssemblyPrompt.new(step: @step, codebase_root: "")
      end

      assert_match(/codebase_root must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "system_prompt includes guidelines" do
      prompt = ContextAssemblyPrompt.new(step: @step, codebase_root: @codebase_root)

      system_message = prompt.system_prompt

      assert_includes system_message, "context is needed"
      assert_includes system_message, "Be Specific"
      assert_includes system_message, "Be Minimal"
    end

    speed_profile :fast
    test "response_schema defines correct structure" do
      prompt = ContextAssemblyPrompt.new(step: @step, codebase_root: @codebase_root)

      schema = prompt.response_schema

      assert_equal "object", schema[:type]
      assert_includes schema[:properties].keys, :files_to_read
      assert_includes schema[:properties].keys, :patterns_to_search
      assert_includes schema[:properties].keys, :directories_to_explore
      assert_includes schema[:properties].keys, :rationale
    end

    speed_profile :fast
    test "build_user_message includes step details" do
      prompt = ContextAssemblyPrompt.new(step: @step, codebase_root: @codebase_root)

      message = prompt.build_user_message

      assert_includes message, "Create User Model"
      assert_includes message, "Define user entity"
      assert_includes message, "Add email field"
      assert_includes message, "Test user creation"
    end
  end
end


