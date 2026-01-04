# frozen_string_literal: true

# Service for managing GenericLlmClient configuration.
# Provides read access to current configuration and validation
# for configuration changes.
#
# This service follows OOP patterns and provides a clean interface
# for configuration management without exposing internal details.
class ConfigurationService
  # LLM-related environment variable keys
  ENV_KEYS = %w[
    LLM_URL
    API_KEY
    LLM_REQUEST_TIMEOUT
    LLM_RETRY
    LLM_RETRY_DELAY
    MAX_SAFE_CONTEXT
  ].freeze

  # Get current agent configuration
  # @return [Configuration::AgentConfig] Current configuration
  def get_current_config
    capabilities = build_capabilities_from_generic_client
    environment = get_environment_vars

    Configuration::AgentConfig.new(
      capabilities: capabilities,
      environment: environment
    )
  end

  # Get environment variables (with secrets masked)
  # @return [Hash] Environment variables with secrets masked
  def get_environment_vars
    env_vars = {}

    ENV_KEYS.each do |key|
      value = ENV[key]
      
      # Mask API keys and sensitive values
      if key.include?("KEY") || key.include?("SECRET") || key.include?("PASSWORD")
        env_vars[key] = value ? mask_secret(value) : nil
      else
        env_vars[key] = value
      end
    end

    env_vars
  end

  # Validate a capability configuration
  # @param config_hash [Hash] Capability configuration to validate
  # @return [Hash] Validation result {valid:, errors:}
  def validate_capability(config_hash)
    Configuration::CapabilityConfig.from_h(**config_hash)
    { valid: true, errors: [] }
  rescue ArgumentError, TypeError => e
    { valid: false, errors: [e.message] }
  end

  # Test connection to an LLM endpoint
  # @param capability [Symbol] Capability name to test
  # @return [Hash] Test result {success:, message:, details:}
  def test_connection(capability)
    unless GenericLlmClient::CAPABILITIES.key?(capability)
      return {
        success: false,
        message: "Unknown capability: #{capability}",
        details: nil
      }
    end

    begin
      # Try to get the client for this capability
      client = GenericLlmClient.client_for(capability)
      model = GenericLlmClient.model_for(capability)

      {
        success: true,
        message: "Successfully connected to #{capability}",
        details: {
          capability: capability,
          model: model,
          client_type: client.class.name
        }
      }
    rescue StandardError => e
      {
        success: false,
        message: "Connection failed: #{e.message}",
        details: {
          capability: capability,
          error_type: e.class.name
        }
      }
    end
  end

  private

  # Build capabilities hash from GenericLlmClient
  # Following OpenAI API format
  # @return [Hash] Hash of capability_name => CapabilityConfig
  def build_capabilities_from_generic_client
    capabilities = {}

    GenericLlmClient::CAPABILITIES.each do |name, config|
      capabilities[name] = Configuration::CapabilityConfig.new(
        name: name,
        model: config[:model_name],  # OpenAI API format
        provider: "vllm",  # All current capabilities use vLLM
        port: config[:port],
        max_context: config[:max_context],
        base_url: config[:base_url]
      )
    end

    capabilities
  end

  # Mask a secret value
  # @param value [String] Secret to mask
  # @return [String] Masked secret
  def mask_secret(value)
    return nil if value.nil?
    return "***" if value.length < 8

    # Show first 3 and last 3 characters
    "#{value[0..2]}***#{value[-3..-1]}"
  end
end

