require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  test "attributes and bracket access" do
    item = InventoryItem.new(
      name: "Torch",
      weight: 1.0,
      description: "Light",
      property_type: "gear",
      quantity: 2
    )

    assert_equal "Torch", item[:name]
    assert_equal "Torch", item["name"]
    assert_equal 1.0, item[:weight]
    assert_equal "Light", item[:description]
    assert_equal "gear", item[:property_type]
    assert_equal 2, item[:quantity]

    attrs = item.attributes
    assert_equal "Torch", attrs[:name]
    assert_equal 2, attrs[:quantity]
  end

  test "to_json uses attributes" do
    item = InventoryItem.new(
      name: "Rope",
      weight: 10,
      description: "50ft",
      property_type: "gear",
      quantity: 1
    )

    json = JSON.parse(item.to_json)
    assert_equal "Rope", json["name"]
    assert_equal 1, json["quantity"]
  end
end
