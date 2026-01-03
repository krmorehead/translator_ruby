# frozen_string_literal: true

module Planning
  # Prompt that guides the LLM in analyzing the codebase to identify relevant files and patterns.
  # Provides context for plan generation.
  class CodebaseAnalysisPrompt < BasePrompt
    attr_reader :goal, :file_tree, :path

    # @param goal [String] The goal to analyze the codebase for
    # @param file_tree [String] File tree structure from FileTreeTool
    # @param path [String] Root directory path
    def initialize(goal:, file_tree:, path:)
      validate_parameters!(goal, file_tree, path)

      @goal = goal
      @file_tree = file_tree
      @path = path
      super()
    end

    def system_prompt
      <<~PROMPT
        You are an expert code analyst. Your role is to analyze a codebase and identify 
        files, patterns, and constraints relevant to a specific development goal.

        ## Your Task

        Given a project goal and the codebase file structure, identify:

        1. **Relevant Files** - Specific file paths that are relevant to the goal
           - Focus on files that will be referenced or serve as examples
           - Include base classes, similar implementations, and test files
           - Limit to the top 10-15 most relevant files
           - Provide full relative paths from the project root

        2. **Patterns to Follow** - Development patterns used in the codebase
           - Architectural patterns (e.g., "Use state machines for workers")
           - Code organization patterns (e.g., "Separate concerns into modules")
           - Testing patterns (e.g., "Write unit tests in test/ directory")
           - Naming conventions (e.g., "Use underscore case for file names")

        3. **Constraints** - Technical constraints or requirements
           - Framework requirements (e.g., "Must extend BaseWorker")
           - Testing requirements (e.g., "All models must have test coverage")
           - Style requirements (e.g., "Follow OOP patterns from docs/references/oop-patterns.md")

        4. **Context** (optional) - Additional relevant context
           - Notes about existing similar implementations
           - Warnings about complexity or gotchas
           - Suggestions for how to approach the task

        ## Output Format

        Return a JSON object with:
        - `relevant_files`: Array of file path strings (top 10-15 most relevant)
        - `patterns`: Array of pattern description strings
        - `constraints`: Array of constraint description strings  
        - `context`: Optional string with additional context

        ## Guidelines

        - Be selective: Only include files directly relevant to the goal
        - Be specific: Provide concrete, actionable patterns and constraints
        - Be concise: Keep descriptions clear and focused
        - Prioritize: List most important items first
      PROMPT
    end

    def build_user_message
      message = []
      message << "## Goal"
      message << ""
      message << @goal
      message << ""
      message << "## Codebase Root"
      message << ""
      message << @path
      message << ""
      message << "## File Tree"
      message << ""
      message << "```"
      message << @file_tree
      message << "```"
      message << ""
      message << "## Instructions"
      message << ""
      message << "Analyze this codebase and identify the files, patterns, and constraints"
      message << "most relevant to achieving the stated goal. Focus on finding examples"
      message << "of similar implementations and understanding the architectural patterns used."

      message.join("\n")
    end

    def response_schema
      {
        type: "object",
        properties: {
          relevant_files: {
            type: "array",
            items: { type: "string" }
          },
          patterns: {
            type: "array",
            items: { type: "string" }
          },
          constraints: {
            type: "array",
            items: { type: "string" }
          },
          context: {
            type: "string"
          }
        },
        required: ["relevant_files", "patterns", "constraints"],
        additionalProperties: false
      }
    end

    # Override execute to use build_user_message
    def execute(prompt: nil, context: nil)
      user_message = build_user_message
      super(prompt: user_message, context: context)
    end

    private

    def validate_parameters!(goal, file_tree, path)
      raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
      raise ArgumentError, "file_tree must be a String, got #{file_tree.class}" unless file_tree.is_a?(String)
      raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
    end
  end
end








