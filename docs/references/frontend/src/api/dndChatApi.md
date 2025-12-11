# frontend/src/api/dndChatApi.js

## Summary
- Fetch helpers for DnD chat backend.
- Provides chat send, conversation read, agent state/version, and contracts.

## Endpoints
- `sendMessage(message)` → POST `/dnd_chat/messages`
- `getConversation()` → GET `/dnd_chat/messages`
- `getAgentState()` → GET `/dnd_chat/agent`
- `getAgentVersion()` → GET `/dnd_chat/agent/version`
- `getMessagesContract()` → GET `/dnd_chat/messages/contract`
- `getAgentContract()` → GET `/dnd_chat/agent/contract`

## Notes
- Uses JSON headers for POST.
- Throws on non-OK responses with error message.


