# frozen_string_literal: true

module Execution
  # Prompt that determines what codebase context is needed to execute a step effectively.
  # Prevents both under-context (missing information) and over-context (token waste).
  #
  # @example Basic usage
  #   prompt = Execution::ContextAssemblyPrompt.new(
  #     step: plan_step,
  #     codebase_root: "/path/to/code",
  #     file_tree_summary: "app/, config/, lib/"
  #   )
  #   
  #   result = prompt.execute(
  #     prompt: "What context do you need?",
  #     context: {}
  #   )
  #   
  #   result[:content][:files_to_read]  # => ["app/models/user.rb"]
  class ContextAssemblyPrompt < BasePrompt
    attr_reader :step, :codebase_root, :file_tree_summary

    # @param step [Planning::Step] The step to execute
    # @param codebase_root [String] Root path of the codebase
    # @param file_tree_summary [String, nil] Optional summary of file structure
    def initialize(step:, codebase_root:, file_tree_summary: nil)
      validate_parameters!(step, codebase_root)
      
      @step = step
      @codebase_root = codebase_root
      @file_tree_summary = file_tree_summary
      
      super()
    end

    def system_prompt
      <<~PROMPT
        You are analyzing a plan step to determine what codebase context is needed for execution.

        Your goal is to identify the minimal set of files, patterns, and directories needed to understand
        and execute this step effectively. Request only what's necessary - not the entire codebase.

        ## Guidelines

        - **Be Specific**: Request exact file paths when possible
        - **Be Minimal**: Only request what's actually needed for this specific step
        - **Consider Dependencies**: Think about what files the target might depend on
        - **Look for Patterns**: If you need to understand conventions, request example files
        - **Avoid Excess**: Don't request entire directories unless truly necessary

        ## When to Request What

        - **Creating New Files**: Request similar existing files to understand patterns
        - **Modifying Files**: Request the target file and any dependencies
        - **Adding Features**: Request related feature files and tests
        - **Fixing Bugs**: Request the failing file and relevant test files
        - **Refactoring**: Request files that will change and their callers

        ## Response Format

        Return a JSON object with:
        - `files_to_read`: Array of specific file paths (e.g., ["app/models/user.rb"])
        - `patterns_to_search`: Array of grep patterns (e.g., ["class.*Service", "def authenticate"])
        - `directories_to_explore`: Array of directory paths to browse (e.g., ["app/models"])
        - `rationale`: Brief explanation of why you need this context
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          files_to_read: {
            type: "array",
            items: { type: "string" },
            description: "Specific file paths to read"
          },
          patterns_to_search: {
            type: "array",
            items: { type: "string" },
            description: "Grep patterns to search for in the codebase"
          },
          directories_to_explore: {
            type: "array",
            items: { type: "string" },
            description: "Directory paths to explore"
          },
          rationale: {
            type: "string",
            description: "Explanation of why this context is needed"
          }
        },
        required: ["files_to_read", "patterns_to_search", "directories_to_explore", "rationale"],
        additionalProperties: false
      }
    end

    # Build the user message for context assembly
    def build_user_message
      message = []
      
      message << "## Step to Execute"
      message << ""
      message << "**Step Number**: #{@step.number}"
      message << "**Title**: #{@step.title}"
      message << ""
      message << "**Intent**: #{@step.intent}"
      message << ""
      message << "**Details**:"
      @step.details.each { |detail| message << "- #{detail}" }
      message << ""
      message << "**Tests/Acceptance Criteria**:"
      @step.tests.each { |test| message << "- #{test}" }
      
      if @file_tree_summary
        message << ""
        message << "## Available Codebase Structure"
        message << ""
        message << @file_tree_summary
      end
      
      message << ""
      message << "## Your Task"
      message << ""
      message << "Analyze this step and determine what codebase context you need to execute it effectively."
      message << "Be specific and minimal - request only what's necessary."
      
      message.join("\n")
    end

    private

    def validate_parameters!(step, codebase_root)
      unless step.is_a?(Planning::Step)
        raise TypeError, "step must be a Planning::Step, got #{step.class}"
      end

      unless codebase_root.is_a?(String) && !codebase_root.empty?
        raise ArgumentError, "codebase_root must be a non-empty String"
      end
    end
  end
end








