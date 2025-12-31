# frozen_string_literal: true

require "test_helper"

module Execution
  class SisyphusSystemPromptTest < ActiveSupport::TestCase
    # ===== Initialization Tests =====

    test "initializes with default empty parameters" do
      prompt = SisyphusSystemPrompt.new

      assert_equal [], prompt.capabilities
      assert_equal [], prompt.available_tools
      assert_equal({}, prompt.execution_context)
    end

    test "initializes with capabilities" do
      capabilities = ["file_modification", "command_execution"]
      
      prompt = SisyphusSystemPrompt.new(capabilities: capabilities)

      assert_equal capabilities, prompt.capabilities
    end

    test "initializes with available_tools" do
      tools = [
        { name: "write_file", description: "Write content to a file" },
        { name: "bash", description: "Execute bash command" }
      ]
      
      prompt = SisyphusSystemPrompt.new(available_tools: tools)

      assert_equal tools, prompt.available_tools
    end

    test "initializes with execution_context" do
      context = {
        codebase_path: "/path/to/code",
        plan_goal: "Add authentication",
        current_milestone: "User Model",
        current_step: "Create User Model"
      }
      
      prompt = SisyphusSystemPrompt.new(execution_context: context)

      assert_equal context, prompt.execution_context
    end

    # ===== Validation Tests =====

    test "validates capabilities is an Array" do
      error = assert_raises(ArgumentError) do
        SisyphusSystemPrompt.new(capabilities: "not an array")
      end

      assert_match(/capabilities must be an Array/, error.message)
    end

    test "validates available_tools is an Array" do
      error = assert_raises(ArgumentError) do
        SisyphusSystemPrompt.new(available_tools: "not an array")
      end

      assert_match(/available_tools must be an Array/, error.message)
    end

    test "validates execution_context is a Hash" do
      error = assert_raises(ArgumentError) do
        SisyphusSystemPrompt.new(execution_context: [])
      end

      assert_match(/execution_context must be a Hash/, error.message)
    end

    # ===== System Prompt Generation Tests =====

    test "system_prompt includes agent identity" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "Sisyphus"
      assert_includes system_message, "autonomous code execution agent"
    end

    test "system_prompt includes capabilities section" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Your Capabilities"
    end

    test "system_prompt formats capabilities list" do
      capabilities = ["file_modification", "command_execution", "testing"]
      prompt = SisyphusSystemPrompt.new(capabilities: capabilities)

      system_message = prompt.system_prompt

      assert_includes system_message, "File modification"
      assert_includes system_message, "Command execution"
      assert_includes system_message, "Testing"
    end

    test "system_prompt includes available tools section" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Available Tools"
    end

    test "system_prompt formats tools list" do
      tools = [
        { name: "write_file", description: "Write content to a file" },
        { name: "bash", description: "Execute bash command" }
      ]
      prompt = SisyphusSystemPrompt.new(available_tools: tools)

      system_message = prompt.system_prompt

      assert_includes system_message, "### write_file"
      assert_includes system_message, "Write content to a file"
      assert_includes system_message, "### bash"
      assert_includes system_message, "Execute bash command"
    end

    test "system_prompt includes execution guidelines" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Execution Guidelines"
      assert_includes system_message, "Step-by-Step Process"
      assert_includes system_message, "Quality Standards"
      assert_includes system_message, "Best Practices"
    end

    test "system_prompt includes current execution context" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Current Execution Context"
    end

    test "system_prompt formats execution context" do
      context = {
        codebase_path: "/path/to/code",
        plan_goal: "Add authentication",
        current_milestone: "User Model",
        current_step: "Create User Model"
      }
      prompt = SisyphusSystemPrompt.new(execution_context: context)

      system_message = prompt.system_prompt

      assert_includes system_message, "/path/to/code"
      assert_includes system_message, "Add authentication"
      assert_includes system_message, "User Model"
      assert_includes system_message, "Create User Model"
    end

    test "system_prompt includes anti-patterns section" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Anti-Patterns to Avoid"
      assert_includes system_message, "Don't"
    end

    test "system_prompt includes examples" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Examples of Good Execution"
      assert_includes system_message, "Example 1"
      assert_includes system_message, "Example 2"
      assert_includes system_message, "Example 3"
    end

    test "system_prompt handles empty capabilities gracefully" do
      prompt = SisyphusSystemPrompt.new(capabilities: [])

      system_message = prompt.system_prompt

      assert_includes system_message, "Standard code execution capabilities"
    end

    test "system_prompt handles empty tools gracefully" do
      prompt = SisyphusSystemPrompt.new(available_tools: [])

      system_message = prompt.system_prompt

      assert_includes system_message, "No tools currently available"
    end

    test "system_prompt handles empty context gracefully" do
      prompt = SisyphusSystemPrompt.new(execution_context: {})

      system_message = prompt.system_prompt

      assert_includes system_message, "No specific context provided"
    end

    # ===== Response Schema Tests =====

    test "response_schema returns nil for freeform text" do
      prompt = SisyphusSystemPrompt.new

      assert_nil prompt.response_schema
    end

    # ===== Integration Tests =====

    test "generates complete system prompt with all sections" do
      capabilities = ["file_modification", "testing"]
      tools = [{ name: "write_file", description: "Write files" }]
      context = {
        codebase_path: "/code",
        plan_goal: "Test goal",
        current_step: "Test step"
      }

      prompt = SisyphusSystemPrompt.new(
        capabilities: capabilities,
        available_tools: tools,
        execution_context: context
      )

      system_message = prompt.system_prompt

      # Verify all major sections are present
      assert_includes system_message, "# Sisyphus"
      assert_includes system_message, "## Your Identity"
      assert_includes system_message, "## Your Capabilities"
      assert_includes system_message, "## Available Tools"
      assert_includes system_message, "## Execution Guidelines"
      assert_includes system_message, "## Current Execution Context"
      assert_includes system_message, "## Anti-Patterns to Avoid"
      assert_includes system_message, "## Examples of Good Execution"

      # Verify content is included
      assert_includes system_message, "File modification"
      assert_includes system_message, "write_file"
      assert_includes system_message, "/code"
      assert_includes system_message, "Test goal"
    end

    test "system prompt is a non-empty string" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_instance_of String, system_message
      assert system_message.length > 100
    end

    test "system prompt contains actionable guidance" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      # Should contain specific instructions
      assert_includes system_message, "Read files before modifying"
      assert_includes system_message, "Test after"
      assert_includes system_message, "Verify"
    end
  end
end

