# frontend/src/App.jsx

## Summary
- Root component that wires the chat experience.
- Pulls state and actions from `useChatStore`, fetches conversation/agent state on mount, and starts/stops version polling.
- Renders `ChatPage` for the main chat UI or `InspectorPage` when the path starts with `/inspector`.

## Key Behaviors
- On mount: `fetchConversation`, `fetchAgentState`, `startVersionPolling`; cleanup stops polling.
- Passes `messages`, `agentState`, `loading`, `error`, and `onSend` to `ChatPage`.
- Route switch uses `window.location.pathname` (no router) to select inspector vs chat.

## Related
- `frontend/src/store/chatStore.js` — data fetching and actions.
- `frontend/src/components/ChatPage.jsx` — chat UI shell.
- `frontend/src/pages/InspectorPage.jsx` — inspector view.

