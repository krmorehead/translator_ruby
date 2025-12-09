# app/models/message.rb

## Summary
- Plain value object for chat messages.
- Fields: `source`, `target`, `message`; optional `context` kept internal.

## Key Behaviors
- Normalizes strings, raises if required fields are blank.
- Optional `context` allowed but omitted from serialized hash unless present.
- `to_h` returns `{source, target, message}` (+ `context` if set).

## Related
- Used by `Conversation` and `DndChatController`.

