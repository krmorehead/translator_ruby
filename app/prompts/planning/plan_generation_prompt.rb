# frozen_string_literal: true

module Planning
  # Prompt that instructs the LLM to generate a structured execution plan.
  # Converts analysis results into a plan with milestones and steps.
  class PlanGenerationPrompt < BasePrompt
    attr_reader :goal, :analysis_results, :context

    # @param goal [String] The goal to create a plan for
    # @param analysis_results [Hash] Results from codebase analysis
    # @param context [String, nil] Optional additional context
    def initialize(goal:, analysis_results:, context: nil)
      validate_parameters!(goal, analysis_results)

      @goal = goal
      @analysis_results = analysis_results
      @context = context
      super()
    end

    def system_prompt
      <<~PROMPT
        You are an expert software architect and project planner. Your role is to create 
        detailed, actionable execution plans for software development tasks.

        ## Plan Structure

        An execution plan consists of:

        1. **Milestones** - High-level phases that group related work
           - Each milestone has: title, description, and steps
           - Milestones should represent logical phases of work
           - Example: "Core Infrastructure", "Domain Models", "Integration"

        2. **Steps** - Individual actionable tasks within milestones
           - Each step has: title, intent, details (array), tests (array)
           - Steps should be SMALL, TESTABLE, and INCREMENTAL
           - Each step should be completable in a single focused work session
           - Steps should follow TDD: write tests before implementation

        ## Example Plan Structure

        ```json
        {
          "milestones": [
            {
              "title": "Core Infrastructure",
              "description": "Build foundational classes and workflows",
              "steps": [
                {
                  "title": "Create BaseWorker class",
                  "intent": "Provide abstract base class for all workers with state machine",
                  "details": [
                    "Extend from ApplicationJob",
                    "Include StateMachine concern",
                    "Define common states: pending, running, complete, failed",
                    "Implement execute method template"
                  ],
                  "tests": [
                    "Test worker initialization",
                    "Test state transitions",
                    "Test error handling"
                  ]
                }
              ]
            }
          ],
          "constraints": ["Must follow OOP patterns", "Write tests first"],
          "assumptions": ["Rails environment available"],
          "risks": ["Complexity may require multiple iterations"]
        }
        ```

        ## Key Principles

        - **Small steps**: Each step should do ONE thing well
        - **Testable**: Every step must have specific test requirements
        - **Incremental**: Steps build on each other naturally
        - **Clear intent**: Explain WHY each step matters, not just WHAT it does
        - **Specific details**: Provide concrete implementation guidance
        - **TDD approach**: Tests should be listed for each step

        ## Output Format

        Return a JSON object with:
        - `milestones`: Array of milestone objects (required)
        - `constraints`: Array of constraints to follow (optional)
        - `assumptions`: Array of assumptions made (optional)
        - `risks`: Array of identified risks (optional)

        Generate a comprehensive, well-structured plan that breaks down the goal into 
        manageable milestones and actionable steps.
      PROMPT
    end

    def build_user_message
      message = []
      message << "## Goal"
      message << ""
      message << @goal
      message << ""

      if @analysis_results.present?
        message << "## Codebase Analysis Results"
        message << ""

        if @analysis_results[:relevant_files]&.any?
          message << "**Relevant Files:**"
          @analysis_results[:relevant_files].each { |file| message << "- #{file}" }
          message << ""
        end

        if @analysis_results[:patterns]&.any?
          message << "**Patterns to Follow:**"
          @analysis_results[:patterns].each { |pattern| message << "- #{pattern}" }
          message << ""
        end

        if @analysis_results[:constraints]&.any?
          message << "**Constraints:**"
          @analysis_results[:constraints].each { |constraint| message << "- #{constraint}" }
          message << ""
        end

        if @analysis_results[:context]
          message << "**Additional Context:**"
          message << @analysis_results[:context]
          message << ""
        end
      end

      if @context.present?
        message << "## Additional Context"
        message << ""
        message << @context
        message << ""
      end

      message << "## Instructions"
      message << ""
      message << "Generate a detailed execution plan for achieving this goal."
      message << "Break it down into logical milestones and small, testable steps."
      message << "Each step should be completable in a single focused session."
      message << "Follow TDD: specify tests for each step."

      message.join("\n")
    end

    def response_schema
      {
        type: "object",
        properties: {
          milestones: {
            type: "array",
            items: {
              type: "object",
              properties: {
                title: { type: "string" },
                description: { type: "string" },
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
                      estimated_duration: { type: "string" },
                      dependencies: {
                        type: "array",
                        items: { type: "string" }
                      },
                      file_changes: {
                        type: "array",
                        items: { type: "string" }
                      }
                    },
                    required: ["title", "intent", "details", "tests"],
                    additionalProperties: false
                  }
                },
                estimated_duration: { type: "string" },
                success_criteria: {
                  type: "array",
                  items: { type: "string" }
                }
              },
              required: ["title", "description", "steps"],
              additionalProperties: false
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
          }
        },
        required: ["milestones"],
        additionalProperties: false
      }
    end

    # Override execute to use build_user_message
    def execute(prompt: nil, context: nil)
      user_message = build_user_message
      super(prompt: user_message, context: context)
    end

    private

    def validate_parameters!(goal, analysis_results)
      raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
      unless analysis_results.is_a?(Hash)
        raise ArgumentError, "analysis_results must be a Hash, got #{analysis_results.class}"
      end
    end
  end
end

