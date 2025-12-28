# frozen_string_literal: true

require "test_helper"

class DndChatControllerTest < ActionDispatch::IntegrationTest
  SANDBOX = Rails.root.join("tmp", "dnd_chat_sandbox")

  setup do
    FileUtils.rm_rf(SANDBOX)
  end

  test "messages contract returns yaml" do
    get "/dnd_chat/messages/contract"
    assert_response :success
    assert_includes response.media_type, "yaml"
  end

  test "agent contract returns yaml" do
    get "/dnd_chat/agent/contract"
    assert_response :success
    assert_includes response.media_type, "yaml"
  end

  test "get messages returns empty conversation initially" do
    get "/dnd_chat/messages"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body["messages"]
  end

  test "post messages validates presence" do
    post "/dnd_chat/messages", params: { message: "" }
    assert_response :bad_request
    body = JSON.parse(response.body)
    refute body["success"]
    assert_match(/message required/i, body["error"])
  end

  test "post messages flows through LLM and tools when configured" do
    post "/dnd_chat/messages", params: { message: "Describe the scenario" }
    assert_response :success
    body = JSON.parse(response.body)

    assert_equal true, body["success"], "Expected success, got: #{body['error']}"
    assert body["reply"].present?
    assert body["conversation"]["messages"].size >= 2
    refute body.key?("tool")
    refute body.key?("result")
    refute body.key?("arguments")
  end

  test "agent endpoint returns state and version" do
    get "/dnd_chat/agent"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert body["version"].is_a?(Numeric)
    assert body["state"].is_a?(Hash)
    assert body["state"].key?("memories")
    assert body["state"].key?("inventory")
  end

  test "agent version endpoint returns version" do
    get "/dnd_chat/agent/version"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert body["version"].is_a?(Numeric)
  end
end
