# frozen_string_literal: true

module Planning
  # Ultra-minimal validation prompt.
  class ValidationPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        Check plan for: duplicates, missing pieces, order issues. Be brief.
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          valid: { type: "boolean" },
          issues: {
            type: "array",
            items: { type: "string", maxLength: 100 },
            maxItems: 5
          },
          suggestions: {
            type: "array",
            items: { type: "string", maxLength: 100 },
            maxItems: 3
          }
        },
        required: %w[valid issues suggestions],
        additionalProperties: false
      }
    end

    def validate(goal:, milestones:)
      # Build ultra-compact summary
      lines = ["Goal: #{goal.to_s.truncate(50)}"]
      milestones.each_with_index do |m, i|
        title = (m["title"] || m[:title]).to_s.truncate(20)
        step_count = (m["steps"] || m[:steps] || []).size
        lines << "M#{i + 1}: #{title} (#{step_count} steps)"
      end
      lines << "Valid?"

      execute(prompt: lines.join("\n"))
    end
  end
end
