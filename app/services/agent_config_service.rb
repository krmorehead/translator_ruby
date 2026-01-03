# frozen_string_literal: true

# Service for managing agent configuration.
# Handles reading current LLM configuration from GenericLlmClient
# and validating configuration updates.
#
# Follows service object pattern - no controller logic.
class AgentConfigService
  # Get current agent configuration
  # @return [Configuration::AgentConfig] Current configuration
  def self.get_config
    capabilities = build_capabilities_from_client
    environment = build_environment_info

    Configuration::AgentConfig.new(
      capabilities: capabilities,
      environment: environment
    )
  end

  # Validate a configuration update
  # @param capabilities [Hash] Hash of capability_name => capability_hash
  # @return [Hash] Validation result { valid: true/false, errors: [] }
  def self.validate_config(capabilities:)
    errors = []

    capabilities.each do |name, config_hash|
      begin
        # Attempt to build CapabilityConfig (will validate)
        Configuration::CapabilityConfig.from_h(
          name: name,
          **config_hash.symbolize_keys
        )
      rescue ArgumentError => e
        errors << "#{name}: #{e.message}"
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # Test connection to an LLM endpoint
  # @param capability_name [Symbol, String] The capability to test
  # @return [Hash] Test result { success: true/false, error: nil/string }
  def self.test_connection(capability_name)
    capability_name = capability_name.to_sym

    unless GenericLlmClient::CAPABILITIES.key?(capability_name)
      return {
        success: false,
        error: "Unknown capability: #{capability_name}"
      }
    end

    # Try to get client and make a minimal test call
    client = GenericLlmClient.client_for(capability_name)
    
    # Make a simple test request
    test_params = {
      model: GenericLlmClient.model_for(capability_name),
      messages: [
        { role: "user", content: "test" }
      ],
      max_tokens: 5
    }

    client.chat(parameters: test_params, response_type: LlmResponse)
    
    {
      success: true,
      error: nil
    }
  rescue StandardError => e
    {
      success: false,
      error: e.message
    }
  end

  # Build capabilities hash from GenericLlmClient
  # @return [Hash<Symbol, Configuration::CapabilityConfig>]
  def self.build_capabilities_from_client
    GenericLlmClient::CAPABILITIES.transform_values do |config|
      Configuration::CapabilityConfig.new(
        name: config[:model_name].split("/").last.to_sym,
        model_name: config[:model_name],
        port: config[:port],
        max_context: config[:max_context],
        base_url: config[:base_url]
      )
    end
  end
  private_class_method :build_capabilities_from_client

  # Build environment info (with secrets masked)
  # @return [Hash] Environment variables safe for frontend
  def self.build_environment_info
    {
      llm_url: mask_secret(ENV["LLM_URL"]),
      llm_retry: ENV.fetch("LLM_RETRY", "1"),
      llm_retry_delay: ENV.fetch("LLM_RETRY_DELAY", "50"),
      llm_request_timeout: ENV.fetch("LLM_REQUEST_TIMEOUT", "60"),
      rails_env: Rails.env
    }
  end
  private_class_method :build_environment_info

  # Mask secrets for display (show only last 4 chars)
  # @param value [String, nil] Value to mask
  # @return [String, nil] Masked value or nil
  def self.mask_secret(value)
    return nil if value.nil?
    return value if value.length < 8

    "***" + value[-4..]
  end
  private_class_method :mask_secret
end


