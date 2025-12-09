# docs/api/contracts/dnd_chat_messages.yml

## Summary
- OpenAPI contract for DnD chat messages.
- Conversation schema is narration-only: each message has `source`, `target`, and `message`.
- POST `/dnd_chat/messages` returns `success`, `reply`, and updated `conversation`; tool metadata is not part of the response.

## Key Details
- Message schema omits tool/arguments/result/context; narrative is produced server-side.
- Conversation schema wraps an array of `Message`.
- Error schema is `{ success: false, error: string }`.

## Related
- Used by `DndChatController` message endpoints.
- Agent/inspector contracts live in `docs/api/contracts/dnd_chat_agent.yml`.

