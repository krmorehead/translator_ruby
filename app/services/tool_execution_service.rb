# frozen_string_literal: true

# Service for executing existing tools from the API layer.
# Wraps FileTreeTool, ReadFileTool, and GrepTool to provide
# a consistent interface for the SisyphusController.
#
# This service follows the OOP pattern of wrapping existing
# functionality rather than duplicating it.
class ToolExecutionService
  # Map of tool names to tool classes
  TOOL_MAP = {
    file_tree: FileTreeTool,
    read_file: ReadFileTool,
    grep: GrepTool
  }.freeze

  # Execute a tool by name with given parameters
  # @param tool_name [Symbol] The tool to execute (:file_tree, :read_file, :grep)
  # @param params [Hash] Parameters to pass to the tool
  # @return [Hash] Standardized result {success:, data:, error:}
  def execute_tool(tool_name:, params:)
    unless tool_name.is_a?(Symbol)
      return error_response("tool_name must be a Symbol")
    end

    unless params.is_a?(Hash)
      return error_response("params must be a Hash")
    end

    tool_class = TOOL_MAP[tool_name]
    unless tool_class
      return error_response("Unknown tool: #{tool_name}")
    end

    tool = tool_class.new
    result = tool.execute(**params.symbolize_keys)

    standardize_response(result)
  rescue ArgumentError => e
    error_response("Invalid parameters: #{e.message}")
  rescue StandardError => e
    error_response("Tool execution failed: #{e.message}")
  end

  # List directory using FileTreeTool
  # @param path [String] Directory path to list
  # @param options [Hash] Optional parameters (max_depth, extensions, ignore_patterns)
  # @return [Hash] Standardized result with directory tree
  def list_directory(path:, options: {})
    unless path.is_a?(String)
      return error_response("path must be a String")
    end
    
    unless options.is_a?(Hash)
      return error_response("options must be a Hash")
    end

    params = { path: path }.merge(options.symbolize_keys)
    execute_tool(tool_name: :file_tree, params: params)
  end

  # Read file using ReadFileTool
  # @param path [String] File path to read
  # @return [Hash] Standardized result with file content
  def read_file(path:)
    unless path.is_a?(String)
      return error_response("path must be a String")
    end

    execute_tool(tool_name: :read_file, params: { path: path })
  end

  # Search files using GrepTool
  # @param path [String] Directory or file to search
  # @param pattern [String] Search pattern (regex)
  # @param options [Hash] Optional parameters (extensions, max_results, etc.)
  # @return [Hash] Standardized result with search matches
  def search_files(path:, pattern:, options: {})
    unless path.is_a?(String)
      return error_response("path must be a String")
    end
    
    unless pattern.is_a?(String)
      return error_response("pattern must be a String")
    end
    
    unless options.is_a?(Hash)
      return error_response("options must be a Hash")
    end

    params = { path: path, pattern: pattern }.merge(options.symbolize_keys)
    execute_tool(tool_name: :grep, params: params)
  end

  private

  # Standardize tool result into consistent format
  # @param result [Hash] Tool result
  # @return [Hash] Standardized response
  def standardize_response(result)
    if result[:success]
      {
        success: true,
        data: result[:result] || result,
        error: nil
      }
    else
      {
        success: false,
        data: nil,
        error: result[:error] || "Unknown error"
      }
    end
  end

  # Create error response
  # @param message [String] Error message
  # @return [Hash] Error response
  def error_response(message)
    {
      success: false,
      data: nil,
      error: message
    }
  end
end

