# frozen_string_literal: true

require_relative "base_tool"
require_relative "../models/memory_store"
require_relative "../models/memory_kinds"
require_relative "../services/tool_call_service"

# LLM-callable tool to read/update memory sections.
class MemoryTool < BaseTool
  DEFAULT_FILENAME = "memory.json"
  NAME = "memory".freeze
  OP_LIST = "list_sections".freeze
  OP_GET = "get_section".freeze
  OP_UPDATE = "update_section".freeze
  ALLOWED_SECTIONS = MemoryKinds::ALL
  ERR_SECTION_REQUIRED = "section required".freeze

  def self.name_identifier
    NAME
  end

  def self.description
    "Read or update narrative memory sections (recent conversation, quests, etc.)."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        operation: {
          type: "string",
          description: "Operation to perform",
          enum: [
            OP_GET,
            OP_UPDATE,
            OP_LIST
          ]
        },
        path: {
          type: "string",
          description: "Optional memory file path (defaults to sandbox/memory.json)",
          nullable: true
        },
        section: { type: "string", description: "Section name", nullable: true },
        content: { description: "Content to store (string or object)", nullable: true },
        append: { type: "boolean", description: "Append (true) or replace (false) for update", nullable: true }
      },
      required: ["operation"],
      additionalProperties: false
    }
  end

  def execute(operation:, path: nil, section: nil, content: nil, append: true)
    op, store_path, normalized = normalize_args(operation, path, section, content, append)
    store = MemoryStore.new(path: store_path, sandbox_path: sandbox_path)

    case op
    when OP_LIST
      success_result(store.list_sections)
    when OP_GET
      section = normalized[:section]
      return error_result(ERR_SECTION_REQUIRED) unless valid_section?(section)
      success_result(store.get_section(section))
    when OP_UPDATE
      return error_result(ERR_SECTION_REQUIRED) unless valid_section?(normalized[:section])
      raise ArgumentError, "content required" if normalized[:content].nil?
      updated = store.update_section(name: normalized[:section], content: normalized[:content], append: normalized[:append] != false)
      success_result({ section: normalized[:section], content: updated })
    else
      error_result("Unsupported operation: #{op}")
    end
  rescue SecurityError => e
    error_result(e.message)
  rescue ArgumentError => e
    error_result(e.message)
  rescue => e
    error_result("Memory error: #{e.message}")
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

  def ensure_section!(section)
    raise ArgumentError, ERR_SECTION_REQUIRED if section.to_s.strip.empty?
  end

  def normalize_args(operation, path, section, content, append)
    op = operation || OP_UPDATE
    op = OP_UPDATE if op == "update"
    op = OP_GET if op == "get"
    op = OP_LIST if op == "list"

    store_path = resolve_path(path)

    normalized_section = normalize_section(section)

    content_val = content
    if content.is_a?(Hash) && content.key?(:value)
      content_val = content[:value]
    elsif content.is_a?(Hash) && content.key?("value")
      content_val = content["value"]
    end

    {
      operation: op,
      section: normalized_section,
      content: content_val || content,
      append: append
    }.yield_self do |norm|
      [op, store_path, norm]
    end
  end

  def normalize_section(section)
    return nil if section.nil?
    sec = section
    sec = sec[:key] if sec.is_a?(Hash) && sec.key?(:key)
    sec = sec["key"] if sec.is_a?(Hash) && sec.key?("key")
    sec.to_s.strip.empty? ? nil : sec.to_s
  end

  def valid_section?(section)
    return false if section.nil? || section.to_s.strip.empty?
    ALLOWED_SECTIONS.include?(section.to_s)
  end
end

# Register with ToolCallService
ToolCallService.register_tool(MemoryTool)
