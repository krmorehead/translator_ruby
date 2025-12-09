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
    unless ENV["API_KEY"].to_s.strip.present? && ENV["LLM_URL"].to_s.strip.present?
      skip "LLM credentials not configured for integration run"
    end

    post "/dnd_chat/messages", params: { message: "Describe the scenario" }
    assert_response :success
    body = JSON.parse(response.body)

    assert_equal true, body["success"]
    assert body["reply"].present?
    assert body["conversation"]["messages"].size >= 2
    assert body["tool"].present?
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

