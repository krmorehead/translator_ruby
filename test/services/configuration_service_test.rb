# frozen_string_literal: true

require "test_helper"

class ConfigurationServiceTest < ActiveSupport::TestCase
  def setup
    @service = ConfigurationService.new
  end

  speed_profile :fast
  test "initializes successfully" do
    assert_instance_of ConfigurationService, @service
  end

  # get_current_config tests
  speed_profile :fast
  test "get_current_config returns AgentConfig" do
    config = @service.get_current_config

    assert_instance_of Configuration::AgentConfig, config
  end

  speed_profile :fast
  test "get_current_config includes all capabilities from GenericLlmClient" do
    config = @service.get_current_config

    GenericLlmClient::CAPABILITIES.each_key do |capability_name|
      assert config.capability?(capability_name),
             "Expected config to include capability: #{capability_name}"
    end
  end

  speed_profile :fast
  test "get_current_config capability has correct attributes" do
    config = @service.get_current_config
    capability = config.capability(:general_llm)

    # Following OpenAI API format
    assert_equal :general_llm, capability.name
    assert capability.model.is_a?(String)
    assert capability.provider.is_a?(String)
    assert capability.port.is_a?(Integer)
    assert capability.max_context.is_a?(Integer)
    assert capability.base_url.is_a?(String)
  end

  # get_environment_vars tests
  speed_profile :fast
  test "get_environment_vars returns hash of environment variables" do
    env_vars = @service.get_environment_vars

    assert env_vars.is_a?(Hash)
  end

  speed_profile :fast
  test "get_environment_vars includes expected keys" do
    env_vars = @service.get_environment_vars

    ConfigurationService::ENV_KEYS.each do |key|
      assert env_vars.key?(key), "Expected env_vars to include key: #{key}"
    end
  end

  speed_profile :fast
  test "get_environment_vars masks API_KEY" do
    # Set a test API key
    original_key = ENV["API_KEY"]
    ENV["API_KEY"] = "test_secret_key_12345"

    env_vars = @service.get_environment_vars

    assert_match(/\*\*\*/, env_vars["API_KEY"])
    assert_not_equal "test_secret_key_12345", env_vars["API_KEY"]
  ensure
    ENV["API_KEY"] = original_key
  end

  speed_profile :fast
  test "get_environment_vars does not mask non-secret values" do
    original_timeout = ENV["LLM_REQUEST_TIMEOUT"]
    ENV["LLM_REQUEST_TIMEOUT"] = "120"

    env_vars = @service.get_environment_vars

    assert_equal "120", env_vars["LLM_REQUEST_TIMEOUT"]
  ensure
    ENV["LLM_REQUEST_TIMEOUT"] = original_timeout
  end

  # validate_capability tests
  speed_profile :fast
  test "validate_capability returns valid for correct configuration" do
    # Following OpenAI API format
    config_hash = {
      name: :test_capability,
      model: "test_model",
      provider: "vllm",
      port: 8000,
      max_context: 1000,
      base_url: "TEST_URL"
    }

    result = @service.validate_capability(config_hash)

    assert result[:valid]
    assert_empty result[:errors]
  end

  speed_profile :fast
  test "validate_capability returns errors for invalid port" do
    # Following OpenAI API format
    config_hash = {
      name: :test,
      model: "model",
      provider: "vllm",
      port: 70000,
      max_context: 1000,
      base_url: "url"
    }

    result = @service.validate_capability(config_hash)

    assert_not result[:valid]
    assert result[:errors].any?
    assert result[:errors].first.include?("port")
  end

  speed_profile :fast
  test "validate_capability returns errors for missing required fields" do
    config_hash = {
      name: :test,
      model_name: "model"
      # missing port, max_context, base_url
    }

    result = @service.validate_capability(config_hash)

    assert_not result[:valid]
    assert result[:errors].any?
  end

  # test_connection tests
  speed_profile :medium
  test "test_connection returns success for valid capability" do
    result = @service.test_connection(:general_llm)

    assert result[:success]
    assert result[:message].include?("general_llm")
    assert result[:details]
    assert_equal :general_llm, result[:details][:capability]
  end

  speed_profile :fast
  test "test_connection returns error for unknown capability" do
    result = @service.test_connection(:unknown_capability)

    assert_not result[:success]
    assert result[:message].include?("Unknown capability")
    assert_nil result[:details]
  end

  speed_profile :medium
  test "test_connection includes client and model details" do
    result = @service.test_connection(:general_llm)

    if result[:success]
      assert result[:details][:model]
      assert result[:details][:client_type]
    end
  end

  # Private method tests (testing through public interface)
  speed_profile :fast
  test "masks secrets correctly" do
    # Test through get_environment_vars
    original_key = ENV["API_KEY"]
    ENV["API_KEY"] = "short"

    env_vars = @service.get_environment_vars

    assert_equal "***", env_vars["API_KEY"]
  ensure
    ENV["API_KEY"] = original_key
  end

  speed_profile :fast
  test "masks long secrets showing first and last characters" do
    original_key = ENV["API_KEY"]
    ENV["API_KEY"] = "verylongsecretkey123"

    env_vars = @service.get_environment_vars

    assert_match(/^ver\*\*\*123$/, env_vars["API_KEY"])
  ensure
    ENV["API_KEY"] = original_key
  end
end

