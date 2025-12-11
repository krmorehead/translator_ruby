# frozen_string_literal: true


# Tool to summarize memory sections and extract key items (quests/goals/people).
class MemorySummarizeTool < BaseTool
  DEFAULT_FILENAME = "memory.json"
  PATH = File.join("tmp", "dnd_chat_sandbox", DEFAULT_FILENAME)
  NAME = "memory_summarize".freeze

  def self.name_identifier
    NAME
  end

  def self.description
    "Summarize a specific memory target: person, location, or quest_log."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Target to summarize",
          enum: %w[person location quest_log]
        },
        name: {
          type: "string",
          description: "Name of the person or location (required for person/location)"
        },
        path: {
          type: "string",
          description: "Optional memory file path (defaults to sandbox/memory.json)",
          nullable: true
        }
      },
      required: [ "target" ],
      additionalProperties: false
    }
  end

  def execute(target:, name: nil, path: nil)
    store = MemoryStore.new(path: resolve_path(path), sandbox_path: sandbox_path)

    case target
    when "person"
      raise ArgumentError, "name required for person summary" if name.to_s.strip.empty?
      entries = store.get_section(MemoryKinds::PEOPLE) || []
      matches = entries.select { |e| (e[:text] || e["text"]).to_s.downcase.include?(name.downcase) }
      success_result({ target: target, name: name, summary: summarize_texts(matches), entries: matches })
    when "location"
      raise ArgumentError, "name required for location summary" if name.to_s.strip.empty?
      scene = store.get_section(MemoryKinds::CURRENT_SCENE)
      match = scene if scene.to_s.downcase.include?(name.downcase)
      success_result({ target: target, name: name, summary: match.to_s, entries: Array(match).compact })
    when "quest_log"
      quests = store.get_section(MemoryKinds::QUEST_LOG) || []
      success_result({ target: target, summary: summarize_texts(quests), entries: quests })
    else
      error_result("Unsupported target: #{target}")
    end
  rescue SecurityError => e
    error_result(e.message)
  rescue ArgumentError => e
    error_result(e.message)
  rescue => e
    error_result("Memory summarize error: #{e.message}")
  end

  private

  def resolve_path(path)
    return PATH if path.nil? || path.to_s.strip.empty?

    path
  end

  def build_summary(texts, max_tokens)
    return "" if texts.empty?

    summary = texts.join(" ")
    return summary if max_tokens.nil? || max_tokens <= 0

    summary.split(//).take(max_tokens).join
  end

  def summarize_texts(entries)
    texts = Array(entries).map { |e| e.is_a?(Hash) ? (e[:text] || e["text"]) : e }.compact
    texts.join(" ")
  end
end

# Register with ToolCallService
ToolCallService.register_tool(MemorySummarizeTool)
