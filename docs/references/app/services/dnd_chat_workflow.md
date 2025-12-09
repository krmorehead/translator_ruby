# app/services/dnd_chat_workflow.rb

## Summary
- Builds standardized chat parameters for the DnD tools workflow.
- Sets system prompt and tool schemas; enforces response_format JSON schema.

## Key Behaviors
- Uses `ToolCallService.available_dnd_tools` to supply functions.
- System prompt instructs tool use, scene creation, and persistence rules.
- `chat_parameters` accepts user prompt, model override, extra system prompt.

## Related
- Consumed by `DndChatController` for chat requests.
- Works with `ToolCallService`.

