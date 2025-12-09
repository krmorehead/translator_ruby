# frontend/src/components/MessageInput.jsx

## Summary
- Text input and send button for chat messages.
- Handles Enter key or button click to submit a trimmed message.

## Key Behaviors
- Keeps local `text` state; uses a ref to clear/focus after send.
- `handleSend` trims input, no-op if empty, then calls `onSend` and clears the field.
- Disables input/button when `disabled` is true; Enter key submission is supported.

## Props
- `onSend(text: string)` — required.
- `disabled` (bool) — disables input/button when true.

## Related
- Used by `ChatPage.jsx`.

