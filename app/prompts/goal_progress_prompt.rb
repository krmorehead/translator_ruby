# frozen_string_literal: true

# Prompt to evaluate progress toward a goal.
# Used by the agent to determine if the goal has been achieved
# or if more work is needed.
class GoalProgressPrompt < BasePrompt
  def system_prompt
    <<~PROMPT
      You are evaluating whether a research goal has been achieved based on the
      current findings and context.

      ## Evaluation Criteria

      1. **Completeness**: Have all aspects of the goal been addressed?
      2. **Confidence**: Are the findings supported by evidence from the codebase?
      3. **Clarity**: Is there enough information to provide a clear answer?
      4. **Coverage**: Have relevant files and code paths been examined?

      ## Guidelines

      - Be honest about what is known vs. unknown
      - Consider if additional investigation would add meaningful value
      - A goal can be "achieved" even if not every detail is known, as long as
        the core question is answered
      - If stuck in a loop without progress, recommend stopping

      ## Response Format

      Return a JSON object with:
      - goal_achieved: Boolean indicating if the goal is sufficiently answered
      - confidence: Float (0.0-1.0) indicating confidence in the assessment
      - summary: Brief summary of what has been learned
      - unknown_aspects: Array of aspects that remain unclear (if any)
      - recommendation: "continue", "stop", or "synthesize"
    PROMPT
  end

  def response_schema
    {
      type: "object",
      properties: {
        goal_achieved: {
          type: "boolean",
          description: "Whether the goal has been sufficiently achieved"
        },
        confidence: {
          type: "number",
          description: "Confidence in this assessment (0.0-1.0)"
        },
        summary: {
          type: "string",
          description: "Brief summary of what has been learned"
        },
        unknown_aspects: {
          type: "array",
          items: { type: "string" },
          description: "Aspects that remain unclear"
        },
        recommendation: {
          type: "string",
          enum: ["continue", "stop", "synthesize"],
          description: "Recommended next step"
        },
        progress_percentage: {
          type: "number",
          description: "Estimated progress toward goal (0-100)"
        }
      },
      required: ["goal_achieved", "confidence", "summary", "recommendation"],
      additionalProperties: false
    }
  end

  def format_context(context, question: nil)
    context.format_for_prompt(question)
  end

  # Convenience method to check if goal is achieved
  # @param goal [String] The goal to evaluate
  # @param context [Contexts::BaseContext] Current context with findings
  # @return [Hash] Evaluation result
  def evaluate(goal:, context:)
    result = execute(prompt: goal, context: context)
    result[:content]
  end
end
