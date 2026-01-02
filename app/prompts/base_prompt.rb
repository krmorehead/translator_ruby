# frozen_string_literal: true

# Error raised when context size exceeds the safe limit
class ContextSizeExceededError < StandardError; end

# Abstract base class for all LLM-backed prompts.
# Subclasses must implement system_prompt and response_schema.
class BasePrompt
  # Approximate characters per token for context size estimation
  CHARS_PER_TOKEN = 4

  def initialize()
    @client = default_client
  end

  # Maximum safe context size in tokens (from ENV, required)
  def max_safe_context
    ENV.fetch("MAX_SAFE_CONTEXT").to_i
  end

  # Default model comes from the general_llm capability.
  # Raises an error if not configured to fail fast with helpful message.
  def model
    GenericLlmClient.model_for(:general_llm)
  rescue ArgumentError => e
    raise_missing_model_error
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

  # Convert a context into a string payload for the LLM.
  # Context objects format themselves completely via format_for_prompt.
  # @param context [Contexts::BaseContext, nil] The context (optional)
  # @param question [String, nil] Optional question for relevance filtering
  # @return [String, nil] Formatted context string or nil
  def format_context(context, question: '')
    return nil if context.nil?
    return nil unless context.respond_to?(:format_for_prompt)
    
    context.format_for_prompt(question)
  end
  # Execute the prompt against the LLM and parse the response.
  # Returns hash with :content (structured JSON or raw text) and :thoughts (extracted reasoning).
  # - For prompts with response_schema: { content: parsed_json_hash, thoughts: thoughts }
  # - For prompts without schema: { content: text_string, thoughts: thoughts }
  def execute(prompt:, context:)
    messages = build_messages(prompt, context)
    validate_context_size!(messages)

    parameters = build_parameters(messages)

    response = @client.chat(parameters: parameters)
    parse_response(response)
  rescue JSON::ParserError => e
    raise "Failed to parse LLM response as JSON: #{e.message}"
  rescue => e
    raise "LLM prompt execution failed: #{e.message}"
  end

  
  def base_system_prompt
    BASE_SYSTEM_PROMPT
  end

  # Build parameters for the LLM API call
  # Subclasses can override to add tools or other parameters
  def build_parameters(messages)
    parameters = {
      model: model,
      messages: messages,
    }.compact

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



  # Validate that the total context size doesn't exceed MAX_SAFE_CONTEXT
  # Raises an error if context is too large to prevent unbounded LLM calls
  def validate_context_size!(messages)
    total_chars = messages.sum { |m| m[:content].to_s.length }
    estimated_tokens = total_chars / CHARS_PER_TOKEN

    if estimated_tokens > max_safe_context
      raise ContextSizeExceededError.new(
        "Context size (#{estimated_tokens} tokens) exceeds MAX_SAFE_CONTEXT (#{max_safe_context} tokens). " \
        "Total characters: #{total_chars}. Reduce context or increase MAX_SAFE_CONTEXT."
      )
    end
  end

  def parse_response(response)
    # Response from GenericLlmClient is now an LlmResponse object
    raise TypeError, "response must be an LlmResponse, got #{response.class}" unless response.is_a?(LlmResponse)
    
    content = response.content
    thoughts = response.thoughts
    finish_reason = response.finish_reason

    parsed_content = if response_schema
      raise "LLM response missing content" unless content
      # Content is JSON string, parse with symbolized keys
      JSON.parse(content, symbolize_names: true)
    else
      content.to_s
    end

    {
      content: parsed_content,
      thoughts: thoughts
    }
  end

  def build_messages(prompt, context)
    messages = [ { role: "system", content: system_prompt } ]
    # Pass the prompt as the question for relevance filtering when context is a Context object
    formatted_context = format_context(context, question: prompt)
    messages << { role: "user", content: formatted_context } if formatted_context.present?
    messages << { role: "user", content: prompt }
    messages
  end

  def default_client
    client = GenericLlmClient.client_for(:general_llm)
    raise "LLM client not configured" unless client
    client
  end

  def raise_missing_model_error
    raise <<~ERROR.squish
      LLM configuration error: Unable to determine model for capability.
      Ensure your .env file is loaded properly with API_KEY and LLM_URL configured
      (check .env for development, .env.test for tests).
    ERROR
  end
end
