# app/tools/base_tool.rb

## Summary
- Base class for all chat tools.
- Provides success/error result helpers and sandbox path handling.

## Key Behaviors
- `success_result` / `error_result` helpers normalize tool outputs.
- Stores `sandbox_path` for file-based tools.

## Related
- Inherited by all tools in `app/tools`.

