# frontend/src/components/AgentInspector.jsx

## Summary
- Displays agent state: memories and inventory with version info.
- Read-only view for debugging/observability.

## Key Behaviors
- Shows version number and renders memory sections and inventory lists.
- Accepts arbitrary memory/inventory shapes and renders JSON snippets.

## Props
- `agentState`: `{ version: number, state: { memories: object, inventory: array } }`

## Related
- Consumed by `ChatPage.jsx`.

