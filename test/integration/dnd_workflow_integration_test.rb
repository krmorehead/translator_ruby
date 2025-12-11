require "test_helper"

class DndWorkflowIntegrationTest < ActionDispatch::IntegrationTest
  SANDBOX_ROOT = DndChatController::SANDBOX_ROOT
  MEMORY_PATH = DndChatController::MEMORY_PATH
  CONVO_PATH = DndChatController::CONVERSATION_PATH

  def setup
    skip_unless_llm_configured!
    FileUtils.rm_rf(SANDBOX_ROOT)
    FileUtils.mkdir_p(SANDBOX_ROOT)
  end

  def teardown
    FileUtils.rm_rf(SANDBOX_ROOT) if File.exist?(SANDBOX_ROOT)
  end

  test "simple prompt completes the full workflow" do
    body = post_message("I search the room carefully.")

    assert body["success"], "expected success response"
    assert body["reply"].to_s.strip.present?, "reply should be present"
    assert_conversation_persisted_with_messages(2)
    assert_actions_recorded(require_entries: false)
  end

  test "multi-action prompt processes sequential actions" do
    body = post_message("Use the memory tool to record that we accepted the quest to rescue the merchant's son, then summarize our quests.")

    assert body["success"], "expected success response"
    assert body["reply"].to_s.strip.present?
    assert_conversation_persisted_with_messages(2)
    assert_actions_recorded(require_entries: false)
  end

  test "conversation continuity across multiple messages" do
    post_message("I light a torch.")
    body = post_message("I explore the corridor ahead.")

    assert body["success"], "expected success response"
    # Expect at least 4 messages: user+assistant for each of two turns
    assert_conversation_persisted_with_messages(4)
  end

  private

  def skip_unless_llm_configured!
    creds = ENV["API_KEY"].to_s.strip
    url = ENV["LLM_URL"].to_s.strip
    skip "LLM credentials not configured for integration run" if creds.empty? || url.empty?
  end

  def post_message(message)
    post "/dnd_chat/messages", params: { message: message }
    assert_response :success
    JSON.parse(response.body)
  end

  def assert_conversation_persisted_with_messages(min_count)
    assert File.exist?(CONVO_PATH), "conversation file should persist"
    convo = Conversation.new(messages: JSON.parse(File.read(CONVO_PATH))["messages"])
    assert convo.messages.count >= min_count, "expected at least #{min_count} messages persisted"
  end

  def assert_actions_recorded(require_entries: true)
    store = MemoryStore.new(path: MEMORY_PATH, sandbox_path: SANDBOX_ROOT)
    actions = store.get_section(MemoryKinds::ACTIONS)
    assert actions.is_a?(Array), "actions section should be an array"
    assert actions.any?, "expected at least one action recorded" if require_entries
  end
end
