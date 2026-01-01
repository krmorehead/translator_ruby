# frozen_string_literal: true

# Base class for prompts that use tool-calling LLM capability for structured output.
# Inherits from BasePrompt but routes to the tool_calling capability by default.
# 
# The tool_calling capability uses a specific LLM model optimized for structured JSON output.
# This is different from OpenAI-style "function calling" - subclasses may or may not use actual tools.
#
# @example Prompt with tools (ActionDetectionPrompt)
#   prompt = ActionDetectionPrompt.new(tools: [tool1, tool2])
#
# @example Prompt with JSON schema only (FileRelevancePrompt)
#   prompt = FileRelevancePrompt.new
class ToolCallPrompt < BasePrompt
  attr_reader :tools
  
  def initialize(tools: [])
    @tools = Array(tools)
    super()
  end

  # Serialize tools to hash format
  # Following OOP patterns: tools should be proper objects with to_h method
  # @return [Array<Hash>] Tool schemas
  def serialize_tools
    @tools.map(&:to_h)
  end
  
  def model
    GenericLlmClient.model_for(:tool_calling)
  end

  def default_client
    GenericLlmClient.client_for(:tool_calling)
  end

end

