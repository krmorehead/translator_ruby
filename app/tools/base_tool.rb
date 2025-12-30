# frozen_string_literal: true

# Abstract base class for all tools that can be called by the LLM.
# Subclasses must implement the schema class method and execute instance method.
class BaseTool
  # Default base path for agent data storage
  # Override with AGENT_DATA_PATH env var
  DEFAULT_DATA_PATH = ".agents/memories"

  # Base tool config for OpenAI tool calling
  def self.tool_choice
    "auto"
  end

  def self.tools
    [ schema ]
  end

  # Base path for agent data - use env var or default
  def self.data_path
    ENV.fetch("AGENT_DATA_PATH", DEFAULT_DATA_PATH)
  end

  # Default file path for this tool's data
  def self.default_file_path
    File.join(data_path, "#{name_identifier}.json")
  end

  def initialize
  end

  # Returns the OpenAI function calling schema for this tool.
  # Must be overridden by subclasses.
  def self.schema
    {
      type: "function",
      function: {
        name: name_identifier,
        description: description,
        parameters: parameters_schema
      }
    }
  end

  # Returns the tool name identifier (e.g., "read_file")
  def self.name_identifier
    raise NotImplementedError, "#{name} must implement .name_identifier"
  end

  # Returns the tool description for the LLM
  def self.description
    raise NotImplementedError, "#{name} must implement .description"
  end

  # Returns the JSON schema for parameters
  def self.parameters_schema
    raise NotImplementedError, "#{name} must implement .parameters_schema"
  end

  # Executes the tool with the given arguments.
  # Must be overridden by subclasses.
  # Returns a hash with { success: bool, result: string, error: string }
  def execute(**args)
    raise NotImplementedError, "#{self.class.name} must implement #execute"
  end

  # Instance method to access data path
  def data_path
    self.class.data_path
  end

  # Instance method to access default file path
  def default_file_path
    self.class.default_file_path
  end

  
  # Builds a success result hash
  def success_result(result)
    { success: true, result: result, error: nil }
  end

  # Builds an error result hash
  def error_result(error)
    { success: false, result: nil, error: error }
  end
end
