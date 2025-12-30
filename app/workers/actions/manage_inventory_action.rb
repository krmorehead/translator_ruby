# frozen_string_literal: true

module Actions
  # Action to add, remove, or check inventory items.
  class ManageInventoryAction < BaseAction
    def execute(action:, item:, quantity: 1)
      quantity = quantity.to_i
      action_type = action.to_s.downcase

      case action_type
      when "add"
        add_item(item, quantity)
      when "remove"
        remove_item(item, quantity)
      when "check"
        check_item(item)
      else
        failure_result(error: "Unknown inventory action: #{action}. Use add, remove, or check.")
      end
    end

    
    def add_item(item, quantity)
      memory_store.update_section(
        name: MemoryKinds::INVENTORY,
        content: { item: item, quantity: quantity, action: "added", timestamp: Time.now.utc.iso8601 },
        append: true
      )

      success_result(
        result: "Added #{quantity}x #{item} to inventory",
        summary: "Inventory updated",
        metadata: { item: item, quantity: quantity, action: "add" }
      )
    end

    def remove_item(item, quantity)
      # Check if item exists first
      inventory = memory_store.get_section(MemoryKinds::INVENTORY) || []
      item_entries = inventory.select { |i| (i[:item] || i["item"]).to_s.downcase == item.downcase }

      if item_entries.empty?
        return failure_result(error: "#{item} not found in inventory")
      end

      memory_store.update_section(
        name: MemoryKinds::INVENTORY,
        content: { item: item, quantity: -quantity, action: "removed", timestamp: Time.now.utc.iso8601 },
        append: true
      )

      success_result(
        result: "Removed #{quantity}x #{item} from inventory",
        summary: "Inventory updated",
        metadata: { item: item, quantity: quantity, action: "remove" }
      )
    end

    def check_item(item)
      inventory = memory_store.get_section(MemoryKinds::INVENTORY) || []

      # Calculate net quantity for the item
      total = 0
      inventory.each do |entry|
        entry_item = (entry[:item] || entry["item"]).to_s
        next unless entry_item.downcase == item.downcase

        qty = (entry[:quantity] || entry["quantity"]).to_i
        total += qty
      end

      if total > 0
        success_result(
          result: "You have #{total}x #{item}",
          summary: "Inventory check: #{total}x #{item}",
          metadata: { item: item, quantity: total, found: true }
        )
      else
        success_result(
          result: "You don't have any #{item}",
          summary: "Inventory check: no #{item}",
          metadata: { item: item, quantity: 0, found: false }
        )
      end
    end
  end
end

