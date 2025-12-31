# frozen_string_literal: true

# Prompt for condensing information while preserving key context
# Used to create concise summaries for LLM input
class SummarizePrompt < BasePrompt
  def system_prompt
    <<~PROMPT
      You will be given content to summarize.
      
      Create a concise summary that:
      1. Retains all critical information
      2. Removes redundant details
      伪. Uses clear, direct language
      4. Maintains proper context for LLM processing
      
      Return only the summary text in a single string.
    PROMPT
  end

  def response_schema
    {
      type: "object",
      properties: {
        summary: { type: "string" }
      },
      required: [:summary],
      additionalProperties: false
    }
  end

  def format_context(context)
    <<~CONTEXT
      Content to summarize: #{context}
    CONTEXT
  end
end
