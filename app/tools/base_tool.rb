# frozen_string_literal: true

# Abstract base class for all tools that can be called by the LLM.
# Subclasses must implement the schema class method and execute instance method.
class BaseTool
  attr_reader :sandbox_path

  def initialize(sandbox_path: nil)
    @sandbox_path = sandbox_path
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

  protected

  # Builds a success result hash
  def success_result(result)
    { success: true, result: result, error: nil }
  end

  # Builds an error result hash
  def error_result(error)
    { success: false, result: nil, error: error }
  end

  # Validates that a path is within the sandbox (if sandbox is configured)
  def validate_sandbox_path!(path)
    return true unless sandbox_path

    expanded_path = File.expand_path(path)
    expanded_sandbox = File.expand_path(sandbox_path)

    unless expanded_path.start_with?(expanded_sandbox)
      raise SecurityError, "Path '#{path}' is outside the sandbox '#{sandbox_path}'"
    end

    true
  end
end

