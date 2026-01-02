# frozen_string_literal: true

require "test_helper"

class DndChatWorkflowTest < ActiveSupport::TestCase
  def setup
    @owner_id = SecureRandom.uuid
    @parent_memory = MemoryStore.new(owner_id: @owner_id)
    load_tools
  end

  def teardown
    # Cleanup memory files
    data_path = ENV.fetch("AGENT_DATA_PATH")
    owner_path = File.join(data_path, @owner_id)
    FileUtils.rm_rf(owner_path) if File.exist?(owner_path)
  end
  
  speed_profile :fast
  test "inherits base workflow and exposes workflow_name" do
    workflow = DndChatWorkflow.new(owner_id: @owner_id, parent_memory: @parent_memory)
    assert_kind_of BaseWorkflow, workflow
    assert_equal "dnd_chat", DndChatWorkflow.workflow_name
  end

  speed_profile :medium
  test "workflow executes and returns narrative" do
    workflow = DndChatWorkflow.new(owner_id: @owner_id, parent_memory: @parent_memory)
    conversation = Conversation.new(messages: [ Message.new(source: "user", target: "assistant", message: "Start the adventure") ])

    workflow.setup(prompt: "Search the room", conversation: conversation)
    result = workflow.execute

    assert workflow.complete?, "Workflow should complete: #{workflow.error}"
    assert_kind_of Hash, result
    assert result[:narrative].is_a?(String), "Should return narrative string"
    assert result[:actions].is_a?(Array), "Should return actions array"
    assert_kind_of Conversation, result[:conversation]
  end

  
  def load_tools
    %w[dice_roll_tool skill_check_tool inventory_tool memory_tool memory_summarize_tool read_file_tool write_file_tool].each do |file|
      require Rails.root.join("app", "tools", file)
    rescue LoadError
      # already loaded
    end
  end

  def llm_configured?
    ENV["API_KEY"].to_s.strip.present? && ENV["LLM_URL"].to_s.strip.present?
  end
end
