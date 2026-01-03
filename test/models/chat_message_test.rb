# frozen_string_literal: true

require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  speed_profile :fast
  test "creates valid message with all required fields" do
    message = ChatMessage.new(
      id: "msg-123",
      session_id: "session-456",
      role: ChatMessage::ROLE_USER,
      content: "Hello, agent!",
      timestamp: Time.now.utc
    )

    assert_equal "msg-123", message.id
    assert_equal "session-456", message.session_id
    assert_equal ChatMessage::ROLE_USER, message.role
    assert_equal "Hello, agent!", message.content
    assert_nil message.thoughts
  end

  speed_profile :fast
  test "creates message with thoughts" do
    message = build_message(
      role: ChatMessage::ROLE_AGENT,
      thoughts: "Let me think about this..."
    )

    assert_equal "Let me think about this...", message.thoughts
    assert message.has_thoughts?
  end

  speed_profile :fast
  test "is immutable after creation" do
    message = build_message

    assert message.frozen?
  end

  speed_profile :fast
  test "validates id is required" do
    error = assert_raises(ArgumentError) do
      ChatMessage.new(
        id: nil,
        session_id: "session-456",
        role: ChatMessage::ROLE_USER,
        content: "Hello",
        timestamp: Time.now.utc
      )
    end

    assert_match(/id is required/, error.message)
  end

  speed_profile :fast
  test "validates role is valid" do
    error = assert_raises(ArgumentError) do
      ChatMessage.new(
        id: "msg-123",
        session_id: "session-456",
        role: "invalid_role",
        content: "Hello",
        timestamp: Time.now.utc
      )
    end

    assert_match(/Invalid role/, error.message)
  end

  speed_profile :fast
  test "user? returns true for user role" do
    message = build_message(role: ChatMessage::ROLE_USER)
    assert message.user?
    refute message.agent?
    refute message.system?
  end

  speed_profile :fast
  test "agent? returns true for agent role" do
    message = build_message(role: ChatMessage::ROLE_AGENT)
    assert message.agent?
    refute message.user?
    refute message.system?
  end

  speed_profile :fast
  test "system? returns true for system role" do
    message = build_message(role: ChatMessage::ROLE_SYSTEM)
    assert message.system?
    refute message.user?
    refute message.agent?
  end

  speed_profile :fast
  test "has_thoughts? returns false when no thoughts" do
    message = build_message(thoughts: nil)
    refute message.has_thoughts?
  end

  speed_profile :fast
  test "has_thoughts? returns false for empty string" do
    message = build_message(thoughts: "")
    refute message.has_thoughts?
  end

  speed_profile :fast
  test "has_thoughts? returns true when thoughts present" do
    message = build_message(thoughts: "Some reasoning")
    assert message.has_thoughts?
  end

  speed_profile :fast
  test "to_h serializes correctly" do
    timestamp = Time.now.utc
    message = build_message(
      id: "msg-789",
      content: "Test content",
      thoughts: "Test thoughts",
      timestamp: timestamp
    )

    hash = message.to_h

    assert_equal "msg-789", hash[:id]
    assert_equal "Test content", hash[:content]
    assert_equal "Test thoughts", hash[:thoughts]
    assert_equal timestamp.iso8601, hash[:timestamp]
  end

  speed_profile :fast
  test "from_h creates message from hash with symbol keys" do
    hash = {
      id: "msg-abc",
      session_id: "session-def",
      role: ChatMessage::ROLE_AGENT,
      content: "Response",
      thoughts: "Reasoning",
      timestamp: Time.now.utc.iso8601,
      metadata: { key: "value" }
    }

    message = ChatMessage.from_h(hash)

    assert_equal "msg-abc", message.id
    assert_equal "Response", message.content
    assert_equal "Reasoning", message.thoughts
  end

  speed_profile :fast
  test "from_h creates message from hash with string keys" do
    hash = {
      "id" => "msg-abc",
      "session_id" => "session-def",
      "role" => ChatMessage::ROLE_AGENT,
      "content" => "Response",
      "timestamp" => Time.now.utc.iso8601
    }

    message = ChatMessage.from_h(hash)

    assert_equal "msg-abc", message.id
  end

  speed_profile :fast
  test "metadata is frozen and immutable" do
    message = build_message(metadata: { key: "value" })

    assert message.metadata.frozen?
  end

  private

  def build_message(overrides = {})
    defaults = {
      id: "msg-123",
      session_id: "session-456",
      role: ChatMessage::ROLE_USER,
      content: "Test message",
      thoughts: nil,
      timestamp: Time.now.utc,
      metadata: {}
    }

    ChatMessage.new(**defaults.merge(overrides))
  end
end


