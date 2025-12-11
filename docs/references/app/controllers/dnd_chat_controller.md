# app/controllers/dnd_chat_controller.rb

## Summary
- JSON API controller for DnD chat.
- Endpoints: messages (GET/POST), agent state/version, contracts, SPA entry.

## Key Behaviors
- Ensures sandbox paths; loads tools.
- `/dnd_chat/messages` POST runs LLM → tool call → summarizes to narrative; persists conversation with `{source,target,message}` only.
- `/dnd_chat/messages` GET returns conversation.
- `/dnd_chat/agent` and `/dnd_chat/agent/version` expose serialized state/version for inspector polling.
- Contracts served from docs; SPA serves built frontend.

## Related
- `DndChatWorkflow` for chat parameters.
- `ToolCallService` for tool execution.
- `Conversation`/`Message` models for payloads.


