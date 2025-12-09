# Project Plan: DnD Chat UX

## Overview
Build a dark-themed web chat experience to play D&D with the LLM, leveraging the existing DnD tools and workflow. Provide a browser UI and HTTP endpoint that routes user input through `DndChatWorkflow` and `ToolCallService`, returning chat responses. Serialized workflow/memory state must carry a version number and expose a lightweight version endpoint so clients can poll for changes and fetch the full serialized state when the version updates.

## Goals
- Serve a dark-mode chat UI for user/DM interactions
- Route chat messages through the existing tool-calling workflow
- Validate the end-to-end flow with request tests
- DO NOT MOCK THE LLM in any tests (all time, all scopes)

## File Reference Guidance
- Each project `file_references.md` must include Document Tree sections with clear **Before** and **Added** layouts that list every relevant file path (existing and planned), matching the style used in `rules/update-documentation.mdc` and `docs/references/base_references.md`.
- Keep the trees in sync with the tables so the structure and descriptions do not drift.
- Example tree snippets:
```
Before
project/
├── existing_file.rb
└── docs/
    └── file_references.md

Added
project/
├── existing_file.rb
├── new_feature.rb
└── docs/
    └── file_references.md
```

## Architecture Guardrails
- Keep controllers thin: delegate to service objects (`DndChatWorkflow`, `ToolCallService`) and plain POROs like `Conversation` for aggregation.
- Contracts-first: add `/contract` endpoints and OpenAPI docs before implementing behaviors; keep request/response schemas aligned to the conversation and agent payloads.
- Single-purpose models: `Conversation` manages message arrays/ordering; `Message` encapsulates `source`, `target`, `message`; memory/inventory remain in their dedicated stores.
- Narrative-only chat thread: tool execution drives state, but the conversation API returns only story narration. Tool metadata belongs in the agent/inspector endpoints, not the chat messages.
- Shared abstractions: reuse existing tool registry and memory/inventory stores instead of duplicating logic in the chat layer.
- Frontend layers separate concerns: API client, state store, and UI components remain decoupled; avoid coupling state polling/version logic into view components directly.

---

## Milestone 1 - Ship React Chat UX (Vite)
Deliver a working dark-mode React SPA and backend endpoints that use the existing DnD tool workflow. Users only see DM/user chat; tool internals stay hidden. React is the default from day one (no future migration).

### 1.1 - Contracts and Chat Models
**Intent**: Define contracts and domain models for chat so schemas are locked before wiring controllers or UI.

**Details**:
- Add routes:
  - `/dnd_chat/messages/contract` (GET) returns OpenAPI contract for message endpoints
  - `/dnd_chat/messages` (GET) returns full conversation thread (Conversation -> array of messages with `source`, `target`, `message`)
  - `/dnd_chat/messages` (POST) sends a message; returns assistant reply plus updated conversation (narration only, no tool metadata)
  - `/dnd_chat/agent/contract` and `/dnd_chat/agent/version/contract` return OpenAPI contracts
  - `/dnd_chat/agent` (GET) and `/dnd_chat/agent/version` (GET) existing behavior
- Implement a `Conversation` class responsible for storing an array of message objects (`source`, `target`, `message`) and appending new messages
- Implement a `Message` model/PORO to encapsulate `source`, `target`, `message`, with basic validation/normalization
- Build `/contract` endpoints first when implementing any new API
- Error handling returns `success: false` with message

**Files**:
- `app/models/conversation.rb`
- `app/models/message.rb`
- `docs/api/contracts/dnd_chat_messages.yml`
- `docs/api/contracts/dnd_chat_agent.yml`

**Condensed API Contracts (endpoints + schemas)**:
- Schemas:
  - `Message`: `{ source: string, target: string, message: string }`
  - `Conversation`: `{ messages: Message[] }`
  - `PostMessageRequest`: `{ message: string }`
  - `PostMessageResponse`: `{ success: boolean, reply: string, conversation: Conversation, error?: string }`
  - `AgentState`: `{ success: true, version: number, state: object }`
  - `AgentVersion`: `{ success: true, version: number }`
  - `Error`: `{ success: false, error: string }`
- Endpoints (and contract twins):
  - `GET /dnd_chat/messages` → `Conversation` (200), `Error` (4xx/5xx)
  - `POST /dnd_chat/messages` → `PostMessageResponse` (200), `Error` (4xx/5xx)
  - `GET /dnd_chat/messages/contract` → OpenAPI for both message endpoints + schemas above
  - `GET /dnd_chat/agent` → `AgentState` (200), `Error` (4xx/5xx)
  - `GET /dnd_chat/agent/version` → `AgentVersion` (200), `Error` (4xx/5xx)
  - `GET /dnd_chat/agent/contract` → OpenAPI for `/agent` + `/agent/version` + shared schemas
  - `GET /dnd_chat/agent/version/contract` → OpenAPI for `/agent/version` + shared schemas
- Contract files:
  - `docs/api/contracts/dnd_chat_messages.yml`
  - `docs/api/contracts/dnd_chat_agent.yml`

**Tests**:
- `/dnd_chat/messages/contract` returns a valid OpenAPI document for GET/POST
- `Message` object accepts required fields and rejects missing `message` or `source/target`
- Contracts include schemas for `Message`, `Conversation`, `PostMessageRequest/Response`, `AgentState`, `AgentVersion`

---

### 1.2 - Chat Controller and Routes
**Intent**: Expose the chat/agent endpoints using the finalized contracts and models.

**Details**:
- Implement `DndChatController` actions for GET/POST `/dnd_chat/messages`, GET `/dnd_chat/agent`, GET `/dnd_chat/agent/version`, plus `/contract` twins.
- Wire `config/routes.rb` for the chat endpoints and contract routes.
- Integrate `DndChatWorkflow` and `ToolCallService` in the controller; return JSON only.
- Use `Conversation`/`Message` models for payload shape and validation.
- Error handling returns `success: false` with message.

**Files**:
- `app/controllers/dnd_chat_controller.rb`
- `config/routes.rb`
- `test/controllers/dnd_chat_controller_test.rb`

**Tests**:
- POST `/dnd_chat/messages` with real LLM returns `success: true`, reply payload, and conversation array
- GET `/dnd_chat/messages` returns the conversation array with message objects (schema: `source`, `target`, `message`)
- GET `/dnd_chat/agent` returns serialized state with version; `/contract` variants return valid OpenAPI

---

### 1.3 - Frontend Bootstrap (Vite Scaffold)
**Intent**: Initialize the React SPA scaffold with Vite so the project has a runnable base.

**Details**:
- Create `frontend/` Vite React app (`npm create vite@latest frontend -- --template react`)
- Ensure dev server runs; keep default entry wiring minimal
- Commit the baseline scaffold only (no UI wiring yet)

**Files**:
- `frontend/package.json`
- `frontend/vite.config.js`
- `frontend/index.html`
- `frontend/src/main.jsx`

**Tests**:
- Vite dev server runs and proxies API requests
- Production build emits to `public/dist/` and assets are served by Rails

---

### 1.4 - Frontend Tooling & Proxy Config
**Intent**: Add tooling and proxy settings to keep the frontend aligned with API and linting rules.

**Details**:
- Configure Vite proxy to Rails backend (port 3000) in `vite.config.js`
- Add ESLint config, base rules (React, JSX, testing), and Prettier compatibility if used
- Add lint/test scripts to `package.json` (e.g., `lint`, `test`, `dev`, `build`)
- Add minimal README notes for frontend usage
- Keep changes limited to tooling; UI still untouched

**Files**:
- `frontend/.eslintrc.json`
- `frontend/README.md`
- `frontend/package.json` (scripts)

**Tests**:
- Vite dev server proxies API requests
- Lint config loads without errors

---

### 1.5 - Build React Chat UI (Dark Theme) - Core Shell
**Intent**: Implement the core chat view containers with dark theme styling.

**Details**:
- Components: `App`, `ChatPage`, `ChatLog`, `Message`
- Port dark theme styles (CSS modules or styled-components)
- Implement scroll-to-latest, loading states, and message rendering for core log
- Ensure layout scaffolding supports input/inspector sections added next step

**Files**:
- `frontend/src/App.jsx`
- `frontend/src/components/ChatPage.jsx`
- `frontend/src/components/ChatLog.jsx`
- `frontend/src/components/Message.jsx`

**Tests**:
- Components render expected structure and dark theme classes
- Message list scrolls to bottom on new messages

---

### 1.6 - Build React Chat UI (Dark Theme) - Input & Inspector
**Intent**: Add user input, loading indicator, and agent inspector components.

**Details**:
- Components: `MessageInput`, `LoadingIndicator`, `AgentInspector`
- Wire props to allow external state/store to supply handlers and data
- Keep styles consistent with core shell

**Files**:
- `frontend/src/components/MessageInput.jsx`
- `frontend/src/components/LoadingIndicator.jsx`
- `frontend/src/components/AgentInspector.jsx`

**Tests**:
- Input renders and calls submit handler
- Loading indicator shows/hides based on prop
- Agent inspector renders provided data

---

### 1.7 - API Integration, Contracts, & State/Version Polling
**Intent**: Wire the React app to the Rails API with versioned state polling and contract-driven endpoints.

**Details**:
- API client: `sendMessage`, `getConversation` (GET messages), `getAgentState`, `getAgentVersion`
- Contracts: fetch `/dnd_chat/messages/contract`, `/dnd_chat/agent/contract`, `/dnd_chat/agent/version/contract` for schema-driven UI/validation
- State management via React Context or Zustand: chat messages, agent state, agent version, loading flags
- Poll `/dnd_chat/agent/version`; on change, fetch `/dnd_chat/agent`
- Handle errors gracefully and display error states

**Files**:
- `frontend/src/api/dndChatApi.js`
- `frontend/src/store/chatStore.js`

**Tests**:
- Sending a message updates UI with assistant reply and conversation state
- GET conversation returns thread matching contract (message objects with `source`, `target`, `message`, `context`)
- Version polling triggers state refresh when version changes
- Contract endpoints return valid OpenAPI documents consumed by the client

---

### 1.8 - Front-End Unit Tests (React)
**Intent**: Add fast, deterministic React unit tests with Vitest + React Testing Library.

**Details**:
- Test message submission, loading states, scroll behavior, and rendering
- Coverage targets (>80%)
- Use live Rails dev/test API (no mocks/stubs/fakes); configure test env to point at local API

**Files**:
- `frontend/src/test/setup.js`
- `frontend/src/components/__tests__/ChatPage.test.jsx`
- `frontend/src/components/__tests__/MessageInput.test.jsx`
- `frontend/src/components/__tests__/AgentInspector.test.jsx`

**Tests**:
- Vitest suite passes headless against local API
- API calls validated against real endpoints (no mocking)
- DOM updates and accessibility assertions pass

---

### 1.9 - E2E Tests (Playwright)
**Intent**: Validate full-browser behavior against the real Rails API and LLM.

**Details**:
- Playwright tests for sending messages, seeing assistant replies, dark theme presence, and agent inspector updates
- Run headless; support Chrome/Firefox/WebKit

**Files**:
- `frontend/playwright.config.js`
- `frontend/e2e/chat.spec.js`

**Tests**:
- E2E suite passes with real LLM/tool execution
- Agent inspector reflects updates after chat interactions

---

### 1.10 - Documentation Update
**Intent**: Record the React-first UX artifacts and workflows.

**Details**:
- Ensure `file_references.md` lists React/Vite files and tests
- Note how to run Rails API + Vite dev server, and how to serve production build

**Files**:
- `docs/projects/12-09-2025_dnd_chat_ux/file_references.md`
- `docs/projects/12-09-2025_dnd_chat_ux/project_plan.md`
- `frontend/README.md` (updated with run instructions)

**Tests**:
- Documentation review only

---

## Milestone 2 - Agent View (Serialized State)
Expose a separate agent/inspector view to display serialized memories (including quest log with main/current flags) and inventory in a consumable way.

### 2.1 - Agent/Inspector Endpoint
**Intent**: Provide a read-only endpoint (HTML and/or JSON) showing all memory sections and inventory for debugging/observability, with versioned serialized state for change detection.

**Details**:
- Route (e.g., `/dnd_chat/agent`) returning structured JSON and/or a lightweight inspector page
- Show sections: recent_conversation, quests, main_quest, current_goal, current_scene, people, misc, quest_log
- Include a version number in the serialized payload and expose a lightweight version-only endpoint (e.g., `/dnd_chat/agent/version`) that clients can poll; when the version differs, they fetch the full serialized state
- Show inventory items with quantities and properties

**Files**:
- `app/controllers/dnd_chat_controller.rb` (add agent/agent_version read endpoints if not present)
- `config/routes.rb` (agent/agent_version routes)
- `docs/api/contracts/dnd_chat_agent.yml` (ensure agent schemas include sections/inventory/version)

**Tests**:
- GET agent endpoint returns success
- Response includes all sections, inventory payload, and version field
- Version endpoint returns the current version and matches the full payload

---

## Milestone 3 - Workflow Integration & Error Handling
Keep tool internals hidden from users; ensure stable error handling and sandboxing.

### 3.1 - Workflow Wiring
**Intent**: Ensure chat POST uses `DndChatWorkflow` response_format, parses tool payload, executes via `ToolCallService`, and returns only the assistant reply (plus minimal metadata).

**Details**:
- Enforce response_format JSON schema (tool + arguments)
- Sandbox paths for memory/inventory
- Graceful errors returned as `success: false`

**Files**:
- `app/services/dnd_chat_workflow.rb`
- `app/services/tool_call_service.rb`
- `app/controllers/dnd_chat_controller.rb` (POST wiring)

**Tests**:
- Real LLM tool payload -> executes tool -> returns structured JSON
- Error path returns `success: false`

### 3.2 - Inspector Consistency (Memory)
**Intent**: Ensure the agent view reads the same memory sandbox and stays read-only.

**Details**:
- Agent endpoint reads from the same memory sandbox files used by chat
- No mutations allowed in inspector for memory data

**Files**:
- `app/controllers/dnd_chat_controller.rb`
- `app/models/memory_store.rb`
- `app/models/memories/*`

**Tests**:
- After a chat write, agent view shows updated memory sections and version bump

---

### 3.3 - Inspector Consistency (Inventory)
**Intent**: Ensure the agent view reads the same inventory sandbox and stays read-only.

**Details**:
- Agent endpoint reads from the shared inventory store/items
- No mutations allowed in inspector for inventory data

**Files**:
- `app/controllers/dnd_chat_controller.rb`
- `app/models/inventory_item.rb`

**Tests**:
- After a chat write that affects inventory, agent view shows updated inventory and version bump

---

## Milestone 4 - E2E Test Suite
Validate the full DM/user chat flow end-to-end (tool details remain hidden from the user) with real LLM/tool execution and versioned serialized state.

### 4.1 - Chat Flow E2E
**Intent**: Exercise a user prompt through the live workflow, execute real LLM tool payloads, and render the assistant reply.

**Details**:
- Use real LLM responses with tool calls and run through controller POST
- Assert returned reply field is present, tools execute, and versioned state updates

**Files**:
- `frontend/e2e/chat.spec.js`
- `frontend/playwright.config.js`
- `docs/projects/12-09-2025_dnd_chat_ux/file_references.md` (list E2E artifacts)

**Tests**:
- POST `/dnd_chat/messages` with real LLM -> `success: true`, `reply` present, `tool` and `arguments` populated
- After POST, fetch `/dnd_chat/agent/version`; if the version changed, fetch `/dnd_chat/agent` and assert inventory/memory updates

### 4.2 - Agent View E2E
**Intent**: Ensure agent endpoint reflects state after chat mutations using real workflow execution.

**Details**:
- After a real chat write, GET agent endpoint shows the change and version increments

**Files**:
- `frontend/e2e/chat.spec.js` (extend/add scenarios)
- `frontend/playwright.config.js`

**Tests**:
- Agent endpoint returns updated inventory/memory and a higher version after prior POST

### 4.3 - Documentation Check
**Intent**: Keep references and runbook notes aligned with the shipped E2E suite.

**Details**:
- Ensure `file_references.md` lists created files and test files
- Note how to run the chat server (via Rails server) and the endpoints

**Files**:
- `docs/projects/12-09-2025_dnd_chat_ux/file_references.md`
- `docs/projects/12-09-2025_dnd_chat_ux/project_plan.md`

**Tests**:
- Documentation review only

## Milestone 5 - LLM Manual Interaction via cURL
Provide steps and examples for interacting with the live endpoints manually using cURL to validate behavior with the real LLM and versioned serialized state.

### 5.1 - Manual cURL Flows
**Intent**: Enable manual verification of chat and inspector endpoints.

**Details**:
- Document cURL commands to send chat messages to `/dnd_chat/messages`
- Document polling `/dnd_chat/agent/version` and fetching `/dnd_chat/agent` when the version changes
- Example commands (adjust host/port):
  - `curl -X POST http://localhost:4000/dnd_chat/messages -H "Content-Type: application/json" -d '{"message":"Scout the tavern"}'`
  - `curl http://localhost:4000/dnd_chat/agent/version`
  - `curl http://localhost:4000/dnd_chat/agent`

**Files**:
- `docs/projects/12-09-2025_dnd_chat_ux/file_references.md`
- `docs/projects/12-09-2025_dnd_chat_ux/project_plan.md`
- `frontend/README.md` (optional snippet placement)

**Tests**:
- Manual verification only; ensure commands are documented and usable

---

