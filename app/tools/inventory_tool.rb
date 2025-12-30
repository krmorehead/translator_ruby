# frozen_string_literal: true


# LLM-callable tool for managing inventory via InventoryStore.
class InventoryTool < BaseTool
  NAME = "inventory".freeze
  OP_ADD_ITEM = "add_item".freeze
  OP_REMOVE_ITEM = "remove_item".freeze
  OP_UPDATE_QUANTITY = "update_quantity".freeze
  OP_LIST = "list_inventory".freeze
  OP_GET = "get_item".freeze

  def self.name_identifier
    NAME
  end

  def self.description
    "Manage inventory: add, remove, update quantity, list, or get an item."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        operation: {
          type: "string",
          description: "Operation to perform (defaults to add_item if not specified)",
          enum: [
            OP_ADD_ITEM,
            OP_REMOVE_ITEM,
            OP_UPDATE_QUANTITY,
            OP_LIST,
            OP_GET
          ]
        },
        path: {
          type: "string",
          description: "Inventory file path (optional, defaults to agent data path)"
        },
        name: { type: "string", description: "Item name" },
        weight: { type: "number", description: "Item weight" },
        description: { type: "string", description: "Item description" },
        property_type: { type: "string", description: "Item type" },
        quantity: { type: "integer", description: "Item quantity" }
      },
      required: [],
      additionalProperties: false
    }
  end

  def execute(operation: OP_ADD_ITEM, path: nil, name: nil, weight: nil, description: nil, property_type: nil, quantity: nil)
    op, store_path, normalized = normalize_args(operation, path, name, weight, description, property_type, quantity)
    store = InventoryStore.new(path: store_path)

    case op
    when OP_ADD_ITEM
      item = InventoryItem.new(
        name: normalized[:name],
        weight: normalized[:weight],
        description: normalized[:description],
        property_type: normalized[:property_type],
        quantity: normalized[:quantity] || 1
      )
      store.add_or_update_item(item)
      success_result(item.to_h)
    when OP_REMOVE_ITEM
      ensure_name!(normalized[:name])
      store.remove_item(normalized[:name])
      success_result({ removed: normalized[:name] })
    when OP_UPDATE_QUANTITY
      ensure_name!(normalized[:name])
      raise ArgumentError, "quantity required" if normalized[:quantity].nil?
      store.update_quantity(normalized[:name], normalized[:quantity])
      success_result({ name: normalized[:name], quantity: normalized[:quantity] })
    when OP_LIST
      success_result(store.to_a)
    when OP_GET
      ensure_name!(normalized[:name])
      item = store.find_item(normalized[:name])
      if item
        success_result(item.to_h)
      else
        error_result("Item not found: #{normalized[:name]}")
      end
    else
      error_result("Unsupported operation: #{op}")
    end
  rescue ArgumentError => e
    error_result(e.message)
  end

  
  def ensure_name!(name)
    raise ArgumentError, "name required" if name.to_s.strip.empty?
  end

  def normalize_args(operation, path, name, weight, description, property_type, quantity)
    op = operation || OP_ADD_ITEM
    op = OP_ADD_ITEM if op == "add"
    op = OP_REMOVE_ITEM if op == "remove"
    store_path = path || default_file_path

    # Allow a nested item hash
    if name.is_a?(Hash)
      item_hash = name
      name = item_hash[:name] || item_hash["name"]
      weight ||= item_hash[:weight] || item_hash["weight"]
      description ||= item_hash[:description] || item_hash["description"]
      property_type ||= item_hash[:property_type] || item_hash["property_type"] || item_hash[:type] || item_hash["type"]
      quantity ||= item_hash[:quantity] || item_hash["quantity"]
    end

    normalized = {
      name: name,
      weight: weight,
      description: description,
      property_type: property_type,
      quantity: quantity
    }

    [ op, store_path, normalized ]
  end
end

# Register with ToolCallService
ToolCallService.register_tool(InventoryTool)
