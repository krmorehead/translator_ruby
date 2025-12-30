# frozen_string_literal: true

module Planning
  # Ultra-minimal prompt for step details.
  class StepDetailPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        Provide 2-3 details and 2 test cases for this step.
        Each item: max 15 words. Be extremely concise.
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          details: {
            type: "array",
            items: { type: "string", maxLength: 150 },
            maxItems: 4
          },
          tests: {
            type: "array",
            items: { type: "string", maxLength: 150 },
            maxItems: 3
          }
        },
        required: %w[details tests],
        additionalProperties: false
      }
    end

    def generate(step_title:, step_intent:, milestone_title:, goal:)
      prompt = "Step: #{step_title.to_s.truncate(30)}\nIntent: #{step_intent.to_s.truncate(40)}\nProvide details and tests."
      execute(prompt: prompt)
    end
  end
end
