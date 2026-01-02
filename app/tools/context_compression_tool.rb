# frozen_string_literal: true


# Tool that compresses all memory sections using each memory's summarize/weight.
class ContextCompressionTool < BaseTool
  NAME = "context_compress".freeze

  def self.name_identifier
    NAME
  end

  def self.description
    "Summarize all memory sections with weights to produce an overall compressed context."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        owner_id: {
          type: "string",
          description: "Owner ID for the memory store (required)"
        }
      },
      required: ["owner_id"],
      additionalProperties: false
    }
  end

  def execute(owner_id:)
    store = MemoryStore.new(owner_id: owner_id)

    summaries = Memories::Registry::ALL.map do |klass|
      summary = klass.summarize(store: store)
      weight = klass.weight
      {
        section: summary[:section],
        summary: summary[:summary].to_s,
        weight: weight
      }
    end

    overall_summary = summaries.sort_by { |s| -s[:weight].to_f }.map do |s|
      "#{s[:section]} (w=#{s[:weight]}): #{s[:summary]}"
    end.join("\n")

    success_result({
      overall_summary: overall_summary,
      sections: summaries
    })
  end
end
# Register with ToolCallService
ToolCallService.register_tool(ContextCompressionTool)
