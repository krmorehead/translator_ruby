# frozen_string_literal: true


# LLM-callable tool to read/update memory sections.
class MemoryTool < BaseTool
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
        owner_id: {
          type: "string",
          description: "Owner ID for the memory store (required)"
        },
        section: { type: "string", description: "Section name" },
        content: {
          description: "Content to store (string or object)",
          type: [ "string", "object", "array", "number", "boolean", "null" ]
        },
        append: { type: "boolean", description: "Append (true) or replace (false) for update" }
      },
      required: [ "operation", "owner_id" ],
      additionalProperties: false
    }
  end

  def execute(operation:, section: nil, content: nil, append: true, owner_id:)
    op, normalized = normalize_args(operation, section, content, append)
    store = MemoryStore.new(owner_id: owner_id)

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
  rescue ArgumentError => e
    error_result(e.message)
  end

  
  def normalize_args(operation, section, content, append)
    op = operation || OP_UPDATE
    op = OP_UPDATE if op == "update" || op == "write"
    op = OP_GET if op == "get"
    op = OP_LIST if op == "list"

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
      content: content_val || content || "",
      append: append
    }.yield_self do |norm|
      [ op, norm ]
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
