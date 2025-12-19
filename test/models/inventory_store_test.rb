require "test_helper"

class InventoryStoreTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "inventory_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @path = File.join(@sandbox_path, "inventory.json")
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  def new_store
    InventoryStore.new(path: @path)
  end

  test "load empty when file missing" do
    store = new_store
    assert_equal [], store.all_items
  end

  test "serialize and deserialize round-trip" do
    store = new_store
    item = InventoryItem.new(name: "Rope", weight: 10, description: "50ft hemp", property_type: "gear", quantity: 1)
    store.add_or_update_item(item)

    reloaded = new_store
    loaded_item = reloaded.find_item("Rope")

    assert_not_nil loaded_item
    assert_equal item.name, loaded_item.name
    assert_equal item.weight, loaded_item.weight
    assert_equal item.description, loaded_item.description
    assert_equal item.property_type, loaded_item.property_type
    assert_equal item.quantity, loaded_item.quantity
  end

  test "add then update quantity" do
    store = new_store
    store.add_or_update_item(InventoryItem.new(name: "Arrow", weight: 0.1, description: "Ammo", property_type: "ammo", quantity: 5))
    store.update_quantity("Arrow", 8)

    item = store.find_item("Arrow")
    assert_equal 8, item.quantity
  end

  test "remove item" do
    store = new_store
    store.add_or_update_item(InventoryItem.new(name: "Potion", weight: 0.5, description: "Healing", property_type: "consumable", quantity: 2))
    store.remove_item("Potion")

    assert_nil store.find_item("Potion")
    assert_equal [], store.all_items
  end

  test "reject negative quantities" do
    store = new_store
    assert_raises(ArgumentError) do
      store.add_or_update_item(InventoryItem.new(name: "Gold", weight: 0, description: "Coins", property_type: "currency", quantity: -1))
    end

    store.add_or_update_item(InventoryItem.new(name: "Gold", weight: 0, description: "Coins", property_type: "currency", quantity: 5))
    assert_raises(ArgumentError) do
      store.update_quantity("Gold", -2)
    end
  end

end
