# frozen_string_literal: true


# Tool to summarize memory sections and extract key items (quests/goals/people).
class MemorySummarizeTool < BaseTool
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
          description: "Target to summarize (defaults to quest_log if not specified)",
          enum: %w[person location quest_log]
        },
        name: {
          type: "string",
          description: "Name of the person or location (required for person/location)"
        },
        path: {
          type: "string",
          description: "Memory file path (optional, defaults to agent data path)"
        }
      },
      required: [],
      additionalProperties: false
    }
  end

  def execute(target: "quest_log", name: nil, path: nil)
    store = MemoryStore.new(path: path || default_file_path)

    case target
    when "person"
      raise ArgumentError, "name required for person summary" if name.to_s.strip.empty?
      entries = Array(store.get_section(MemoryKinds::PEOPLE))
      matches = entries.select { |e| extract_text(e).downcase.include?(name.downcase) }
      success_result({ target: target, name: name, summary: summarize_texts(matches), entries: matches })
    when "location"
      raise ArgumentError, "name required for location summary" if name.to_s.strip.empty?
      scene = store.get_section(MemoryKinds::CURRENT_SCENE)
      scene_text = extract_text(scene)
      match = scene if scene_text.downcase.include?(name.downcase)
      success_result({ target: target, name: name, summary: scene_text, entries: Array(match).compact })
    when "quest_log"
      quests = Array(store.get_section(MemoryKinds::QUEST_LOG))
      success_result({ target: target, summary: summarize_texts(quests), entries: quests })
    else
      error_result("Unsupported target: #{target}")
    end
  rescue ArgumentError => e
    error_result(e.message)
  end

  
  # Extract text from entry - handles both strings and hashes
  def extract_text(entry)
    case entry
    when String
      entry
    when Hash
      entry[:text] || entry["text"] || entry.to_s
    when Array
      entry.map { |e| extract_text(e) }.join(" ")
    else
      entry.to_s
    end
  end

  def summarize_texts(entries)
    texts = Array(entries).map { |e| extract_text(e) }.compact
    texts.join(" ")
  end
end

# Register with ToolCallService
ToolCallService.register_tool(MemorySummarizeTool)
