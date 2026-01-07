# frozen_string_literal: true

require "test_helper"

class AgentToolBuilderTest < ActiveSupport::TestCase
  speed_profile :fast
  test "exploration_tools returns 3 tools for Daedalus" do
    tools = AgentToolBuilder.exploration_tools

    assert_equal 3, tools.size
    assert tools.all? { |t| t.is_a?(Tool) }, "All items should be Tool objects"
  end

  speed_profile :fast
  test "exploration_tools includes file_tree, grep, and read_file" do
    tools = AgentToolBuilder.exploration_tools
    tool_names = tools.map(&:name)

    assert_includes tool_names, "file_tree"
    assert_includes tool_names, "grep"
    assert_includes tool_names, "read_file"
  end

  speed_profile :fast
  test "execution_tools returns 5 tools for Sisyphus" do
    tools = AgentToolBuilder.execution_tools

    assert_equal 5, tools.size
    assert tools.all? { |t| t.is_a?(Tool) }, "All items should be Tool objects"
  end

  speed_profile :fast
  test "execution_tools includes file_tree, grep, read_file, write_file, and bash" do
    tools = AgentToolBuilder.execution_tools
    tool_names = tools.map(&:name)

    assert_includes tool_names, "file_tree"
    assert_includes tool_names, "grep"
    assert_includes tool_names, "read_file"
    assert_includes tool_names, "write_file"
    assert_includes tool_names, "bash"
  end

  speed_profile :fast
  test "tools have proper schema structure" do
    tool = AgentToolBuilder.exploration_tools.first

    assert_respond_to tool, :name
    assert_respond_to tool, :description
    assert_respond_to tool, :parameters
    assert_respond_to tool, :to_h
  end

  speed_profile :fast
  test "tool to_h returns OpenAI function calling format" do
    tool = AgentToolBuilder.exploration_tools.first
    hash = tool.to_h

    assert_equal "function", hash[:type]
    assert hash[:function].is_a?(Hash)
    assert hash[:function][:name].is_a?(String)
    assert hash[:function][:description].is_a?(String)
    assert hash[:function][:parameters].is_a?(Hash)
  end

  speed_profile :fast
  test "exploration_tools and execution_tools share common tools" do
    exploration = AgentToolBuilder.exploration_tools.map(&:name)
    execution = AgentToolBuilder.execution_tools.map(&:name)

    # All exploration tools should be in execution tools
    exploration.each do |tool_name|
      assert_includes execution, tool_name,
        "Execution tools should include exploration tool: #{tool_name}"
    end
  end
end

