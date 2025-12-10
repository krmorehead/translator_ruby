require "test_helper"

class ChatResponseSerializerTest < ActiveSupport::TestCase
  class FakeConversation
    def initialize(messages = [])
      @messages = messages
    end

    def to_h
      { messages: @messages }
    end
  end

  class StubWorkflow < BaseWorkflow
    def initialize(result:, state:, error: nil)
      super()
      @result = result
      @error = error
      @state = state
      @conversation = result[:conversation] if result
    end

    def execute; end
  end

  test "serializes successful workflow with reply and conversation" do
    convo = FakeConversation.new([ { text: "hi" } ])
    result = { narrative: "Story", conversation: convo }
    workflow = StubWorkflow.new(result: result, state: :complete)

    serializer = ChatResponseSerializer.new(workflow)
    payload = serializer.serialize

    assert_equal true, payload[:success]
    assert_equal "Story", payload[:reply]
    assert_equal({ messages: [ { text: "hi" } ] }, payload[:conversation])
    assert_nil payload[:error]
  end

  test "serializes failed workflow with fallback reply" do
    workflow = StubWorkflow.new(result: nil, state: :failed, error: "boom")

    serializer = ChatResponseSerializer.new(workflow)
    payload = serializer.serialize

    assert_equal false, payload[:success]
    assert_equal "boom", payload[:error]
    assert payload[:reply].include?("couldn't complete")
  end

  test "serialize_json returns JSON string" do
    workflow = StubWorkflow.new(result: { narrative: "ok" }, state: :complete)

    serializer = ChatResponseSerializer.new(workflow)
    json = serializer.serialize_json

    parsed = JSON.parse(json)
    assert parsed["success"]
    assert_equal "ok", parsed["reply"]
  end
end
