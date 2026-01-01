# frozen_string_literal: true

require "test_helper"

class MessageTest < ActiveSupport::TestCase
  speed_profile :fast
  test "builds message with required fields" do
    msg = Message.new(source: "user", target: "assistant", message: "Hi there")

    assert_equal "user", msg.source
    assert_equal "assistant", msg.target
    assert_equal "Hi there", msg.message
    assert_nil msg.context
  end

  speed_profile :fast
  test "rejects blank message body" do
    assert_raises(ArgumentError) do
      Message.new(source: "user", target: "assistant", message: "   ")
    end
  end

  speed_profile :fast
  test "context must be hash or nil" do
    assert Message.new(source: "u", target: "a", message: "ok", context: { foo: "bar" })

    assert_raises(ArgumentError) do
      Message.new(source: "u", target: "a", message: "ok", context: "bad")
    end
  end
end

