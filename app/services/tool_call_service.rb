# frozen_string_literal: true

require_relative "../tools/base_tool"

# Service that orchestrates tool registration and execution.
# Provides a central interface for the LLM to discover and execute tools.
class ToolCallService
  attr_reader :sandbox_path

  # Registry of all available tool classes
  TOOL_CLASSES = []

  def self.register_tool(tool_class)
    TOOL_CLASSES << tool_class unless TOOL_CLASSES.include?(tool_class)
  end

  def self.available_tools
    TOOL_CLASSES.map(&:schema)
  end

  def self.tool_class_for(name)
    TOOL_CLASSES.find { |klass| klass.name_identifier == name }
  end

  def initialize(sandbox_path: nil)
    @sandbox_path = sandbox_path
  end

  # Execute a tool by name with the given arguments
  # @param tool_name [String] The name of the tool to execute
  # @param arguments [Hash] The arguments to pass to the tool
  # @return [Hash] Result hash with success, result, and error keys
  def execute(tool_name:, arguments:)
    tool_class = self.class.tool_class_for(tool_name)

    raise ArgumentError, "Unknown tool: #{tool_name}" unless tool_class

    tool = tool_class.new(sandbox_path: sandbox_path)
    tool.execute(**arguments.transform_keys(&:to_sym))
  end
end

