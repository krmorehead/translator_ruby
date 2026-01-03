# frozen_string_literal: true

# LLM response that parses JSON content automatically.
# Used when prompts specify a response_schema.
#
# @example Creating from LlmResponse
#   base_response = LlmResponse.new(raw_hash)
#   json_response = LlmJsonResponse.new(base_response)
#   json_response.to_h  # => { content: {...parsed json...}, thoughts: "..." }
#
class LlmJsonResponse < LlmResponse
  # Initialize from an existing LlmResponse
  # @param base_response [LlmResponse] The base response to wrap
  def initialize(base_response)
    raise TypeError, "base_response must be an LlmResponse, got #{base_response.class}" unless base_response.is_a?(LlmResponse)
    
    # Copy all instance variables from base response
    @raw = base_response.raw
    @id = base_response.id
    @model = base_response.model
    @created = base_response.created
    @content = base_response.content
    @thoughts = base_response.thoughts
    
    freeze
  end

  # Convert to hash with JSON-parsed content
  # @return [Hash] Hash with :content (parsed JSON hash) and :thoughts
  def to_h
    raise "LLM response missing content for JSON parsing" unless @content
    
    {
      content: JSON.parse(@content, symbolize_names: true),
      thoughts: @thoughts
    }
  end
end








