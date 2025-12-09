# app/tools/memory_tool.rb

## Summary
- Reads/updates narrative memory sections stored via `MemoryStore`.

## Key Behaviors
- Operations: list sections, get section, update section (append/replace).
- Validates sections against `MemoryKinds::ALL`.
- Normalizes arguments and content, supports sandbox path.

## Related
- Registered in `ToolCallService`.
- Uses `MemoryStore` and `MemoryKinds`.

