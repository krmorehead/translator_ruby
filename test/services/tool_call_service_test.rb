require "test_helper"

class ToolCallServiceTest < ActiveSupport::TestCase
  # Test tool for service tests
  class MockTool < BaseTool
    def self.name_identifier
      "mock_tool"
    end

    def self.description
      "A mock tool for testing the service"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          message: { type: "string", description: "A message to echo" }
        },
        required: ["message"]
      }
    end

    def execute(message:)
      success_result("Mock received: #{message}, sandbox: #{sandbox_path}")
    end
  end

  def setup
    # Register the mock tool for testing
    ToolCallService.register_tool(MockTool) unless ToolCallService::TOOL_CLASSES.include?(MockTool)
    # Ensure DnD tools are loaded and registered
    %w[dice_roll_tool skill_check_tool inventory_tool memory_tool memory_summarize_tool].each do |file|
      require Rails.root.join("app", "tools", file)
    rescue LoadError
      # Some tools may already be loaded; ignore
    end
  end

  test "available_tools returns array of tool schemas" do
    tools = ToolCallService.available_tools

    assert tools.is_a?(Array)
    assert tools.any? { |t| t[:function][:name] == "mock_tool" }
  end

  test "execute dispatches to correct tool class" do
    service = ToolCallService.new

    result = service.execute(
      tool_name: "mock_tool",
      arguments: { message: "hello" }
    )

    assert_equal true, result[:success]
    assert_includes result[:result], "Mock received: hello"
  end

  test "execute raises ArgumentError for unknown tool" do
    service = ToolCallService.new

    assert_raises(ArgumentError) do
      service.execute(tool_name: "nonexistent_tool", arguments: {})
    end
  end

  test "sandbox_path is passed to tool instances" do
    service = ToolCallService.new(sandbox_path: "/tmp/test_sandbox")

    result = service.execute(
      tool_name: "mock_tool",
      arguments: { message: "test" }
    )

    assert_includes result[:result], "sandbox: /tmp/test_sandbox"
  end

  test "execute handles string keys in arguments" do
    service = ToolCallService.new

    result = service.execute(
      tool_name: "mock_tool",
      arguments: { "message" => "string key test" }
    )

    assert_equal true, result[:success]
    assert_includes result[:result], "Mock received: string key test"
  end

  test "tool_class_for returns correct class" do
    tool_class = ToolCallService.tool_class_for("mock_tool")

    assert_equal MockTool, tool_class
  end

  test "tool_class_for returns nil for unknown tool" do
    tool_class = ToolCallService.tool_class_for("unknown")

    assert_nil tool_class
  end

  test "available_tools includes new DnD tools" do
    names = ToolCallService.available_tools.map { |t| t[:function][:name] }
    [
      DiceRollTool::NAME,
      SkillCheckTool::NAME,
      InventoryTool::NAME,
      MemoryTool::NAME,
      MemorySummarizeTool::NAME
    ].each do |tool_name|
      assert_includes names, tool_name
    end
  end
end

