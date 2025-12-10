# frozen_string_literal: true

require "json"
require "openai"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

# Abstract base class for all LLM-backed prompts.
# Subclasses must implement system_prompt and response_schema.
class BasePrompt
  attr_reader :tools

  def initialize(tools: [])
    @tools = tools || []
    @client = default_client
  end

  # Default model comes from the shared LLM_MODEL env var.
  def model
    ENV["LLM_MODEL"].presence
  end

  # Must return a system prompt string.
  BASE_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a helpful assistant. Answer the user directly and succinctly.
    Keep responses clear, focused, and free of extraneous commentary.
  PROMPT

  # Default system prompt provides a sensible chat baseline; subclasses may override.
  def system_prompt
    base_system_prompt
  end

  # Must return a JSON schema hash, or nil for freeform text.
  def response_schema
    raise NotImplementedError, "#{self.class.name} must define #response_schema"
  end

  # Convert a context hash into a string payload for the LLM.
  def format_context(context)
    return "" if context.nil? || context.empty?

    "Context:\n#{JSON.pretty_generate(context)}"
  end

  # Serialize tool schemas for inclusion in prompts.
  def serialize_tools(tool_schemas)
    JSON.pretty_generate(tool_schemas || [])
  end

  # Execute the prompt against the LLM and parse the response.
  # Returns structured JSON when a schema is present, otherwise raw text.
  def execute(prompt:, context: {})
    raise "LLM client not configured" unless @client

    parameters = {
      model: model,
      messages: build_messages(prompt, context)
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

    response = @client.chat(parameters: parameters)
    parse_response(response)
  rescue JSON::ParserError => e
    raise "Failed to parse LLM response as JSON: #{e.message}"
  rescue => e
    raise "LLM prompt execution failed: #{e.message}"
  end

  private

  def base_system_prompt
    BASE_SYSTEM_PROMPT
  end

  def parse_response(response)
    message = response.dig("choices", 0, "message") || {}
    content = message["content"]

    if response_schema
      raise "LLM response missing content" unless content

      JSON.parse(content)
    else
      content.to_s
    end
  end

  def build_messages(prompt, context)
    messages = [{ role: "system", content: system_prompt }]
    formatted_context = format_context(context)
    messages << { role: "user", content: formatted_context } if formatted_context.present?
    messages << { role: "user", content: prompt }
    messages
  end

  def default_client
    client = GenericLlmClient.instance
    raise "LLM client not configured" unless client
    client
  end
end

