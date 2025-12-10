# frozen_string_literal: true

require_relative "base_tool"

# Tool for writing content to files.
# Creates parent directories if they don't exist.
# Validates paths against sandbox if configured.
class WriteFileTool < BaseTool
  def self.name_identifier
    "write_file"
  end

  def self.description
    "Write content to a file at the specified path"
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "The path to the file to write"
        },
        content: {
          type: "string",
          description: "The content to write to the file"
        }
      },
      required: [ "path", "content" ],
      additionalProperties: false
    }
  end

  def execute(path:, content:)
    validate_sandbox_path!(path)

    # Create parent directories if they don't exist
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)

    File.write(path, content)
    success_result("Successfully wrote #{content.bytesize} bytes to #{path}")
  rescue SecurityError => e
    error_result(e.message)
  rescue => e
    error_result("Error writing file: #{e.message}")
  end
end

# Register with ToolCallService
ToolCallService.register_tool(WriteFileTool)
