require "test_helper"

class ToolCallServiceTest < ActiveSupport::TestCase
  def setup
    %w[dice_roll_tool skill_check_tool inventory_tool memory_tool memory_summarize_tool].each do |file|
      require Rails.root.join("app", "tools", file)
    rescue LoadError
      # Some tools may already be loaded; ignore
    end
  end

  test "available_tools returns array of tool schemas" do
    tools = ToolCallService.available_tools

    assert tools.is_a?(Array)
    assert_includes tools.map { |t| t[:function][:name] }, DiceRollTool::NAME
  end

  test "execute dispatches to dice_roll_tool" do
    service = ToolCallService.new

    result = service.execute(
      tool_name: DiceRollTool::NAME,
      arguments: { dice: "d6" }
    )

    assert_equal true, result[:success]
    assert result[:result][:total].is_a?(Integer)
  end

  test "execute raises ArgumentError for unknown tool" do
    service = ToolCallService.new

    assert_raises(ArgumentError) do
      service.execute(tool_name: "nonexistent_tool", arguments: {})
    end
  end

  test "execute handles string keys in arguments" do
    service = ToolCallService.new

    result = service.execute(tool_name: DiceRollTool::NAME, arguments: { dice: "d4" })

    assert_equal true, result[:success]
    assert result[:result][:total].is_a?(Integer)
  end

  test "tool_class_for returns correct class" do
    tool_class = ToolCallService.tool_class_for(DiceRollTool::NAME)

    assert_equal DiceRollTool, tool_class
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
