# app/tools/inventory_tool.rb

## Summary
- Manages inventory items via `InventoryStore`.

## Key Behaviors
- Operations: add item, remove item, update quantity, list, get item.
- Normalizes nested item hashes; ensures name/quantity where required.
- Uses sandbox path default when no path provided.

## Related
- Registered in `ToolCallService`.
- Depends on `InventoryStore` and `InventoryItem`.


