# frozen_string_literal: true

module Planning
  # Ultra-minimal prompt for breaking a milestone into steps.
  class StepBreakdownPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        Break milestone into 2-4 steps. Each: title (5 words max), intent (10 words max).
        Be extremely concise.
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          steps: {
            type: "array",
            items: {
              type: "object",
              properties: {
                title: { type: "string", maxLength: 50 },
                intent: { type: "string", maxLength: 100 }
              },
              required: %w[title intent],
              additionalProperties: false
            },
            maxItems: 5
          }
        },
        required: ["steps"],
        additionalProperties: false
      }
    end

    def generate(milestone_title:, milestone_description:, goal:, previous_attempt: nil)
      prompt = "Goal: #{goal.to_s.truncate(50)}\nMilestone: #{milestone_title.to_s.truncate(30)}\nBreak into steps."
      execute(prompt: prompt)
    end
  end
end
