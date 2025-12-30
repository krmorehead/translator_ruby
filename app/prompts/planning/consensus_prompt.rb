# frozen_string_literal: true

module Planning
  # Ultra-minimal consensus check prompt.
  class ConsensusPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        Compare proposals. Output merged list. Max 4 items. Each: title (5 words), description (10 words).
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          agreed: { type: "boolean" },
          items: {
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
          },
          reason: { type: "string", maxLength: 100 }
        },
        required: %w[agreed items reason],
        additionalProperties: false
      }
    end

    def check(proposals:, context:)
      # Build ultra-compact prompt
      lines = ["Merge these #{context}:"]
      proposals.each_with_index do |proposal, i|
        items = proposal.first(3).map do |item|
          title = (item["title"] || item[:title]).to_s.truncate(20)
          "#{title}"
        end
        lines << "P#{i + 1}: #{items.join(', ')}"
      end
      
      execute(prompt: lines.join("\n"))
    end
  end
end
