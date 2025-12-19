# frozen_string_literal: true


# Tool for reading file contents.
# Validates paths against sandbox if configured.
class ReadFileTool < BaseTool
  def self.name_identifier
    "read_file"
  end

  def self.description
    "Read the contents of a file at the specified path"
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "The path to the file to read"
        }
      },
      required: [ "path" ],
      additionalProperties: false
    }
  end

  def execute(path:)
    unless File.exist?(path)
      return error_result("File not found: #{path}")
    end

    content = File.read(path)
    success_result(content)
  end
end

# Register with ToolCallService
ToolCallService.register_tool(ReadFileTool)
