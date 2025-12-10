# frozen_string_literal: true

require "test_helper"

class ActionRecordTest < ActiveSupport::TestCase
  test "initializes with required attributes and defaults" do
    record = ActionRecord.new(prompt_reference: "open door", tool_name: "open", arguments: { target: "door" })

    assert_predicate record.id, :present?
    assert_equal "open door", record.prompt_reference
    assert_equal "open", record.tool_name
    assert_equal({ target: "door" }, record.arguments)
    assert_equal :pending, record.status
    assert_nil record.result
    assert_nil record.consequence
    assert_nil record.error
    assert_kind_of Time, record.timestamp
  end

  test "requires tool_name and arguments" do
    assert_raises(ArgumentError) { ActionRecord.new(prompt_reference: "x", tool_name: nil, arguments: {}) }
    assert_raises(ArgumentError) { ActionRecord.new(prompt_reference: "x", tool_name: "t", arguments: "bad") }
  end

  test "with returns new instance and keeps immutability" do
    record = ActionRecord.new(prompt_reference: "inspect", tool_name: "inspect_room", arguments: { target: "table" })
    updated = record.with(status: :executed, result: { success: true })

    assert_equal :pending, record.status
    assert_equal :executed, updated.status
    assert_equal({ success: true }, updated.result)
    refute_equal record.object_id, updated.object_id
  end

  test "to_h serializes all attributes" do
    timestamp = Time.now
    record = ActionRecord.new(
      prompt_reference: "pickup",
      tool_name: "pickup_item",
      arguments: { item: "sword" },
      id: "123",
      status: :executed,
      result: { success: true },
      consequence: "You grab the sword.",
      error: nil,
      timestamp: timestamp
    )

    hash = record.to_h

    assert_equal "123", hash[:id]
    assert_equal "pickup", hash[:prompt_reference]
    assert_equal "pickup_item", hash[:tool_name]
    assert_equal({ item: "sword" }, hash[:arguments])
    assert_equal :executed, hash[:status]
    assert_equal({ success: true }, hash[:result])
    assert_equal "You grab the sword.", hash[:consequence]
    assert_nil hash[:error]
    assert_equal timestamp, hash[:timestamp]
  end
end

