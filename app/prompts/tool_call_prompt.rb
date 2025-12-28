# frozen_string_literal: true

# Base class for prompts that use tool-calling LLM for structured action selection.
# Inherits from BasePrompt but routes to the tool_calling capability by default.
# Provides execute_with_general_llm for scenarios requiring more complex reasoning.
class ToolCallPrompt < BasePrompt
  # Default fallback values if not configured in CAPABILITIES
  TOOL_CALL_MAX_CONTEXT = 1500
  # Max response tokens for tool-calling (reserve room for input)
  TOOL_CALL_MAX_RESPONSE = 1500

  # Returns the model name for tool calling capability
  def model
    GenericLlmClient.model_for(:tool_calling)
  end

  # Override max context for tool-calling models (read from capability config)
  def max_safe_context
    config = GenericLlmClient::CAPABILITIES[:tool_calling]
    config[:max_context] || TOOL_CALL_MAX_CONTEXT
  end

  # Override max response tokens for tool-calling (reserve room for input)
  def max_response_tokens
    # Use about 25% of max context for response, rest for input
    ENV.fetch("TOOL_CALL_MAX_RESPONSE", max_safe_context / 4).to_i
  end

  # Compact tool serialization for smaller context window
  # Format: "- name: description (param1*: type, param2: type)"
  # * indicates required parameters
  def serialize_tools(tool_schemas)
    return "" if tool_schemas.nil? || tool_schemas.empty?

    tool_schemas.map do |tool|
      func = tool[:function] || tool["function"]
      next unless func

      name = func[:name] || func["name"]
      desc = func[:description] || func["description"]
      params_schema = func[:parameters] || func["parameters"] || {}
      properties = params_schema[:properties] || params_schema["properties"] || {}
      required = params_schema[:required] || params_schema["required"] || []

      params = properties.map do |param_name, config|
        type = config[:type] || config["type"] || "any"
        req_marker = required.include?(param_name.to_s) ? "*" : ""
        "#{param_name}#{req_marker}: #{type}"
      end.join(", ")

      "- #{name}: #{desc} (#{params})"
    end.compact.join("\n")
  end

  # Execute the prompt, optionally overriding the capability
  # @param prompt [String] The user prompt
  # @param context [Object] The context (BaseContext or Hash)
  # @param model_override [Symbol, nil] Capability to use instead (:general_llm, etc.)
  # @return [Hash] Result with :content and :thoughts keys
  def execute(prompt:, context:, model_override: nil)
    if model_override
      execute_with_capability(model_override, prompt: prompt, context: context)
    else
      super(prompt: prompt, context: context)
    end
  end

  private

  # Execute with a specific capability
  def execute_with_capability(capability, prompt:, context:)
    client = GenericLlmClient.client_for(capability)
    raise "LLM client not configured for #{capability}" unless client

    messages = build_messages(prompt, context)
    validate_context_size!(messages)

    parameters = build_parameters_for_capability(capability, messages)

    response = client.chat(parameters: parameters)
    parse_response(response)
  rescue JSON::ParserError => e
    raise "Failed to parse LLM response as JSON: #{e.message}"
  rescue => e
    raise "LLM prompt execution failed: #{e.message}"
  end

  def build_parameters_for_capability(capability, messages)
    parameters = {
      model: GenericLlmClient.model_for(capability),
      messages: messages,
      max_tokens: max_response_tokens
    }

    if response_schema
      parameters[:response_format] = {
        type: "json_schema",
        json_schema: {
          name: self.class.name.demodulize.underscore,
          strict: true,
          schema: response_schema
        }
      }
    end

    parameters
  end

  # Use tool_calling client by default
  def default_client
    client = GenericLlmClient.client_for(:tool_calling)
    raise "LLM client not configured" unless client
    client
  end
end

