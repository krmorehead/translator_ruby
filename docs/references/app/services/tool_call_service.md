# app/services/tool_call_service.rb

## Summary
- Registers and executes tools for the chat workflow.
- Central registry for tool schemas and dispatch.

## Key Behaviors
- `register_tool` adds tool classes; `available_dnd_tools` filters by allowed names.
- `tool_class_for` resolves a tool by name_identifier.
- `execute` instantiates tool with sandbox_path and calls `execute`.

## Related
- Used by `DndChatWorkflow` and `DndChatController`.
- Tools under `app/tools/*`.


