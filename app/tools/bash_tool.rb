# frozen_string_literal: true

require_relative "base_tool"
require "open3"

# Tool for executing bash commands.
# Captures stdout, stderr, and exit status.
class BashTool < BaseTool
  def self.name_identifier
    "bash"
  end

  def self.description
    "Execute a bash command and return the output"
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        command: {
          type: "string",
          description: "The bash command to execute"
        }
      },
      required: ["command"],
      additionalProperties: false
    }
  end

  def execute(command:)
    stdout, stderr, status = Open3.capture3(command)

    if status.success?
      success_result(stdout).merge(exit_status: status.exitstatus)
    else
      error_result(stderr.empty? ? "Command failed with exit status #{status.exitstatus}" : stderr)
        .merge(exit_status: status.exitstatus, stdout: stdout)
    end
  rescue => e
    error_result("Error executing command: #{e.message}")
  end
end

# Register with ToolCallService
ToolCallService.register_tool(BashTool)

