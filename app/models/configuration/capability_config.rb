# frozen_string_literal: true

module Configuration
  # Domain model for an LLM capability configuration.
  # Represents a single capability entry from GenericLlmClient::CAPABILITIES.
  #
  # Follows OOP patterns with strict validation and immutability.
  class CapabilityConfig
    # Valid port range
    MIN_PORT = 1
    MAX_PORT = 65535

    attr_reader :name, :model_name, :port, :max_context, :base_url

    # Initialize a CapabilityConfig
    # @param name [Symbol] The capability name (:general_llm, :tool_calling, etc.)
    # @param model_name [String] The model path or name
    # @param port [Integer] The port number (1-65535)
    # @param max_context [Integer] Maximum context size in tokens
    # @param base_url [String] The base URL or ENV variable name
    def initialize(name:, model_name:, port:, max_context:, base_url:)
      # Business rule validations only
      raise ArgumentError, "name cannot be empty" if name.to_s.strip.empty?
      raise ArgumentError, "model_name cannot be empty" if model_name.strip.empty?
      raise ArgumentError, "port must be between #{MIN_PORT} and #{MAX_PORT}, got #{port}" unless port.between?(MIN_PORT, MAX_PORT)
      raise ArgumentError, "max_context must be positive, got #{max_context}" unless max_context.positive?
      raise ArgumentError, "base_url cannot be empty" if base_url.strip.empty?

      @name = name
      @model_name = model_name
      @port = port
      @max_context = max_context
      @base_url = base_url
    end

    # Alias for model_name (for API compatibility)
    def model
      @model_name
    end

    # Provider extracted from model_name
    # For vLLM models, this returns "vllm"
    def provider
      "vllm" # All current capabilities use vLLM
    end

    # Serialize to hash
    # @return [Hash] Serialized capability configuration
    def to_h
      {
        name: @name,
        model_name: @model_name,
        port: @port,
        max_context: @max_context,
        base_url: @base_url
      }
    end

    # Deserialize from hash
    # @param hash [Hash] Serialized capability configuration
    # @return [CapabilityConfig] New instance
    def self.from_h(name:, model_name:, port:, max_context:, base_url:)
      # Convert name to symbol if it's a string
      name = name.to_sym if name.is_a?(String)

      new(
        name: name,
        model_name: model_name,
        port: port,
        max_context: max_context,
        base_url: base_url
      )
    end
  end
end

