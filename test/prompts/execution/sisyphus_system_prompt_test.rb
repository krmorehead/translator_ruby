# frozen_string_literal: true

require "test_helper"

module Execution
  class SisyphusSystemPromptTest < ActiveSupport::TestCase
    # Helper to create a SisyphusContext for testing
    def create_test_context
      Contexts::SisyphusContext.new(
        codebase_path: Rails.root.to_s,
        plan_goal: "Test Plan Goal",
        plan_id: "test-plan-123",
        execution_id: "test-exec-456",
        current_milestone: { number: 1, title: "User Model", description: "Create user model" },
        current_step: { number: "1.1", title: "Create User Model", intent: "Define user entity" }
      )
    end

    # ===== Initialization Tests =====
    speed_profile :fast
    test "initializes with default empty parameters" do
      prompt = SisyphusSystemPrompt.new

      assert_equal [], prompt.capabilities
      assert_equal [], prompt.available_tools
      assert_nil prompt.execution_context
    end

    speed_profile :fast
    test "initializes with capabilities" do
      capabilities = ["file_modification", "command_execution"]
      
      prompt = SisyphusSystemPrompt.new(capabilities: capabilities)

      assert_equal capabilities, prompt.capabilities
    end

    speed_profile :fast
    test "initializes with available_tools" do
      tools = [
        { name: "write_file", description: "Write content to a file" },
        { name: "bash", description: "Execute bash command" }
      ]
      
      prompt = SisyphusSystemPrompt.new(available_tools: tools)

      assert_equal tools, prompt.available_tools
    end

    speed_profile :fast
    test "initializes with execution_context" do
      context = create_test_context
      
      prompt = SisyphusSystemPrompt.new(execution_context: context)

      assert_equal context, prompt.execution_context
      assert_kind_of Contexts::BaseContext, prompt.execution_context
    end

    # ===== Validation Tests =====

    speed_profile :fast
    test "validates capabilities is an Array" do
      error = assert_raises(ArgumentError) do
        SisyphusSystemPrompt.new(capabilities: "not an array")
      end

      assert_match(/capabilities must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates available_tools is an Array" do
      error = assert_raises(ArgumentError) do
        SisyphusSystemPrompt.new(available_tools: "not an array")
      end

      assert_match(/available_tools must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates execution_context is a Context object" do
      error = assert_raises(TypeError) do
        SisyphusSystemPrompt.new(execution_context: {})
      end

      assert_match(/execution_context must be a Contexts::BaseContext subclass/, error.message)
    end

    # ===== System Prompt Generation Tests =====

    speed_profile :fast
    test "system_prompt includes agent identity" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "Sisyphus"
      assert_includes system_message, "autonomous code execution agent"
    end

    speed_profile :fast
    test "system_prompt includes capabilities section" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Your Capabilities"
    end

    speed_profile :fast
    test "system_prompt formats capabilities list" do
      capabilities = ["file_modification", "command_execution", "testing"]
      prompt = SisyphusSystemPrompt.new(capabilities: capabilities)

      system_message = prompt.system_prompt

      assert_includes system_message, "File modification"
      assert_includes system_message, "Command execution"
      assert_includes system_message, "Testing"
    end

    speed_profile :fast
    test "system_prompt includes available tools section" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Available Tools"
    end

    speed_profile :fast
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

    speed_profile :fast
    test "system_prompt includes execution guidelines" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Execution Guidelines"
      assert_includes system_message, "Step-by-Step Process"
      assert_includes system_message, "Quality Standards"
      assert_includes system_message, "Best Practices"
    end

    speed_profile :fast
    test "system_prompt includes current execution context" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Current Execution Context"
    end

    speed_profile :fast
    test "system_prompt formats execution context" do
      context = create_test_context
      prompt = SisyphusSystemPrompt.new(execution_context: context)

      system_message = prompt.system_prompt

      assert_includes system_message, Rails.root.to_s
      assert_includes system_message, "Test Plan Goal"
      assert_includes system_message, "User Model"
      assert_includes system_message, "Create User Model"
    end

    speed_profile :fast
    test "system_prompt includes anti-patterns section" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Anti-Patterns to Avoid"
      assert_includes system_message, "Don't"
    end

    speed_profile :fast
    test "system_prompt includes examples" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_includes system_message, "## Examples of Good Execution"
      assert_includes system_message, "Example 1"
      assert_includes system_message, "Example 2"
      assert_includes system_message, "Example 3"
    end

    speed_profile :fast
    test "system_prompt handles empty capabilities gracefully" do
      prompt = SisyphusSystemPrompt.new(capabilities: [])

      system_message = prompt.system_prompt

      assert_includes system_message, "Standard code execution capabilities"
    end

    speed_profile :fast
    test "system_prompt handles empty tools gracefully" do
      prompt = SisyphusSystemPrompt.new(available_tools: [])

      system_message = prompt.system_prompt

      assert_includes system_message, "No tools currently available"
    end

    speed_profile :fast
    test "system_prompt handles empty context gracefully" do
      prompt = SisyphusSystemPrompt.new(execution_context: nil)

      system_message = prompt.system_prompt

      assert_includes system_message, "No specific context provided"
    end

    # ===== Response Schema Tests =====

    speed_profile :fast
    test "response_schema returns nil for freeform text" do
      prompt = SisyphusSystemPrompt.new

      assert_nil prompt.response_schema
    end

    # ===== Integration Tests =====

    speed_profile :fast
    test "generates complete system prompt with all sections" do
      capabilities = ["file_modification", "testing"]
      tools = [{ name: "write_file", description: "Write files" }]
      context = create_test_context

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
      assert_includes system_message, Rails.root.to_s
      assert_includes system_message, "Test Plan Goal"
    end

    speed_profile :fast
    test "system prompt is a non-empty string" do
      prompt = SisyphusSystemPrompt.new

      system_message = prompt.system_prompt

      assert_instance_of String, system_message
      assert system_message.length > 100
    end

    speed_profile :fast
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

