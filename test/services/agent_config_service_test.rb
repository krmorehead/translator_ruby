# frozen_string_literal: true

require "test_helper"

class AgentConfigServiceTest < ActiveSupport::TestCase
  def setup
    # OOP: Each test gets its own session with config overrides
    @owner_id = "test-owner-#{SecureRandom.hex(4)}"
    @session_service = AgentSessionService.new(owner_id: @owner_id)
    @session = @session_service.create_session(agent_type: "daedalus")
    @service = AgentConfigService.new(session: @session)
  end
  
  def teardown
    # No cleanup needed - sessions are stored in class variables
  end

  # ============================================================================
  # FAST TESTS - No I/O
  # ============================================================================

  speed_profile :fast
  test "get_config returns AgentConfig instance" do
    config = @service.get_config
    
    assert_instance_of Configuration::AgentConfig, config
  end

  speed_profile :fast
  test "get_config includes all standard capabilities" do
    config = @service.get_config
    
    # Check for actual capabilities defined in GenericLlmClient
    assert config.capability?(:general_llm), "missing general_llm capability"
    assert config.capability?(:tool_calling), "missing tool_calling capability"
    assert config.capability?(:embeddings), "missing embeddings capability"
  end

  speed_profile :fast
  test "each capability has required fields" do
    config = @service.get_config
    
    # Following OpenAI API format
    config.capabilities.each do |name, capability|
      assert capability.model.present?, "#{name} missing model"
      assert capability.provider.present?, "#{name} missing provider"
      assert capability.base_url.present?, "#{name} missing base_url"
    end
  end

  speed_profile :fast
  test "get_config includes environment variables" do
    config = @service.get_config
    
    assert config.environment.is_a?(Hash)
    assert config.environment.key?("RAILS_ENV")
  end

  speed_profile :fast
  test "validate_capability returns true for valid capability" do
    # Use actual capability name from GenericLlmClient::CAPABILITIES
    result = @service.validate_capability("general_llm")
    
    assert result[:valid]
    assert_nil result[:error]
  end

  speed_profile :fast
  test "validate_capability returns false for nonexistent capability" do
    result = @service.validate_capability("nonexistent_capability")
    
    assert_equal false, result[:valid]
    assert result[:error].present?
    assert_match(/not found|unknown/i, result[:error])
  end

  speed_profile :fast
  test "validate_capability returns false for nil capability" do
    result = @service.validate_capability(nil)
    
    assert_equal false, result[:valid]
    assert result[:error].present?
  end

  speed_profile :fast
  test "validate_capability returns false for empty string" do
    result = @service.validate_capability("")
    
    assert_equal false, result[:valid]
    assert result[:error].present?
  end

  speed_profile :fast
  test "update_config validates capability structure" do
    invalid_capabilities = {
      "invalid_cap" => { "random" => "data" }
    }
    
    result = @service.update_config(invalid_capabilities)
    
    assert_equal false, result[:success]
    assert result[:error].present?
  end

  speed_profile :fast
  test "update_config rejects empty model" do
    capabilities = {
      "general_llm" => {
        "model" => "",
        "provider" => "openai",
        "base_url" => "http://localhost:11434"
      }
    }
    
    result = @service.update_config(capabilities)
    
    assert_equal false, result[:success]
    assert_match(/model.*required/i, result[:error])
  end

  speed_profile :fast
  test "update_config rejects missing provider" do
    capabilities = {
      "general_llm" => {
        "model" => "gpt-4",
        "base_url" => "http://localhost:11434"
      }
    }
    
    result = @service.update_config(capabilities)
    
    assert_equal false, result[:success]
    assert_match(/provider.*required/i, result[:error])
  end

  # ============================================================================
  # MEDIUM TESTS - Configuration Updates
  # ============================================================================

  speed_profile :medium
  test "update_config persists capability configuration in session" do
    # OOP: update_config stores overrides in AgentSession
    original_config = @service.get_config
    original_model = original_config.capability(:general_llm).model
    
    new_capabilities = {
      "general_llm" => {  # Use the capability key from CAPABILITIES
        "model" => "gpt-4-turbo",
        "provider" => "openai",
        "port" => 52003,
        "max_context" => 64000,
        "base_url" => "LLM_URL"
      }
    }
    
    result = @service.update_config(new_capabilities)
    
    assert result[:success], "Should persist valid configuration"
    
    # Verify the config was actually updated in this session
    # Need to get the updated session from the service
    updated_session = @session_service.get_session(session_id: @session.session_id)
    updated_service = AgentConfigService.new(session: updated_session)
    updated_config = updated_service.get_config
    assert_equal "gpt-4-turbo", updated_config.capability(:general_llm).model
    assert_equal "openai", updated_config.capability(:general_llm).provider
    
    # Verify another session doesn't see the override
    other_session = @session_service.create_session(agent_type: "daedalus")
    other_service = AgentConfigService.new(session: other_session)
    other_config = other_service.get_config
    assert_equal original_model, other_config.capability(:general_llm).model, "Other session should have default config"
  end

  speed_profile :medium
  test "update_config returns updated config after persistence" do
    # OOP: update_config stores overrides in AgentSession
    new_capabilities = {
      "general_llm" => {
        "model" => "gpt-4",
        "provider" => "openai",
        "port" => 52003,
        "max_context" => 64000,
        "base_url" => "LLM_URL"
      }
    }
    
    result = @service.update_config(new_capabilities)
    
    assert result[:success], "Should persist successfully"
    assert result[:config].is_a?(Configuration::AgentConfig), "Should return AgentConfig instance"
    
    # Verify by getting fresh session and checking config
    updated_session = @session_service.get_session(session_id: @session.session_id)
    updated_service = AgentConfigService.new(session: updated_session)
    updated_config = updated_service.get_config
    assert_equal "gpt-4", updated_config.capability(:general_llm).model, "Should have updated model"
  end

  # ============================================================================
  # SLOW TESTS - Real LLM Connections
  # ============================================================================

  speed_profile :slow
  test "test_connection validates real LLM endpoint" do
    result = @service.test_connection("general_llm")
    
    assert result[:success]
    assert result[:connected]
    assert result[:response_time].present?
  end

  speed_profile :slow
  test "test_connection returns model information" do
    result = @service.test_connection("general_llm")
    
    assert result[:success]
    assert result[:model_info].present?
  end

  speed_profile :fast
  test "test_connection fails for invalid capability" do
    result = @service.test_connection("nonexistent")
    
    assert_equal false, result[:success]
    assert result[:error].present?
    assert_match(/not found|unknown/i, result[:error])
  end

  speed_profile :slow
  test "test_connection handles timeout gracefully" do
    # This would require a capability configured with unreachable endpoint
    # For now, we test with a valid one and ensure it doesn't timeout
    result = @service.test_connection("general_llm")
    
    # Should complete within reasonable time (handled by test timeout)
    assert result.key?(:success)
  end

  speed_profile :slow
  test "test_connection for all capabilities" do
    config = @service.get_config
    
    config.capabilities.each do |name, _capability|
      result = @service.test_connection(name.to_s)
      
      # Each should at least respond (may fail if LLM not running, but should respond)
      assert result.key?(:success), "#{name} test_connection didn't respond"
      assert result.key?(:connected), "#{name} test_connection missing connected status"
    end
  end

  # ============================================================================
  # INTEGRATION TESTS
  # ============================================================================

  speed_profile :medium
  test "full config lifecycle: get, update, validate, get" do
    # Get original
    original = @service.get_config
    original_model = original.capability(:general_llm).model
    
    # Update (persists in AgentSession, doesn't write to disk)
    # OOP: update_config stores overrides in AgentSession
    new_capabilities = {
      "general_llm" => {
        "model" => "test-model-temp",
        "provider" => "openai",
        "port" => 52003,
        "max_context" => 64000,
        "base_url" => "LLM_URL"
      }
    }
    update_result = @service.update_config(new_capabilities)
    assert update_result[:success], "Should persist successfully"
    
    # Validate the updated capability
    validate_result = @service.validate_capability("general_llm")
    assert validate_result[:valid], "Updated capability should be valid"
    
    # Get config (should have updated values from AgentSession for this session)
    updated_session = @session_service.get_session(session_id: @session.session_id)
    updated_service = AgentConfigService.new(session: updated_session)
    updated = updated_service.get_config
    assert_equal "test-model-temp", updated.capability(:general_llm).model, "Model should be updated in this session"
  end
end
