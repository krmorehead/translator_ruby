# frozen_string_literal: true

require "test_helper"

module Api
  class AgentConfigControllerTest < ActionDispatch::IntegrationTest
    speed_profile :fast
    test "GET /api/agent_config returns current configuration" do
      get "/api/agent_config", as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json["success"]
      assert json["config"]
      assert json["config"]["capabilities"]
      assert json["config"]["environment"]
    end

    speed_profile :fast
    test "returns all configured capabilities" do
      get "/api/agent_config", as: :json
      
      json = JSON.parse(response.body)
      capabilities = json["config"]["capabilities"]
      
      # Should have at least planner, executor, and researcher
      assert capabilities.key?("planner")
      assert capabilities.key?("executor")
      assert capabilities.key?("researcher")
    end

    speed_profile :fast
    test "each capability has required fields" do
      get "/api/agent_config", as: :json
      
      json = JSON.parse(response.body)
      capabilities = json["config"]["capabilities"]
      
      capabilities.each do |name, config|
        assert config.key?("model"), "#{name} missing model"
        assert config.key?("provider"), "#{name} missing provider"
        assert config.key?("base_url"), "#{name} missing base_url"
      end
    end

    speed_profile :fast
    test "includes environment variables" do
      get "/api/agent_config", as: :json
      
      json = JSON.parse(response.body)
      environment = json["config"]["environment"]
      
      assert environment.is_a?(Hash)
      # Should include at least RAILS_ENV
      assert environment.key?("RAILS_ENV")
    end

    speed_profile :fast
    test "POST /api/agent_config with invalid data returns error" do
      post "/api/agent_config", params: {
        capabilities: {
          planner: { model: "" } # Invalid: empty model
        }
      }, as: :json
      
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      
      assert_equal false, json["success"]
      assert json["error"]
      assert_match(/model.*required|invalid/i, json["error"])
    end

    speed_profile :fast
    test "POST /api/agent_config validates capability structure" do
      post "/api/agent_config", params: {
        capabilities: {
          invalid_capability: { random: "data" }
        }
      }, as: :json
      
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      
      assert_equal false, json["success"]
    end

    speed_profile :medium
    test "POST /api/agent_config updates configuration" do
      original = get "/api/agent_config", as: :json
      original_json = JSON.parse(response.body)
      
      # Update planner model
      updated_capabilities = original_json["config"]["capabilities"]
      updated_capabilities["planner"]["model"] = "gpt-4-turbo"
      
      post "/api/agent_config", params: {
        capabilities: updated_capabilities
      }, as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json["success"]
      assert_equal "gpt-4-turbo", json["config"]["capabilities"]["planner"]["model"]
    end

    speed_profile :fast
    test "POST /api/agent_config/validate with valid capability returns success" do
      post "/api/agent_config/validate", params: {
        capability_name: "planner"
      }, as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json["valid"]
    end

    speed_profile :fast
    test "POST /api/agent_config/validate with invalid capability returns error" do
      post "/api/agent_config/validate", params: {
        capability_name: "nonexistent_capability"
      }, as: :json
      
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      
      assert_equal false, json["valid"]
      assert json["error"]
    end

    speed_profile :fast
    test "POST /api/agent_config/validate requires capability_name" do
      post "/api/agent_config/validate", params: {}, as: :json
      
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      
      assert_equal false, json["valid"]
      assert_match(/capability.*required/i, json["error"])
    end

    speed_profile :slow
    test "POST /api/agent_config/test with valid capability connects to LLM" do
      post "/api/agent_config/test", params: {
        capability_name: "planner"
      }, as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      
      assert json["success"]
      assert json["result"]
      assert json["result"]["connected"]
    end

    speed_profile :fast
    test "POST /api/agent_config/test with invalid capability returns error" do
      post "/api/agent_config/test", params: {
        capability_name: "nonexistent"
      }, as: :json
      
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      
      assert_equal false, json["success"]
      assert json["error"]
    end

    speed_profile :fast
    test "POST /api/agent_config/test requires capability_name" do
      post "/api/agent_config/test", params: {}, as: :json
      
      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      
      assert_equal false, json["success"]
      assert_match(/capability.*required/i, json["error"])
    end
  end
end
