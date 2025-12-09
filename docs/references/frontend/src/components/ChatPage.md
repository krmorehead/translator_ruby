# frontend/src/components/ChatPage.jsx

## Summary
- Main chat layout container.
- Shows the conversation log, error banner, input, and agent inspector side panel.

## Key Behaviors
- Renders `ChatLog` with provided `messages`.
- Shows `LoadingIndicator` when `loading` is true.
- Displays error banner when `error` is non-empty.
- Renders `MessageInput` to submit user text via `onSend`.
- Renders `AgentInspector` with `agentState`.

## Props
- `messages` (array of `{source,target,message}`)
- `onSend(text: string)` — invoked on user submit.
- `loading` (bool), `agentState` (object), `error` (string).

## Related
- `frontend/src/components/ChatLog.jsx`
- `frontend/src/components/MessageInput.jsx`
- `frontend/src/components/AgentInspector.jsx`

