require "test_helper"

class InventoryToolTest < ActiveSupport::TestCase
  def setup
    @test_path = Rails.root.join("test", "tool_test", "inventory_tool_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@test_path)
    @tool = InventoryTool.new
  end

  def teardown
    FileUtils.rm_rf(@test_path) if File.exist?(@test_path)
  end

  test "schema includes operations" do
    schema = InventoryTool.schema
    ops = schema[:function][:parameters][:properties][:operation][:enum]
    assert_includes ops, InventoryTool::OP_ADD_ITEM
    assert_includes ops, InventoryTool::OP_LIST
  end

  test "add item creates inventory file" do
    result = @tool.execute(operation: InventoryTool::OP_ADD_ITEM, path: File.join(@test_path, "inventory.json"), name: "Torch", weight: 1, description: "Light", property_type: "gear", quantity: 2)

    assert result[:success]
    file_path = File.join(@test_path, "inventory.json")
    assert File.exist?(file_path)

    data = JSON.parse(File.read(file_path))
    assert_equal "Torch", data.first["name"]
    assert_equal 2, data.first["quantity"]
  end

  test "update quantity" do
    inv_path = File.join(@test_path, "inventory.json")
    @tool.execute(operation: InventoryTool::OP_ADD_ITEM, path: inv_path, name: "Arrow", weight: 0.1, description: "Ammo", property_type: "ammo", quantity: 5)
    result = @tool.execute(operation: InventoryTool::OP_UPDATE_QUANTITY, path: inv_path, name: "Arrow", quantity: 10)

    assert result[:success]
    assert_equal 10, result[:result][:quantity]
  end

  test "remove item" do
    inv_path = File.join(@test_path, "inventory.json")
    @tool.execute(operation: InventoryTool::OP_ADD_ITEM, path: inv_path, name: "Potion", weight: 0.5, description: "Healing", property_type: "consumable", quantity: 1)
    result = @tool.execute(operation: InventoryTool::OP_REMOVE_ITEM, path: inv_path, name: "Potion")

    assert result[:success]
    list = @tool.execute(operation: "list_inventory", path: inv_path)
    assert_equal [], list[:result]
  end

  test "get item returns error when missing" do
    result = @tool.execute(operation: InventoryTool::OP_GET, path: File.join(@test_path, "inventory.json"), name: "Missing")

    refute result[:success]
    assert_includes result[:error], "Item not found"
  end

  test "list inventory returns items" do
    inv_path = File.join(@test_path, "inventory.json")
    @tool.execute(operation: InventoryTool::OP_ADD_ITEM, path: inv_path, name: "Rope", weight: 10, description: "50ft", property_type: "gear", quantity: 1)
    result = @tool.execute(operation: InventoryTool::OP_LIST, path: inv_path)

    assert result[:success]
    assert_equal 1, result[:result].size
    assert_equal "Rope", result[:result].first[:name] || result[:result].first["name"]
  end

  test "requires name for update operations" do
    result = @tool.execute(operation: InventoryTool::OP_UPDATE_QUANTITY, path: File.join(@test_path, "inventory.json"), quantity: 1)

    refute result[:success]
    assert_includes result[:error], "name"
  end
end
