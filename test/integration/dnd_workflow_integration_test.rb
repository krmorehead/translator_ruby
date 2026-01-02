require "test_helper"

class DndWorkflowIntegrationTest < ActionDispatch::IntegrationTest
  # Use the same data path as the controller/tools
  DATA_PATH = BaseTool.data_path

  def setup
    # Verify LLM configuration (fail fast if not configured per OOP Lesson 46)
    ENV.fetch("API_KEY")
    ENV.fetch("LLM_URL")
    
    FileUtils.rm_rf(DATA_PATH)
    FileUtils.mkdir_p(DATA_PATH)
    
    # Create session for testing
    @session_id = SecureRandom.uuid
  end

  def teardown
    FileUtils.rm_rf(DATA_PATH) if File.exist?(DATA_PATH)
  end
  speed_profile :slow
  test "simple prompt completes the full workflow" do
    body = post_message("I search the room carefully.")

    assert body["success"], "expected success response"
    assert body["reply"].to_s.strip.present?, "reply should be present"
    assert_conversation_persisted_with_messages(2)
    assert_actions_recorded(require_entries: false)
  end

  speed_profile :slow
  test "multi-action prompt processes sequential actions" do
    body = post_message("Use the memory tool to record that we accepted the quest to rescue the merchant's son, then summarize our quests.")

    assert body["success"], "expected success response"
    assert body["reply"].to_s.strip.present?
    assert_conversation_persisted_with_messages(2)
    assert_actions_recorded(require_entries: false)
  end

  speed_profile :slow
  test "conversation continuity across multiple messages" do
    post_message("I light a torch.")
    body = post_message("I explore the corridor ahead.")

    assert body["success"], "expected success response"
    # Expect at least 4 messages: user+assistant for each of two turns
    assert_conversation_persisted_with_messages(4)
  end


  def post_message(message)
    # Create session first if needed
    unless @session_created
      post "/dnd/sessions"
      assert_response :created
      session_data = JSON.parse(response.body)
      @session_id = session_data["session_id"]
      @session_created = true
    end
    
    post "/dnd_chat/messages", params: { message: message }, headers: { "X-Session-ID" => @session_id }
    assert_response :success
    JSON.parse(response.body)
  end

  def assert_conversation_persisted_with_messages(min_count)
    # MemoryStore now uses owner_id
    memory_path = File.join(DATA_PATH, @session_id, "memory.json")
    assert File.exist?(memory_path), "memory file should exist at #{memory_path}"
    
    store = MemoryStore.new(owner_id: @session_id)
    # Conversation is stored under RECENT_CONVERSATION section
    convo_data = store.get_section(MemoryKinds::RECENT_CONVERSATION)
    messages = convo_data.is_a?(Hash) ? (convo_data[:messages] || convo_data["messages"] || []) : []
    # If conversation data is in an array format, extract messages from first element
    if convo_data.is_a?(Array) && convo_data.first.is_a?(Hash)
      messages = convo_data.first[:messages] || convo_data.first["messages"] || []
    end
    assert messages.count >= min_count, "expected at least #{min_count} messages persisted, got #{messages.count}"
  end

  def assert_actions_recorded(require_entries: true)
    store = MemoryStore.new(owner_id: @session_id)
    actions = store.get_section(MemoryKinds::ACTIONS)
    assert actions.is_a?(Array), "actions section should be an array"
    assert actions.any?, "expected at least one action recorded" if require_entries
  end
end
