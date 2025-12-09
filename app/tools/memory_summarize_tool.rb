# frozen_string_literal: true

require_relative "base_tool"
require_relative "../models/memory_store"
require_relative "../models/memory_kinds"
require_relative "../services/tool_call_service"

# Tool to summarize memory sections and extract key items (quests/goals/people).
class MemorySummarizeTool < BaseTool
  DEFAULT_FILENAME = "memory.json"
  NAME = "memory_summarize".freeze

  def self.name_identifier
    NAME
  end

  def self.description
    "Summarize selected memory sections and extract key quests/goals/people."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        sections: {
          type: "array",
          description: "Section names to summarize",
          items: { type: "string" },
          minItems: 1
        },
        path: {
          type: "string",
          description: "Optional memory file path (defaults to sandbox/memory.json)",
          nullable: true
        },
        max_tokens: {
          type: "integer",
          description: "Optional maximum tokens/length for summary",
          nullable: true
        }
      },
      required: ["sections"],
      additionalProperties: false
    }
  end

  def execute(sections:, path: nil, max_tokens: nil, file_path: nil)
    store_path = resolve_path(path || file_path)
    store = MemoryStore.new(path: store_path, sandbox_path: sandbox_path)

    section_syms = Array(sections).map(&:to_sym)
    contents = section_syms.map { |s| store.get_section(s) || [] }
    texts = contents.flatten.map { |entry| entry[:text] || entry["text"] }.compact

    summary = build_summary(texts, max_tokens)
    key_points = extract_key_points(store, section_syms)

    success_result({ summary: summary, key_points: key_points })
  rescue SecurityError => e
    error_result(e.message)
  rescue ArgumentError => e
    error_result(e.message)
  rescue => e
    error_result("Memory summarize error: #{e.message}")
  end

  private

  def resolve_path(path)
    if path.nil? || path.strip.empty?
      raise ArgumentError, "sandbox_path required when no path provided" unless sandbox_path
      File.join(sandbox_path, DEFAULT_FILENAME)
    else
      path
    end
  end

  def build_summary(texts, max_tokens)
    return "" if texts.empty?

    summary = texts.join(" ")
    return summary if max_tokens.nil? || max_tokens <= 0

    summary.split(//).take(max_tokens).join
  end

  def extract_key_points(store, section_syms)
    quests = section_syms.include?(:quests) ? (store.get_section(:quests) || []).map { |e| e[:text] || e["text"] }.compact : []
    goals = section_syms.include?(:current_goal) ? (store.get_section(:current_goal) || []).map { |e| e[:text] || e["text"] }.compact : []
    people = section_syms.include?(:people) ? (store.get_section(:people) || []).map { |e| e[:text] || e["text"] }.compact : []

    {
      quests: quests,
      goals: goals,
      people: people
    }
  end
end

# Register with ToolCallService
ToolCallService.register_tool(MemorySummarizeTool)
