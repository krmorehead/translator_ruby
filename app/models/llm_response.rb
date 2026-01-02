# frozen_string_literal: true

# Domain object representing an LLM API response.
# Provides structured access to response data instead of raw hashes.
#
# @example Accessing response content
#   response = LlmResponse.new(raw_response)
#   response.content        # => "The actual response"
#   response.thoughts       # => "Internal reasoning" or nil
#   response.id             # => "chatcmpl-123"
#   response.model          # => "gpt-4"
#
class LlmResponse
  attr_reader :id, :model, :created, :content, :thoughts, :raw

  # Initialize a new LlmResponse from LLM API response hash
  #
  # @param response [Hash] The raw response from LLM API (with symbol keys)
  # @raise [TypeError] If response is not a Hash
  def initialize(response)
    raise TypeError, "response must be a Hash, got #{response.class}" unless response.is_a?(Hash)
    
    @raw = response.deep_symbolize_keys
    @id = response[:id]
    @model = response[:model]
    @created = response[:created]
    
    # Extract message content from choices array
    message = response.dig(:choices, 0, :message)
    @content = message ? message[:content] : nil
    @thoughts = response[:thoughts]
    
    freeze
  end

  # Check if response has thoughts/reasoning
  # @return [Boolean] True if thoughts are present
  def has_thoughts?
    !@thoughts.nil? && !@thoughts.empty?
  end

  # Get the full message hash (for compatibility)
  # @return [Hash, nil] The message hash or nil
  def message
    @raw.dig(:choices, 0, :message)
  end

  # Get finish reason
  # @return [String, nil] The finish reason
  def finish_reason
    @raw.dig(:choices, 0, :finish_reason)
  end

  # Check if response was completed successfully
  # @return [Boolean] True if finish_reason is "stop"
  def complete?
    finish_reason == "stop"
  end

  # Get usage statistics
  # @return [Hash, nil] Usage hash with token counts
  def usage
    @raw[:usage]
  end

  # Convert to hash with content and thoughts
  # Content is returned as-is (string)
  # @return [Hash] Hash with :content and :thoughts
  def to_h
    {
      content: @content,
      thoughts: @thoughts
    }
  end
end

