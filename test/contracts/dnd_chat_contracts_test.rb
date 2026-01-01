# frozen_string_literal: true

require "test_helper"

class DndChatContractsTest < ActiveSupport::TestCase
  speed_profile :fast
  test "message contract includes expected paths and schemas" do
    contract = YAML.load_file(Rails.root.join("docs/api/contracts/dnd_chat_messages.yml"))

    assert_equal "3.1.0", contract["openapi"]
    paths = contract.fetch("paths")
    assert_includes paths.keys, "/dnd_chat/messages"
    assert_includes paths.keys, "/dnd_chat/messages/contract"

    schemas = contract.dig("components", "schemas")
    %w[Message Conversation PostMessageRequest PostMessageResponse AgentState AgentVersion Error].each do |schema|
      assert_includes schemas.keys, schema
    end
  end

  speed_profile :fast
  test "agent contract includes version endpoint" do
    contract = YAML.load_file(Rails.root.join("docs/api/contracts/dnd_chat_agent.yml"))

    paths = contract.fetch("paths")
    assert_includes paths.keys, "/dnd_chat/agent"
    assert_includes paths.keys, "/dnd_chat/agent/version"
    assert_includes paths.keys, "/dnd_chat/agent/contract"
    assert_includes paths.keys, "/dnd_chat/agent/version/contract"

    schemas = contract.dig("components", "schemas")
    %w[AgentState AgentVersion Error].each do |schema|
      assert_includes schemas.keys, schema
    end
  end
end

