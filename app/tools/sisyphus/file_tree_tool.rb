# frozen_string_literal: true

module Sisyphus
  # Tool for exploring directory structure in the Sisyphus execution context.
  # Wraps FileTreeTool with Sisyphus-specific path handling.
  class FileTreeTool < BaseTool
    def self.name_identifier
      "file_tree"
    end

    def self.description
      "List directory structure and files in the codebase"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          path: {
            type: "string",
            description: "Specific directory to explore (optional, relative to codebase root). Defaults to root."
          },
          codebase_path: {
            type: "string",
            description: "The root directory of the codebase (provided by workflow)"
          },
          max_depth: {
            type: "integer",
            description: "Maximum depth to traverse (default: 10)"
          },
          extensions: {
            type: "array",
            items: { type: "string" },
            description: "File extensions to include (e.g., ['rb', 'py'])"
          }
        },
        required: ["codebase_path"]
        # Note: additionalProperties removed to allow graceful handling of unexpected params
      }
    end

    def execute(codebase_path:, path: nil, max_depth: 10, extensions: nil, **_extra_params)
      # Validate codebase_path exists
      unless File.directory?(codebase_path)
        return error_result("Codebase path does not exist: #{codebase_path}")
      end

      # Determine exploration path (default to codebase root if no path specified)
      explore_path = path ? File.join(codebase_path, path) : codebase_path

      # Validate exploration path exists
      unless File.exist?(explore_path)
        return error_result("Path does not exist: #{path || '.'}")
      end

      # Use the generic FileTreeTool to do the actual tree building
      file_tree_tool = ::FileTreeTool.new
      result = file_tree_tool.execute(
        path: explore_path,
        max_depth: max_depth,
        extensions: extensions
      )

      # Return the result as-is (it's already in the correct format)
      result
    rescue StandardError => e
      error_result("Failed to explore directory: #{e.message}")
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(Sisyphus::FileTreeTool)

