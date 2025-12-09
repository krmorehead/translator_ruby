# File References: DnD Chat UX

## Document Trees

**Before**
```
app/
├── models/
│   ├── inventory_item.rb
│   ├── memory_kinds.rb
│   ├── memory_store.rb
│   └── memories/
│       └── ...
├── services/
│   ├── dnd_chat_workflow.rb
│   └── tool_call_service.rb
├── tools/
│   └── ...
config/
└── routes.rb
docs/
└── projects/
    └── 12-09-2025_dnd_chat_ux/
        ├── file_references.md
        └── project_plan.md
```

**After**
```
app/
├── controllers/
│   └── dnd_chat_controller.rb
├── models/
│   ├── inventory_item.rb
│   ├── memory_kinds.rb
│   ├── memory_store.rb
│   └── memories/
│       └── ...
├── services/
│   ├── dnd_chat_workflow.rb
│   └── tool_call_service.rb
├── tools/
│   └── ...
config/
└── routes.rb
docs/
├── api/
│   └── contracts/
│       ├── dnd_chat_agent.yml
│       └── dnd_chat_messages.yml
└── projects/
    └── 12-09-2025_dnd_chat_ux/
        ├── file_references.md
        └── project_plan.md
frontend/
├── .eslintrc.json
├── e2e/
│   └── chat.spec.js
├── package.json
├── playwright.config.js
├── README.md
├── src/
│   ├── App.jsx
│   ├── api/
│   │   └── dndChatApi.js
│   ├── components/
│   │   ├── AgentInspector.jsx
│   │   ├── ChatLog.jsx
│   │   ├── ChatPage.jsx
│   │   ├── LoadingIndicator.jsx
│   │   ├── Message.jsx
│   │   ├── MessageInput.jsx
│   │   └── __tests__/
│   │       ├── AgentInspector.test.jsx
│   │       ├── ChatPage.test.jsx
│   │       └── MessageInput.test.jsx
│   ├── store/
│   │   └── chatStore.js
│   └── test/
│       └── setup.js
├── vite.config.js
└── dist/
    └── ... (build output)
test/
└── controllers/
    └── dnd_chat_controller_test.rb
```

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/services/dnd_chat_workflow.rb` | Builds LLM params with tool schemas | Backend chat orchestration |
| `app/services/tool_call_service.rb` | Dispatches tool executions | Executes LLM tool calls |
| `app/tools/*` | DnD tools (dice, skill, inventory, memory) | Tool catalogue for chat |
| `app/models/memory_store.rb` | Memory persistence | Memory operations |
| `app/models/memory_kinds.rb` | Memory section constants | Section definitions |
| `app/models/memories/*` | Memory subclasses + registry | Quest log and section behaviors |
| `app/models/inventory_item.rb` | Inventory item model | Inventory data for UI ops |
| `config/routes.rb` | Routing for adding chat endpoint | Add chat UI routes |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/controllers/dnd_chat_controller.rb` | Chat JSON endpoints (messages, agent, version) | Step 1.1 |
| `test/controllers/dnd_chat_controller_test.rb` | Request tests for API endpoints | Step 1.1 |
| `docs/projects/12-09-2025_dnd_chat_ux/project_plan.md` | Project plan document | Step 1.0 |
| `docs/api/contracts/dnd_chat_messages.yml` | OpenAPI for messages (GET/POST, conversation) | Step 1.1 |
| `docs/api/contracts/dnd_chat_agent.yml` | OpenAPI for agent + version | Step 1.1 |

## React Frontend Files (Milestone 1)

| File Path | Description | Created In |
|-----------|-------------|------------|
| `frontend/package.json` | React app dependencies and scripts | Step 1.2 |
| `frontend/vite.config.js` | Vite build configuration with proxy | Step 1.2 |
| `frontend/.eslintrc.json` | ESLint configuration | Step 1.2 |
| `frontend/src/App.jsx` | Root React component | Step 1.3 |
| `frontend/src/components/ChatPage.jsx` | Main chat page container | Step 1.3 |
| `frontend/src/components/ChatLog.jsx` | Scrollable message history | Step 1.3 |
| `frontend/src/components/Message.jsx` | Individual message bubble | Step 1.3 |
| `frontend/src/components/MessageInput.jsx` | Text input + send button | Step 1.3 |
| `frontend/src/components/LoadingIndicator.jsx` | Loading state display | Step 1.3 |
| `frontend/src/components/AgentInspector.jsx` | Memory/inventory view | Step 1.3 |
| `frontend/src/api/dndChatApi.js` | API client for Rails backend | Step 1.4 |
| `frontend/src/store/chatStore.js` | State management (Context/Zustand) | Step 1.4 |
| `frontend/src/test/setup.js` | Vitest test setup | Step 1.5 |
| `frontend/src/components/__tests__/ChatPage.test.jsx` | ChatPage component tests | Step 1.5 |
| `frontend/src/components/__tests__/MessageInput.test.jsx` | MessageInput tests | Step 1.5 |
| `frontend/src/components/__tests__/AgentInspector.test.jsx` | AgentInspector tests | Step 1.5 |
| `frontend/playwright.config.js` | Playwright E2E test config | Step 1.6 |
| `frontend/e2e/chat.spec.js` | E2E tests for chat flow | Step 1.6 |
| `frontend/README.md` | Frontend-specific documentation | Step 1.7 |
