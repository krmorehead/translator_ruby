# frozen_string_literal: true

module Planning
  # Prompt for refining individual plan steps based on feedback or additional context.
  # Enables iterative plan improvement (future feature).
  class StepRefinementPrompt < BasePrompt
    attr_reader :step, :feedback, :context

    # @param step [PlanStep] The step to refine
    # @param feedback [String] Feedback or suggestions for improvement
    # @param context [String, nil] Optional additional context
    def initialize(step:, feedback:, context: nil)
      validate_parameters!(step, feedback)

      @step = step
      @feedback = feedback
      @context = context
      super()
    end

    def system_prompt
      <<~PROMPT
        You are an expert software architect and project planner. Your role is to refine 
        execution plan steps based on feedback and suggestions.

        ## Your Task

        You will be given:
        1. An existing plan step with its current details
        2. Feedback or suggestions for improving the step
        3. Optional additional context

        Your job is to refine the step by:
        - Incorporating the feedback while maintaining the step's original intent
        - Adding more specific implementation details if requested
        - Clarifying test requirements if needed
        - Ensuring the step remains small, testable, and incremental
        - Keeping the step focused on a single responsibility

        ## Step Structure

        Each step must have:
        - **title**: Clear, concise title (should generally stay the same)
        - **intent**: What this step accomplishes and why (may be refined)
        - **details**: Array of specific implementation details (often expanded)
        - **tests**: Array of test requirements (may be clarified/expanded)

        ## Output Format

        Return a JSON object with the refined step matching the PlanStep structure:
        ```json
        {
          "title": "Step title",
          "intent": "What this step accomplishes and why",
          "details": [
            "Specific implementation detail 1",
            "Specific implementation detail 2"
          ],
          "tests": [
            "Test requirement 1",
            "Test requirement 2"
          ]
        }
        ```

        ## Guidelines

        - Maintain the step's core purpose and title
        - Add specificity based on feedback
        - Keep details actionable and concrete
        - Ensure tests are specific and verifiable
        - Don't expand scope beyond the original intent
      PROMPT
    end

    def build_user_message
      message = []
      message << "## Current Step"
      message << ""
      message << "**Title**: #{@step.title}"
      message << ""
      message << "**Intent**: #{@step.intent}"
      message << ""
      message << "**Details**:"
      @step.details.each { |detail| message << "- #{detail}" }
      message << ""
      message << "**Tests**:"
      @step.tests.each { |test| message << "- #{test}" }
      message << ""

      message << "## Feedback"
      message << ""
      message << @feedback
      message << ""

      if @context.present?
        message << "## Additional Context"
        message << ""
        message << @context
        message << ""
      end

      message << "## Instructions"
      message << ""
      message << "Refine this step by incorporating the feedback above."
      message << "Keep the step small, testable, and focused."
      message << "Maintain the original intent while adding specificity where needed."

      message.join("\n")
    end

    def response_schema
      {
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
          }
        },
        required: ["title", "intent", "details", "tests"],
        additionalProperties: false
      }
    end

    # Override execute to use build_user_message
    def execute(prompt: nil, context: nil)
      user_message = build_user_message
      super(prompt: user_message, context: context)
    end

    private

    def validate_parameters!(step, feedback)
      unless step.is_a?(PlanStep)
        raise ArgumentError, "step must be a PlanStep, got #{step.class}"
      end
      raise ArgumentError, "feedback must be a String, got #{feedback.class}" unless feedback.is_a?(String)
    end
  end
end








