# frozen_string_literal: true

module Planning
  # Prompt for generating execution plans from user goals and codebase exploration.
  # Following Cline pattern: LLM uses actual tools to explore codebase.
  #
  # The LLM has access to tools (file_tree, grep, read_file) via function calling
  # and should explore the codebase as needed to understand structure before 
  # generating the plan.
  #
  # Extends ToolCallPrompt to enable actual tool calling with the LLM.
  #
  class PlanGenerationPrompt < ToolCallPrompt
    attr_reader :goal, :path, :context

    # @param goal [String] What to accomplish
    # @param path [String] Codebase root for exploration
    # @param context [String, nil] Optional context hint
    # @param available_tools [Array<Tool>] Tools for codebase exploration
    def initialize(goal:, path:, context: nil, available_tools: [])
      validate_params!(goal, path)
      
      @goal = goal
      @path = path
      @context = context
      
      # Call super with tools - ToolCallPrompt handles tool setup
      super(tools: available_tools)
    end

    def system_message
      <<~PROMPT
        You are Daedalus, a master architect and planner for software development projects.
        Your role is to analyze user goals, explore codebases, and generate detailed execution plans.

        ## CODEBASE EXPLORATION

        You have access to powerful tools to explore the codebase at: #{@path}

        Available tools:
        - file_tree(path, max_depth): List directory structure
        - grep(pattern, path): Search for code patterns
        - read_file(file_path): Read file contents

        **IMPORTANT**: Before generating a plan, you should:
        1. Use file_tree to understand the project structure
        2. Use grep to find relevant files and patterns
        3. Use read_file to examine key files
        4. Carefully manage context - only explore files relevant to the goal

        ## PLAN STRUCTURE

        Generate a structured execution plan with:

        **Milestones**: Logical groupings of related work
        - Each milestone has: title, description, steps, success_criteria
        - Milestones should be sequential phases

        **Steps**: Atomic, testable units of work
        - Each step has: title, intent, details (array), tests (array)
        - Steps should be small and incremental
        - Each step should specify what to change and why
        - Include specific file paths when relevant

        ## BEST PRACTICES

        - Break complex features into multiple milestones
        - Keep steps focused (one clear change per step)
        - Every step must have tests specified
        - Reference specific files discovered during exploration
        - Consider existing patterns in the codebase
        - Note any constraints or risks discovered

        ## OUTPUT FORMAT

        Return ONLY valid JSON matching this structure:
        {
          "goal": "string",
          "milestones": [
            {
              "title": "string",
              "description": "string",
              "success_criteria": "string",
              "steps": [
                {
                  "title": "string",
                  "intent": "string (why this step matters)",
                  "details": ["string (specific actions)"],
                  "tests": ["string (how to verify)"],
                  "file_changes": ["string (files to modify)"],
                  "estimated_duration": "string (e.g., '30 minutes')"
                }
              ]
            }
          ],
          "constraints": ["string (limitations discovered)"],
          "assumptions": ["string (assumptions made)"],
          "risks": ["string (potential issues)"],
          "metadata": {
            "files_explored": ["string (files examined)"],
            "patterns_found": ["string (patterns discovered)"]
          }
        }
      PROMPT
    end

    def user_message
      message = <<~MSG
        ## GOAL
        #{@goal}

        ## CODEBASE
        Path: #{@path}

        ## INSTRUCTIONS
        1. First, explore the codebase using available tools
        2. Understand the existing structure and patterns
        3. Generate a detailed execution plan for the goal
        4. Ensure each step references specific files when relevant
        5. Include tests for every step
      MSG

      if @context.present?
        message += <<~CTX

          ## CONTEXT HINT
          #{@context}
        CTX
      end

      message += <<~FINAL

        Begin by exploring the codebase, then generate the plan as JSON.
      FINAL

      message
    end

    def response_schema
      {
        type: "object",
        properties: {
          goal: { type: "string" },
          milestones: {
            type: "array",
            items: {
              type: "object",
              properties: {
                title: { type: "string" },
                description: { type: "string" },
                success_criteria: { type: "string" },
                steps: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      title: { type: "string" },
                      intent: { type: "string" },
                      details: {
                        type: "array",
                        items: { type: "string" }
                      },
                      tests: {
                        type: "array",
                        items: { type: "string" }
                      },
                      file_changes: {
                        type: "array",
                        items: { type: "string" }
                      },
                      estimated_duration: { type: "string" }
                    },
                    required: ["title", "intent", "details", "tests"]
                  }
                }
              },
              required: ["title", "description", "steps"]
            }
          },
          constraints: {
            type: "array",
            items: { type: "string" }
          },
          assumptions: {
            type: "array",
            items: { type: "string" }
          },
          risks: {
            type: "array",
            items: { type: "string" }
          },
          metadata: {
            type: "object",
            properties: {
              files_explored: {
                type: "array",
                items: { type: "string" }
              },
              patterns_found: {
                type: "array",
                items: { type: "string" }
              }
            }
          }
        },
        required: ["goal", "milestones"]
      }
    end

    # Override build_parameters to include tools for function calling
    # Includes both tools (for exploration) and response_schema (for structured output)
    def build_parameters(messages)
      parameters = super(messages)
      
      # Add tools for function calling if available
      parameters[:tools] = serialize_tools if @tools.any?
      
      parameters
    end

    private

    def validate_params!(goal, path)
      raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
      raise ArgumentError, "goal cannot be empty" if goal.strip.empty?
      raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
      raise ArgumentError, "path cannot be empty" if path.strip.empty?
    end
  end
end
