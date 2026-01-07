# frozen_string_literal: true

module Sisyphus
  # Tool for searching file contents in the Sisyphus execution context.
  # Wraps GrepTool with Sisyphus-specific path handling.
  class GrepTool < BaseTool
    def self.name_identifier
      "grep"
    end

    def self.description
      "Search file contents for patterns in the codebase"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          pattern: {
            type: "string",
            description: "The regex pattern to search for"
          },
          path: {
            type: "string",
            description: "Specific path to search in (optional, relative to codebase root)"
          },
          codebase_path: {
            type: "string",
            description: "The root directory of the codebase (provided by workflow)"
          },
          extensions: {
            type: "array",
            items: { type: "string" },
            description: "File extensions to search (e.g., ['rb', 'py'])"
          },
          max_results: {
            type: "integer",
            description: "Maximum number of results to return (default: 100)"
          },
          case_insensitive: {
            type: "boolean",
            description: "Enable case-insensitive matching (default: false)"
          }
        },
        required: ["pattern", "codebase_path"]
        # Note: additionalProperties removed to allow graceful handling of unexpected params
      }
    end

    def execute(pattern:, codebase_path:, path: nil, extensions: nil, max_results: 100, case_insensitive: false, **_extra_params)
      # Validate codebase_path exists
      unless File.directory?(codebase_path)
        return error_result("Codebase path does not exist: #{codebase_path}")
      end

      # Determine search path (default to codebase root if no path specified)
      search_path = path ? File.join(codebase_path, path) : codebase_path

      # Validate search path exists
      unless File.exist?(search_path)
        return error_result("Search path does not exist: #{path || '.'}")
      end

      # Use the generic GrepTool to do the actual search
      grep_tool = ::GrepTool.new
      result = grep_tool.execute(
        pattern: pattern,
        path: search_path,
        extensions: extensions,
        max_results: max_results,
        case_insensitive: case_insensitive
      )

      # Return the result as-is (it's already in the correct format)
      result
    rescue StandardError => e
      error_result("Failed to search files: #{e.message}")
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(Sisyphus::GrepTool)

