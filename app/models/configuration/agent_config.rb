# frozen_string_literal: true

module Configuration
  # Domain model for complete agent configuration.
  # Aggregates all LLM capabilities and environment variables.
  #
  # Follows OOP patterns with strict validation.
  class AgentConfig
    attr_reader :capabilities, :environment

    # Initialize an AgentConfig
    # @param capabilities [Hash] Hash of capability_name => CapabilityConfig
    # @param environment [Hash] Hash of environment variables (secrets masked)
    def initialize(capabilities:, environment:)
      @capabilities = capabilities
      @environment = environment
    end

    # Get capability by name
    # @param name [Symbol] Capability name
    # @return [CapabilityConfig, nil] The capability or nil if not found
    def capability(name)
      @capabilities[name]
    end

    # Get all capability names
    # @return [Array<Symbol>] Array of capability names
    def capability_names
      @capabilities.keys
    end

    # Check if capability exists
    # @param name [Symbol] Capability name
    # @return [Boolean] True if capability exists
    def capability?(name)
      @capabilities.key?(name)
    end

    # Serialize to hash
    # @return [Hash] Serialized agent configuration
    def to_h
      {
        capabilities: @capabilities.transform_values(&:to_h),
        environment: @environment
      }
    end

    # Deserialize from hash
    # @param capabilities [Hash] Hash of capability_name => capability_hash
    # @param environment [Hash] Hash of environment variables
    # @return [AgentConfig] New instance
    def self.from_h(capabilities:, environment:)
      capabilities_objects = capabilities.transform_keys(&:to_sym).transform_values do |cap_hash|
        CapabilityConfig.from_h(**cap_hash)
      end

      new(
        capabilities: capabilities_objects,
        environment: environment
      )
    end
  end
end

