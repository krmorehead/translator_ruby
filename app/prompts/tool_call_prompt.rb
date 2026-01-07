# frozen_string_literal: true

# Base class for prompts that use OpenAI-style tool calling.
# Inherits from BasePrompt but routes to the tool_calling capability by default.
# 
# The tool_calling capability uses vLLM with --enable-auto-tool-choice flag.
# Tools are sent in OpenAI function calling format.
#
# @example Prompt with tools
#   prompt = DaedalusChatPrompt.new(tools: [file_tree_tool, grep_tool])
#
class ToolCallPrompt < BasePrompt
  attr_reader :tools
  
  def initialize(tools: [])
    @tools = Array(tools)
    super()
  end

  # Serialize tools to OpenAI function calling format
  # Following OOP patterns: tools should be proper objects with to_h method
  # @return [Array<Hash>] Tool schemas in OpenAI format
  def serialize_tools
    @tools.map(&:to_h)
  end
  
  # Override build_parameters to include tools for OpenAI function calling
  # @param messages [Array<Hash>] Message array
  # @return [Hash] Parameters with tools included
  def build_parameters(messages)
    parameters = super(messages)
    
    # Add tools - LLM will return tools in Hermes XML format in content
    parameters[:tools] = serialize_tools
    
    parameters
  end
  
  # Execute with multi-turn tool calling loop
  # Subclasses must implement:
  #   - build_messages_with_history: Build message history
  #   - execute_tool(name, args): Execute a tool and return result
  # @param user_message [String] User's message
  # @param max_iterations [Integer] Maximum tool calling iterations
  # @return [Hash] Final response with :content, :tool_calls
  def execute_with_tools(user_message:, max_iterations: 20)
    tool_calls_log = []
    iteration = 0
    
    # Build initial messages
    messages = build_messages_with_history
    messages << { role: "user", content: user_message }
    
    loop do
      iteration += 1
      break if iteration > max_iterations
      
      # Build parameters and call LLM
      parameters = build_parameters(messages)
      response = @client.chat(parameters: parameters, response_type: response_type)
      
      # Parse Hermes XML tool calls from content if present
      tool_calls = parse_tool_calls_from_response(response)
      
      if tool_calls.any?
        # Execute each tool call
        tool_calls.each do |tool_call|
          function = tool_call[:function]
          tool_name = function[:name]
          arguments_json = function[:arguments]
          tool_id = tool_call[:id]
          
          # Parse arguments
          tool_args = JSON.parse(arguments_json, symbolize_names: true)
          
          # Log the tool call
          tool_calls_log << {
            id: tool_id,
            name: tool_name,
            arguments: tool_args
          }
          
          # Execute tool (subclass implements this)
          tool_result = execute_tool(tool_name, tool_args)
          
          # Add assistant message with tool call
          messages << {
            role: "assistant",
            content: "",
            tool_calls: [tool_call]
          }
          
          # Add tool result
          messages << {
            role: "tool",
            tool_call_id: tool_id,
            content: format_tool_result(tool_result)
          }
        end
        
        # Continue loop for next LLM response
        next
      else
        # No more tool calls, return final response
        return {
          content: response.content || "",
          tool_calls: tool_calls_log
        }
      end
    end
    
    # Max iterations reached
    {
      content: "I've reached the maximum number of tool calls. Please try breaking down your request.",
      tool_calls: tool_calls_log
    }
  end
  
  # Execute a tool by name with arguments
  # Subclasses must override this to execute their specific tools
  # @param name [String] Tool name
  # @param args [Hash] Tool arguments (symbolized keys)
  # @return [String, Hash] Tool result
  def execute_tool(name, args)
    raise NotImplementedError, "#{self.class.name} must implement #execute_tool"
  end
  
  # Format tool result for LLM consumption
  # @param result [Hash, String] Tool execution result
  # @return [String] Formatted result string
  def format_tool_result(result)
    if result.is_a?(Hash)
      if result[:success]
        result[:result].to_s
      else
        "Error: #{result[:error]}"
      end
    else
      result.to_s
    end
  end
  
  # Parse tool calls from response (handles both OpenAI format and Hermes XML)
  # @param response [LlmResponse] LLM response
  # @return [Array<Hash>] Tool calls in OpenAI format with symbolized keys
  def parse_tool_calls_from_response(response)
    # Check for OpenAI structured tool_calls first
    return response.tool_calls if response.has_tool_calls?
    
    # Parse Hermes XML from content
    return [] unless response.has_content?
    parse_hermes_xml_tools(response.content)
  end
  
  # Parse Hermes XML tool calls from content
  # Handles both <tools>...</tools> XML and ```json...``` markdown formats
  # @param content [String] Response content with tool calls
  # @return [Array<Hash>] Parsed tool calls in OpenAI format
  def parse_hermes_xml_tools(content)
    tool_calls = []
    
    # Format 1: Extract <tools>...</tools> blocks
    content.scan(/<tools>\s*(\{.+?\})\s*<\/tools>/m).each do |match|
      tool_calls << parse_tool_json(match[0])
    end
    
    # Format 2: Extract ```json...``` markdown code blocks with function call syntax
    content.scan(/```json\s*(\{[^`]+\})\s*```/m).each do |match|
      tool_calls << parse_tool_json(match[0])
    end
    
    tool_calls.compact
  end
  
  # Parse tool JSON string to OpenAI format
  # @param json_str [String] JSON string with name and arguments
  # @return [Hash, nil] Tool call in OpenAI format or nil if parse fails
  def parse_tool_json(json_str)
    parsed = JSON.parse(json_str, symbolize_names: true)
    
    # Convert to OpenAI format
    {
      id: SecureRandom.uuid,
      type: "function",
      function: {
        name: parsed[:name],
        arguments: JSON.generate(parsed[:arguments] || {})
      }
    }
  rescue JSON::ParserError => e
    Rails.logger.warn "[ToolCallPrompt] Failed to parse tool JSON: #{e.message}"
    nil
  end
  
  def model
    GenericLlmClient.model_for(:tool_calling)
  end

  def default_client
    GenericLlmClient.client_for(:tool_calling)
  end
end

