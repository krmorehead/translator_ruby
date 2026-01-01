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
      validate_params!(name, model_name, port, max_context, base_url)

      @name = name
      @model_name = model_name
      @port = port
      @max_context = max_context
      @base_url = base_url
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
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash" unless hash.is_a?(Hash)

      symbolized = hash.deep_symbolize_keys

      # Convert name to symbol if it's a string
      name = symbolized[:name]
      name = name.to_sym if name.is_a?(String)

      new(
        name: name,
        model_name: symbolized[:model_name],
        port: symbolized[:port],
        max_context: symbolized[:max_context],
        base_url: symbolized[:base_url]
      )
    end

    private

    def validate_params!(name, model_name, port, max_context, base_url)
      # Validate name
      raise ArgumentError, "name must be a Symbol" unless name.is_a?(Symbol)
      raise ArgumentError, "name cannot be empty" if name.to_s.strip.empty?

      # Validate model_name
      raise ArgumentError, "model_name must be a String" unless model_name.is_a?(String)
      raise ArgumentError, "model_name cannot be empty" if model_name.strip.empty?

      # Validate port
      raise ArgumentError, "port must be an Integer" unless port.is_a?(Integer)
      unless port.between?(MIN_PORT, MAX_PORT)
        raise ArgumentError, "port must be between #{MIN_PORT} and #{MAX_PORT}, got #{port}"
      end

      # Validate max_context
      raise ArgumentError, "max_context must be an Integer" unless max_context.is_a?(Integer)
      unless max_context.positive?
        raise ArgumentError, "max_context must be positive, got #{max_context}"
      end

      # Validate base_url
      raise ArgumentError, "base_url must be a String" unless base_url.is_a?(String)
      raise ArgumentError, "base_url cannot be empty" if base_url.strip.empty?
    end
  end
end

