# frozen_string_literal: true

require "test_helper"

module Planning
  class CodebaseAnalysisPromptTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with required parameters" do
      file_tree = "app/\n  workers/\n    base_worker.rb"
      
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Create a PlanAgentWorker",
        file_tree: file_tree,
        path: "/home/user/project"
      )

      assert_not_nil prompt
      assert_equal "Create a PlanAgentWorker", prompt.goal
      assert_equal file_tree, prompt.file_tree
      assert_equal "/home/user/project", prompt.path
    end

    speed_profile :fast
    test "validates goal must be a String" do
      error = assert_raises(ArgumentError) do
        CodebaseAnalysisPrompt.new(
          goal: 123,
          file_tree: "tree",
          path: "/path"
        )
      end
      assert_match(/goal must be a String/, error.message)
    end

    speed_profile :fast
    test "validates file_tree must be a String" do
      error = assert_raises(ArgumentError) do
        CodebaseAnalysisPrompt.new(
          goal: "Test goal",
          file_tree: 123,
          path: "/path"
        )
      end
      assert_match(/file_tree must be a String/, error.message)
    end

    speed_profile :fast
    test "validates path must be a String" do
      error = assert_raises(ArgumentError) do
        CodebaseAnalysisPrompt.new(
          goal: "Test goal",
          file_tree: "tree",
          path: 123
        )
      end
      assert_match(/path must be a String/, error.message)
    end

    speed_profile :fast
    test "system_prompt explains analysis task" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      system_msg = prompt.system_prompt

      assert_includes system_msg, "analyz"
      assert_includes system_msg, "codebase"
      assert_includes system_msg, "relevant"
    end

    speed_profile :fast
    test "system_prompt requests specific file paths" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      system_msg = prompt.system_prompt

      assert_includes system_msg, "file"
      assert_includes system_msg, "path"
    end

    speed_profile :fast
    test "system_prompt mentions patterns and constraints" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      system_msg = prompt.system_prompt

      assert_includes system_msg, "pattern"
      assert_includes system_msg, "constraint"
    end

    speed_profile :fast
    test "build_user_message includes goal" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Create a PlanAgentWorker",
        file_tree: "tree",
        path: "/path"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "Create a PlanAgentWorker"
    end

    speed_profile :fast
    test "build_user_message includes file tree" do
      file_tree = "app/\n  workers/\n    base_worker.rb\n    agent_worker.rb"
      
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: file_tree,
        path: "/path"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "base_worker.rb"
      assert_includes user_msg, "agent_worker.rb"
    end

    speed_profile :fast
    test "build_user_message includes path" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/home/user/project"
      )

      user_msg = prompt.build_user_message

      assert_includes user_msg, "/home/user/project"
    end

    speed_profile :fast
    test "response_schema specifies json_object format" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      schema = prompt.response_schema

      assert_not_nil schema
      assert_equal "object", schema[:type]
    end

    speed_profile :fast
    test "response_schema requires relevant_files array" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      schema = prompt.response_schema

      assert_includes schema[:required], "relevant_files"
      assert_equal "array", schema[:properties][:relevant_files][:type]
      assert_equal "string", schema[:properties][:relevant_files][:items][:type]
    end

    speed_profile :fast
    test "response_schema requires patterns array" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      schema = prompt.response_schema

      assert_includes schema[:required], "patterns"
      assert_equal "array", schema[:properties][:patterns][:type]
    end

    speed_profile :fast
    test "response_schema requires constraints array" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      schema = prompt.response_schema

      assert_includes schema[:required], "constraints"
      assert_equal "array", schema[:properties][:constraints][:type]
    end

    speed_profile :fast
    test "response_schema includes optional context field" do
      prompt = CodebaseAnalysisPrompt.new(
        goal: "Test goal",
        file_tree: "tree",
        path: "/path"
      )

      schema = prompt.response_schema

      assert schema[:properties].key?(:context)
      assert_equal "string", schema[:properties][:context][:type]
    end
  end
end

