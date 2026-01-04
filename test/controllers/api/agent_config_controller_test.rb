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
      
      # Should have at least planner, executor, and researcher
      assert capabilities.key?("planner") || capabilities.key?(:planner)
      assert capabilities.key?("executor") || capabilities.key?(:executor)
      assert capabilities.key?("researcher") || capabilities.key?(:researcher)
    end

    speed_profile :fast
    test "each capability has required fields" do
      get "/api/agent/config", as: :json
      
      json = JSON.parse(response.body)
      capabilities = json.fetch("config").fetch("capabilities")
      
      capabilities.each do |name, config|
        assert config.key?("model") || config.key?("model_name"), "#{name} missing model"
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
      result = service.validate_capability("planner")
      
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
      result = service.test_connection("planner")
      
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
