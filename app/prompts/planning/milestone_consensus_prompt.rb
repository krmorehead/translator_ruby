# frozen_string_literal: true

module Planning
  # Ultra-minimal prompt for generating milestones.
  # Strict limits to avoid truncation.
  class MilestoneConsensusPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        Generate 3-4 milestones. Each: title (5 words max), description (10 words max).
        Be extremely concise. No implementation details.
      PROMPT
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
                title: { type: "string", maxLength: 50 },
                description: { type: "string", maxLength: 100 }
              },
              required: %w[title description],
              additionalProperties: false
            },
            maxItems: 5
          }
        },
        required: ["milestones"],
        additionalProperties: false
      }
    end

    def generate(goal:, research_summary:, previous_attempt: nil)
      # Truncate research summary to avoid context overflow
      summary = research_summary.to_s.truncate(200)
      
      prompt = "Goal: #{goal.truncate(100)}"
      prompt += "\nContext: #{summary}" if summary.present?
      prompt += "\nGenerate milestones."

      execute(prompt: prompt)
    end
  end
end
