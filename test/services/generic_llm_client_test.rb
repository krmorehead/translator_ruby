# frozen_string_literal: true

require "test_helper"

class GenericLlmClientTest < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_h.dup
    ENV["API_KEY"] = "test_key"
    ENV["LLM_URL"] = "http://localhost:52003"
    ENV["LLM_RETRY"] = "1"
    # Clear cached clients
    GenericLlmClient.instance_variable_set(:@clients, nil)
  end

  teardown do
    ENV.replace(@original_env)
    GenericLlmClient.instance_variable_set(:@clients, nil)
  end

  test "client_for returns client for valid capability" do
    client = GenericLlmClient.client_for(:general_llm)
    assert_instance_of GenericLlmClient::ClientRetryWrapper, client
  end

  test "client_for raises for invalid capability" do
    assert_raises(ArgumentError) do
      GenericLlmClient.build_client_for_capability(:invalid_capability)
    end
  end

  test "client_for caches clients per capability" do
    client1 = GenericLlmClient.client_for(:general_llm)
    client2 = GenericLlmClient.client_for(:general_llm)
    assert_same client1, client2
  end

  test "different capabilities get different clients" do
    general = GenericLlmClient.client_for(:general_llm)
    tool = GenericLlmClient.client_for(:tool_calling)
    refute_same general, tool
  end

  test "build_url_for_capability extracts host and updates port" do
    # Use the configured base_url from the capability config
    config = GenericLlmClient::CAPABILITIES[:tool_calling]
    base_url = ENV.fetch(config[:base_url], "http://localhost")
    
    url = GenericLlmClient.build_url_for_capability(52999, base_url)
    
    # Should keep the host and update only the port
    uri = URI.parse(url)
    assert_equal 52999, uri.port
    assert_equal URI.parse(base_url).host, uri.host
  end

  test "model_for returns correct model for capability" do
    # Both capabilities return valid model names from the config
    general_model = GenericLlmClient.model_for(:general_llm)
    tool_model = GenericLlmClient.model_for(:tool_calling)
    
    assert general_model.present?, "general_llm should have a model"
    assert tool_model.present?, "tool_calling should have a model"
    
    # Verify they match the CAPABILITIES config
    assert_equal GenericLlmClient::CAPABILITIES[:general_llm][:model_name], general_model
    assert_equal GenericLlmClient::CAPABILITIES[:tool_calling][:model_name], tool_model
  end

  test "instance returns general_llm client for backward compatibility" do
    instance = GenericLlmClient.instance
    general = GenericLlmClient.client_for(:general_llm)
    assert_same instance, general
  end

  test "wrap_with_retry always wraps client" do
    ENV["LLM_RETRY"] = "0"
    
    mock_client = Object.new
    wrapped = GenericLlmClient.wrap_with_retry(mock_client)

    assert_instance_of GenericLlmClient::ClientRetryWrapper, wrapped
  end

  test "retry_attempts defaults to 1" do
    ENV["LLM_RETRY_AT"] = "0"
    assert_equal 0, GenericLlmClient.retry_attempts

    # But wrap_with_retry forces at least 1
    ENV.delete("LLM_RETRY_AT")
    assert_equal 1, GenericLlmClient.retry_attempts
  end

  test "ClientRetryWrapper process_response filters think tags" do
    client = Object.new
    wrapper = GenericLlmClient::ClientRetryWrapper.new(client: client, attempts: 1, delay: 0)
    
    response = {
      "choices" => [
        {
          "message" => {
            "content" => "<think>This is reasoning</think>The actual response"
          }
        }
      ]
    }
    
    processed = wrapper.send(:process_response, response)
    
    assert_equal "The actual response", processed.dig("choices", 0, "message", "content")
    assert_equal "This is reasoning", processed["thoughts"]
  end

  test "ClientRetryWrapper process_response handles no think tags" do
    client = Object.new
    wrapper = GenericLlmClient::ClientRetryWrapper.new(client: client, attempts: 1, delay: 0)
    
    response = {
      "choices" => [
        {
          "message" => {
            "content" => "Regular response"
          }
        }
      ]
    }
    
    processed = wrapper.send(:process_response, response)
    
    assert_equal "Regular response", processed.dig("choices", 0, "message", "content")
    assert_nil processed["thoughts"]
  end

  test "ClientRetryWrapper process_response preserves structure" do
    client = Object.new
    wrapper = GenericLlmClient::ClientRetryWrapper.new(client: client, attempts: 1, delay: 0)
    
    response = {
      "id" => "test-123",
      "model" => "test-model",
      "choices" => [
        {
          "message" => {
            "content" => "<think>reasoning</think>response"
          }
        }
      ],
      "usage" => {
        "tokens" => 100
      }
    }
    
    processed = wrapper.send(:process_response, response)
    
    assert_equal "test-123", processed["id"]
    assert_equal "test-model", processed["model"]
    assert_equal 100, processed.dig("usage", "tokens")
    assert_equal "response", processed.dig("choices", 0, "message", "content")
    assert_equal "reasoning", processed["thoughts"]
  end
end

