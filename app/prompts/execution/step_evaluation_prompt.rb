# frozen_string_literal: true

module Execution
  # Prompt that evaluates whether a step was completed successfully.
  # Provides quality gates with confidence scoring.
  #
  # @example Basic usage
  #   prompt = Execution::StepEvaluationPrompt.new(
  #     step: plan_step,
  #     step_result: execution_result,
  #     context: { codebase_path: "/code" }
  #   )
  class StepEvaluationPrompt < BasePrompt
    attr_reader :step, :step_result, :context

    # @param step [Planning::Step] The step that was executed
    # @param step_result [Hash] The execution result
    # @param context [Hash] Execution context
    def initialize(step:, step_result:, context:)
      validate_parameters!(step, step_result, context)
      
      @step = step
      @step_result = step_result
      @context = context
      
      super()
    end

    def system_prompt
      <<~PROMPT
        You are evaluating whether a plan step was completed successfully.

        Your goal is to assess if the step's objectives were met based on the execution results.

        ## Evaluation Criteria

        ### Tests Satisfied?
        - Were all test requirements met?
        - Did tests pass (if run)?
        - Are edge cases handled?

        ### Requirements Met?
        - Were all step details implemented?
        - Does the code match the intent?
        - Are acceptance criteria satisfied?

        ### Files Modified Correctly?
        - Were the right files changed?
        - Are changes syntactically correct?
        - Do changes follow codebase conventions?

        ### Quality Acceptable?
        - Is error handling present?
        - Are edge cases considered?
        - Is the code maintainable?
        - Are there any obvious bugs?

        ## Confidence Scoring

        Rate your confidence in the evaluation (0.0 to 1.0):
        - 0.0-0.3: Low confidence, significant concerns
        - 0.4-0.6: Medium confidence, some concerns
        - 0.7-0.9: High confidence, minor concerns
        - 1.0: Complete confidence, perfect execution

        ## Response Format

        Return a JSON object with:
        - `passed`: boolean (whether step passed evaluation)
        - `confidence`: number (0.0 to 1.0, your confidence in this assessment)
        - `feedback`: string (explanation of the evaluation)
        - `missing_requirements`: array of strings (unmet requirements)
        - `concerns`: array of strings (issues or potential problems)
        - `should_retry`: boolean (whether step should be retried)
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          passed: {
            type: "boolean",
            description: "Whether the step passed evaluation"
          },
          confidence: {
            type: "number",
            minimum: 0.0,
            maximum: 1.0,
            description: "Confidence in this assessment (0.0 to 1.0)"
          },
          feedback: {
            type: "string",
            description: "Explanation of the evaluation"
          },
          missing_requirements: {
            type: "array",
            items: { type: "string" },
            description: "Requirements that were not met"
          },
          concerns: {
            type: "array",
            items: { type: "string" },
            description: "Issues or potential problems"
          },
          should_retry: {
            type: "boolean",
            description: "Whether the step should be retried"
          }
        },
        required: ["passed", "confidence", "feedback", "missing_requirements", "concerns", "should_retry"],
        additionalProperties: false
      }
    end

    def build_user_message
      message = []
      
      message << "## Step That Was Executed"
      message << ""
      message << "**Step #{@step.number}**: #{@step.title}"
      message << ""
      message << "**Intent**: #{@step.intent}"
      message << ""
      message << "**Details**:"
      @step.details.each { |detail| message << "- #{detail}" }
      message << ""
      message << "**Tests/Acceptance Criteria**:"
      @step.tests.each { |test| message << "- #{test}" }
      
      message << ""
      message << "## Execution Results"
      message << ""
      message << "**Success**: #{@step_result[:success]}"
      
      if @step_result[:actions_taken]
        message << "**Actions Taken**: #{@step_result[:actions_taken].size}"
      end
      
      if @step_result[:files_changed]
        message << "**Files Changed**: #{@step_result[:files_changed].size}"
        @step_result[:files_changed].each { |file| message << "  - #{file}" }
      end
      
      if @step_result[:diffs]
        message << ""
        message << "**Diffs Generated**:"
        @step_result[:diffs].each do |file, diff|
          message << ""
          message << "#{file}:"
          message << "```"
          message << diff.lines.take(20).join  # First 20 lines
          message << "```"
        end
      end
      
      if @step_result[:tool_outputs]
        message << ""
        message << "**Tool Outputs**:"
        @step_result[:tool_outputs].each do |key, output|
          message << "  - #{key}: #{output.to_s.lines.first&.strip}"
        end
      end
      
      if @step_result[:error_message]
        message << ""
        message << "**Error**: #{@step_result[:error_message]}"
      end
      
      message << ""
      message << "## Your Task"
      message << ""
      message << "Evaluate whether this step was completed successfully."
      message << "Check if all requirements were met and provide confidence scoring."
      
      message.join("\n")
    end

    private

    def validate_parameters!(step, step_result, context)
      unless step.is_a?(Planning::Step)
        raise TypeError, "step must be a Planning::Step, got #{step.class}"
      end

      unless step_result.is_a?(Hash)
        raise TypeError, "step_result must be a Hash"
      end

      unless context.is_a?(Hash)
        raise ArgumentError, "context must be a Hash"
      end
    end
  end
end

