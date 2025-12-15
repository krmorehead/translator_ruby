# frozen_string_literal: true

require "test_helper"

class GenericLlmClientTest < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_h.dup
    ENV["API_KEY"] = "test_key"
    ENV["LLM_URL"] = "http://localhost:8000"
    ENV["LLM_RETRY_ATTEMPTS"] = "1"
  end

  teardown do
    ENV.replace(@original_env)
    GenericLlmClient.instance_variable_set(:@instance, nil)
  end

  test "wrap_with_retry always wraps client" do
    ENV["LLM_RETRY_ATTEMPTS"] = "0"
    
    mock_client = Object.new
    wrapped = GenericLlmClient.wrap_with_retry(mock_client)

    assert_instance_of GenericLlmClient::ClientRetryWrapper, wrapped
  end

  test "retry_attempts defaults to 1" do
    ENV["LLM_RETRY_ATTEMPTS"] = "0"
    assert_equal 0, GenericLlmClient.retry_attempts

    # But wrap_with_retry forces at least 1
    ENV.delete("LLM_RETRY_ATTEMPTS")
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

