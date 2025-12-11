# frontend/src/store/chatStore.js

## Summary
- Zustand store managing chat state, API calls, and version polling.

## Key Behaviors
- State: `messages`, `agentState`, `loading`, `error`, `polling`.
- Actions:
  - `fetchConversation` (GET `/dnd_chat/messages`, once)
  - `fetchAgentState` (GET `/dnd_chat/agent`)
  - `sendChatMessage` (POST `/dnd_chat/messages`, optimistic append, refresh agent state)
  - `startVersionPolling`/`stopVersionPolling` (poll `/dnd_chat/agent/version`, refresh state on version change)
- Error handling sets `error` and clears loading.

## Related
- API calls in `frontend/src/api/dndChatApi.js`.
- Used by `App.jsx` to drive UI.


