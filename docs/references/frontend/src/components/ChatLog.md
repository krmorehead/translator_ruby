# frontend/src/components/ChatLog.jsx

## Summary
- Renders the scrollable conversation history.
- Applies layout/styling per message source (user vs assistant).

## Key Behaviors
- Iterates `messages` array and renders `Message` components.
- Uses ref to auto-scroll to the latest message on updates.
- Expects each message to have `source`, `target`, and `message`.

## Related
- `frontend/src/components/Message.jsx` — individual bubble.
- `frontend/src/components/chat.css` — styles.

