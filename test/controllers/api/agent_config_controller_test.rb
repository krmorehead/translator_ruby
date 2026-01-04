# frozen_string_literal: true

require "test_helper"

module Api
  class AgentConfigControllerTest < ActionDispatch::IntegrationTest
    speed_profile :fast
    test "GET /api/agent/config returns current configuration" do
      get "/api/agent/config", as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json["success"]
      assert json["config"]
      assert json["config"]["capabilities"]
      assert json["config"]["environment"]
    end

    speed_profile :fast
    test "returns all configured capabilities" do
      get "/api/agent/config", as: :json
      
      json = JSON.parse(response.body)
      capabilities = json.fetch("config").fetch("capabilities")
      
      # Check for actual capabilities from GenericLlmClient::CAPABILITIES
      assert capabilities.key?("general_llm") || capabilities.key?(:general_llm), "missing general_llm"
      assert capabilities.key?("tool_calling") || capabilities.key?(:tool_calling), "missing tool_calling"
      assert capabilities.key?("embeddings") || capabilities.key?(:embeddings), "missing embeddings"
    end

    speed_profile :fast
    test "each capability has required fields" do
      get "/api/agent/config", as: :json
      
      json = JSON.parse(response.body)
      capabilities = json.fetch("config").fetch("capabilities")
      
      # Following OpenAI API format - model (not model_name)
      capabilities.each do |name, config|
        assert config.key?("model"), "#{name} missing model"
        assert config.key?("provider"), "#{name} missing provider"
        assert config.key?("base_url"), "#{name} missing base_url"
      end
    end

    speed_profile :fast
    test "includes environment variables" do
      get "/api/agent/config", as: :json
      
      json = JSON.parse(response.body)
      environment = json.fetch("config").fetch("environment")
      
      assert environment.is_a?(Hash)
      # Should include at least RAILS_ENV
      assert environment.key?("RAILS_ENV")
    end

    speed_profile :fast
    test "POST /api/agent/config/validate with valid capability returns success" do
      service = AgentConfigService.new
      # Use actual capability name from GenericLlmClient::CAPABILITIES
      result = service.validate_capability("general_llm")
      
      assert result.fetch(:valid)
      assert_nil result.fetch(:error)
    end

    speed_profile :fast
    test "POST /api/agent/config/validate with invalid capability returns error" do
      service = AgentConfigService.new
      result = service.validate_capability("nonexistent_capability")
      
      assert_equal false, result.fetch(:valid)
      assert result.fetch(:error).present?
    end

    speed_profile :fast
    test "POST /api/agent/config/validate requires capability_name" do
      service = AgentConfigService.new
      result = service.validate_capability(nil)
      
      assert_equal false, result.fetch(:valid)
      assert_match(/required/i, result.fetch(:error))
    end

    speed_profile :slow
    test "POST /api/agent/config/test with valid capability connects to LLM" do
      service = AgentConfigService.new
      # Use actual capability name from GenericLlmClient::CAPABILITIES
      result = service.test_connection("general_llm")
      
      assert result.fetch(:success)
      assert result.fetch(:connected)
    end

    speed_profile :fast
    test "POST /api/agent/config/test with invalid capability returns error" do
      service = AgentConfigService.new
      result = service.test_connection("nonexistent")
      
      assert_equal false, result.fetch(:success)
      assert result.fetch(:error).present?
    end
  end
end
