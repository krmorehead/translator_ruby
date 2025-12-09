# frozen_string_literal: true

require "test_helper"

class DndChatWorkflowTest < ActiveSupport::TestCase
  def setup
    %w[dice_roll_tool skill_check_tool inventory_tool memory_tool memory_summarize_tool].each do |file|
      require Rails.root.join("app", "tools", file)
    rescue LoadError
      # already loaded
    end
  end

  test "builds chat parameters with system prompt and tools" do
    params = DndChatWorkflow.new.chat_parameters(user_prompt: "Hello adventurer")

    assert params[:messages].any? { |m| m[:role] == "system" }
    assert params[:messages].any? { |m| m[:role] == "user" && m[:content].include?("Hello adventurer") }
    rf = params[:response_format]
    assert_equal "json_schema", rf[:type]
    tool_enum = rf[:json_schema][:schema][:properties][:tool][:enum]
    assert_includes tool_enum, "dice_roll"
  end

  test "includes extra system prompt when provided" do
    params = DndChatWorkflow.new.chat_parameters(
      user_prompt: "Hi",
      extra_system_prompt: "Use concise responses."
    )

    system_msg = params[:messages].find { |m| m[:role] == "system" }[:content]
    assert_includes system_msg, "Use concise responses."
  end
end

