# frozen_string_literal: true

module Sisyphus
  # Tool for executing bash commands in the Sisyphus execution context.
  # Runs commands within a specific codebase directory.
  class BashTool < BaseTool
    def self.name_identifier
      "bash"
    end

    def self.description
      "Execute a bash command in the codebase directory"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "The bash command to execute"
          },
          codebase_path: {
            type: "string",
            description: "The root directory of the codebase (provided by workflow)"
          }
        },
        required: ["command", "codebase_path"]
        # Note: additionalProperties removed to allow graceful handling of unexpected params
      }
    end

    def execute(command:, codebase_path:, **_extra_params)
      # Validate codebase_path exists
      unless File.directory?(codebase_path)
        return error_result("Codebase path does not exist: #{codebase_path}")
      end

      # Execute command in the codebase directory
      stdout, stderr, status = Open3.capture3(command, chdir: codebase_path)

      if status.success?
        success_result(stdout).merge(
          exit_status: status.exitstatus,
          stderr: stderr
        )
      else
        error_result(stderr.empty? ? "Command failed with exit status #{status.exitstatus}" : stderr).merge(
          exit_status: status.exitstatus,
          stdout: stdout
        )
      end
    rescue StandardError => e
      error_result("Error executing command: #{e.message}")
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(Sisyphus::BashTool)

