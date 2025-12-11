# frozen_string_literal: true


# Tool that compresses all memory sections using each memory's summarize/weight.
class ContextCompressionTool < BaseTool
  DEFAULT_FILENAME = "memory.json"
  PATH = File.join("tmp", "dnd_chat_sandbox", DEFAULT_FILENAME)
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
        path: {
          type: "string",
          description: "Optional memory file path (defaults to sandbox/memory.json)",
          nullable: true
        }
      },
      required: [],
      additionalProperties: false
    }
  end

  def execute(path: nil)
    store = MemoryStore.new(path: resolve_path(path), sandbox_path: sandbox_path)

    summaries = Memories::Registry::ALL.map do |klass|
      summary = klass.summarize(store: store) rescue { section: klass.section_name, summary: "" }
      weight = klass.weight rescue 1.0
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
  rescue => e
    error_result("Context compression error: #{e.message}")
  end

  private

  def resolve_path(path)
    return PATH if path.nil? || path.to_s.strip.empty?

    path
  end
end
# Register with ToolCallService
ToolCallService.register_tool(ContextCompressionTool)
