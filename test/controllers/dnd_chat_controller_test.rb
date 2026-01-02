# frozen_string_literal: true

require "test_helper"

class DndChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Clear session cache before each test
    DndSessionService.clear_cache
    
    # Create a test session
    @session = DndSessionService.create_session
    @session_id = @session.session_id
  end
  
  teardown do
    DndSessionService.clear_cache
  end

  speed_profile :fast
  test "messages contract returns yaml" do
    get "/dnd_chat/messages/contract"
    assert_response :success
    assert_includes response.media_type, "yaml"
  end

  speed_profile :fast
  test "agent contract returns yaml" do
    get "/dnd_chat/agent/contract"
    assert_response :success
    assert_includes response.media_type, "yaml"
  end

  speed_profile :medium
  test "post messages validates presence" do
    post "/dnd_chat/messages", params: { session_id: @session_id, message: "" }
    assert_response :bad_request
    body = JSON.parse(response.body)
    refute body["success"]
    assert_match(/message required/i, body["error"])
  end

  speed_profile :slow
  test "post messages flows through LLM and tools when configured" do
    post "/dnd_chat/messages", params: { session_id: @session_id, message: "Describe the scenario" }
    assert_response :success
    body = JSON.parse(response.body)

    assert_equal true, body["success"], "Expected success, got: #{body['error']}"
    assert body["message"].present?
    assert body["conversation"]["messages"].size >= 2
  end

  speed_profile :fast
  test "agent endpoint returns state" do
    get "/dnd_chat/agent", params: { session_id: @session_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ready", body["state"]
    assert_equal @session_id, body["session_id"]
  end

  speed_profile :fast
  test "create session endpoint creates new session" do
    post "/dnd_chat/sessions"
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert body["session_id"].present?
    assert_equal "DnD session created", body["message"]
  end

  speed_profile :fast
  test "requires session_id for protected endpoints" do
    get "/dnd_chat/messages"
    assert_response :bad_request
    body = JSON.parse(response.body)
    refute body["success"]
    assert_match(/session_id required/i, body["error"])
  end
end
