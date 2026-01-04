# frozen_string_literal: true

module Configuration
  # Domain model for an LLM capability configuration.
  # Follows OpenAI API format for consistency across all APIs.
  #
  # Follows OOP patterns with strict validation and immutability.
  class CapabilityConfig
    # Valid port range
    MIN_PORT = 1
    MAX_PORT = 65535

    attr_reader :name, :model, :provider, :port, :max_context, :base_url

    # Initialize a CapabilityConfig following OpenAI API format
    # @param name [Symbol] The capability name (:general_llm, :tool_calling, etc.)
    # @param model [String] The model path or name (OpenAI API standard field)
    # @param provider [String] The provider name (e.g., "vllm", "openai")
    # @param port [Integer] The port number (1-65535)
    # @param max_context [Integer] Maximum context size in tokens
    # @param base_url [String] The base URL or ENV variable name
    def initialize(name:, model:, provider:, port:, max_context:, base_url:)
      # Business rule validations - fail loudly
      raise ArgumentError, "name cannot be empty" if name.to_s.strip.empty?
      raise ArgumentError, "model cannot be empty" if model.strip.empty?
      raise ArgumentError, "provider cannot be empty" if provider.strip.empty?
      raise ArgumentError, "port must be between #{MIN_PORT} and #{MAX_PORT}, got #{port}" unless port.between?(MIN_PORT, MAX_PORT)
      raise ArgumentError, "max_context must be positive, got #{max_context}" unless max_context.positive?
      raise ArgumentError, "base_url cannot be empty" if base_url.strip.empty?

      @name = name
      @model = model
      @provider = provider
      @port = port
      @max_context = max_context
      @base_url = base_url
    end

    # Serialize to hash (OpenAI API format)
    # @return [Hash] Serialized capability configuration
    def to_h
      {
        name: @name,
        model: @model,
        provider: @provider,
        port: @port,
        max_context: @max_context,
        base_url: @base_url
      }
    end

    # Deserialize from hash (OpenAI API format)
    # @param hash [Hash] Serialized capability configuration
    # @return [CapabilityConfig] New instance
    def self.from_h(name:, model:, provider:, port:, max_context:, base_url:)
      # Convert name to symbol if it's a string
      name = name.to_sym if name.is_a?(String)

      new(
        name: name,
        model: model,
        provider: provider,
        port: port,
        max_context: max_context,
        base_url: base_url
      )
    end
  end
end
