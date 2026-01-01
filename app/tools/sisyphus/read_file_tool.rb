# frozen_string_literal: true

module Sisyphus
  # Tool for reading files in the Sisyphus execution context.
  # Reads files from a specific codebase directory.
  class ReadFileTool < BaseTool
    def self.name_identifier
      "read_file"
    end

    def self.description
      "Read a file from the codebase"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          path: {
            type: "string",
            description: "The path to the file to read (relative to codebase root)"
          },
          codebase_path: {
            type: "string",
            description: "The root directory of the codebase (provided by workflow)"
          }
        },
        required: ["path", "codebase_path"],
        additionalProperties: false
      }
    end

    def execute(path:, codebase_path:)
      # Validate codebase_path exists
      unless File.directory?(codebase_path)
        return error_result("Codebase path does not exist: #{codebase_path}")
      end

      # Build full path
      full_path = File.join(codebase_path, path)

      # Check file exists
      unless File.exist?(full_path)
        return error_result("File does not exist: #{path}")
      end

      # Read file
      content = File.read(full_path)
      
      success_result(content).merge(
        path: path,
        full_path: full_path,
        size: content.bytesize,
        lines: content.lines.count
      )
    rescue StandardError => e
      error_result("Failed to read file: #{e.message}")
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(Sisyphus::ReadFileTool)

