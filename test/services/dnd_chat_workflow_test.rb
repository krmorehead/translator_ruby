# frozen_string_literal: true

require "test_helper"

class DndChatWorkflowTest < ActiveSupport::TestCase
  SANDBOX = Rails.root.join("tmp", "dnd_workflow_test_#{Process.pid}_#{Thread.current.object_id}")

  def setup
    FileUtils.rm_rf(SANDBOX)
    FileUtils.mkdir_p(SANDBOX)
    load_tools
  end

  def teardown
    FileUtils.rm_rf(SANDBOX)
  end

  test "inherits base workflow and exposes workflow_name" do
    workflow = DndChatWorkflow.new
    assert_kind_of BaseWorkflow, workflow
    assert_equal "dnd_chat", DndChatWorkflow.workflow_name
  end

  test "executes end-to-end when LLM configured" do
    workflow = DndChatWorkflow.new
    conversation = Conversation.new(messages: [ Message.new(source: "user", target: "assistant", message: "Start the adventure") ])

    workflow.setup(prompt: "Search the room", conversation: conversation, sandbox_path: SANDBOX.to_s)
    state = workflow.execute

    assert workflow.complete?, "Workflow should complete: #{workflow.error || state&.error}"
    assert_kind_of WorkflowState, state
    result = workflow.result
    assert_kind_of Hash, result
    assert result[:narrative].is_a?(String)
    assert result[:actions].is_a?(Array)
    assert_kind_of Conversation, result[:conversation]
    assert result.key?(:thoughts), "Result should include thoughts field"
  end

  private

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
