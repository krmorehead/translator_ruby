# frozen_string_literal: true

module Sisyphus
  # Tool for writing files in the Sisyphus execution context.
  # Works within a specific codebase directory.
  class WriteFileTool < BaseTool
    def self.name_identifier
      "write_file"
    end

    def self.description
      "Write content to a file at the specified path (relative to codebase root)"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          path: {
            type: "string",
            description: "The path to the file to write (relative to codebase root)"
          },
          content: {
            type: "string",
            description: "The content to write to the file"
          },
          codebase_path: {
            type: "string",
            description: "The root directory of the codebase (provided by workflow)"
          }
        },
        required: ["path", "content", "codebase_path"]
        # Note: additionalProperties removed to allow graceful handling of unexpected params
      }
    end

    def execute(path:, content:, codebase_path:, **_extra_params)
      # Validate codebase_path exists
      unless File.directory?(codebase_path)
        return error_result("Codebase path does not exist: #{codebase_path}")
      end

      # Build full path
      full_path = File.join(codebase_path, path)

      # Create parent directories first
      dir = File.dirname(full_path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)

      # Ensure we're not writing outside codebase
      real_codebase = File.realpath(codebase_path)
      real_target = File.realpath(dir) # Now dir exists
      unless real_target.start_with?(real_codebase)
        return error_result("Cannot write outside codebase: #{path}")
      end

      # Write file
      File.write(full_path, content)
      
      success_result("Successfully wrote #{content.bytesize} bytes to #{path}").merge(
        full_path: full_path,
        bytes_written: content.bytesize
      )
    rescue StandardError => e
      error_result("Failed to write file: #{e.message}")
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(Sisyphus::WriteFileTool)

