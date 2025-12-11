# frozen_string_literal: true

require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "initializes with array of hashes and messages" do
    hash_message = { source: "user", target: "assistant", message: "Hello" }
    obj_message = Message.new(source: "assistant", target: "user", message: "Hi")

    conv = Conversation.new(messages: [ hash_message, obj_message ])

    assert_equal 2, conv.messages.size
    assert conv.messages.all? { |m| m.is_a?(Message) }
  end

  test "adds message via add_message and shovel" do
    conv = Conversation.new
    conv.add_message(source: "user", target: "assistant", message: "Hello")
    conv << { source: "assistant", target: "user", message: "Hi" }

    assert_equal 2, conv.messages.size
    assert_equal %w[user assistant], conv.messages.map(&:source)
  end

  test "to_h returns serializable hash" do
    conv = Conversation.new(messages: [ { source: "user", target: "assistant", message: "Hello" } ])

    payload = conv.to_h
    assert_equal [ "messages" ], payload.keys.map(&:to_s)
    assert_equal "Hello", payload[:messages].first[:message]
  end
end

