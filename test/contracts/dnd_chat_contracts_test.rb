# frozen_string_literal: true

require "test_helper"

class DndChatContractsTest < ActiveSupport::TestCase
  def test_message_contract_includes_expected_paths_and_schemas
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

  def test_agent_contract_includes_version_endpoint
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
