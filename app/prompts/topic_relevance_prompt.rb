# frozen_string_literal: true

# Prompt for evaluating context entries relevance to a specific topic
# Sorts entries by relevance (high/medium/low) and returns them in that order
class TopicRelevancePrompt < BasePrompt
  def system_prompt
    <<~PROMPT
      You will be given an array of context entries and a topic.
      
      For each entry, determine its relevance to the topic using these criteria:
      1. Direct mention of the topic in content or metadata
      2. Semantic connection to the topic
      3. Recency of the entry
      4. Importance of the entry in the context

      Assign each entry one of these relevance scores:
      - high: Directly addresses the topic
      - medium: Indirectly related but still relevant
      - low: Marginally related or tangential

      Return entries sorted by relevance score in this format:
      {
        high: [entry_ids...],
        medium: [entry_ids...],
        low: [entry_ids...]
      }
    PROMPT
  end

  def response_schema
    {
      type: "object",
      properties: {
        high: { type: "array", items: { type: "string" } },
        medium: { type: "array", items: { type: "string" } },
        low: { type: "array", items: { type: "string" } }
      },
      required: %i[high medium low],
      additionalProperties: false
    }
  end

  def format_context(context, question: nil)
    entries = context.all_entries
    topic = question

    entry_data = entries.map do |entry|
      {
        id: entry.id,
        content: entry.content,
        topics: entry.topics,
        source: entry.source,
        timestamp: entry.timestamp,
        metadata: entry.metadata
      }
    end

    <<~CONTEXT
      Topic: #{topic}
      Entries: #{entry_data.to_json}
    CONTEXT
  end
end
