# Project Plan: DnD Chat UX

## Overview
Build a dark-themed web chat experience to play D&D with the LLM, leveraging the existing DnD tools and workflow. Provide a browser UI and HTTP endpoint that routes user input through `DndChatWorkflow` and `ToolCallService`, returning chat responses. Serialized workflow/memory state must carry a version number and expose a lightweight version endpoint so clients can poll for changes and fetch the full serialized state when the version updates.

## Goals
- Serve a dark-mode chat UI for user/DM interactions
- Route chat messages through the existing tool-calling workflow
- Validate the end-to-end flow with request tests
- DO NOT MOCK THE LLM in any tests (all time, all scopes)

## File Reference Guidance
- Each project `file_references.md` must include Document Tree sections with clear **Before** and **After** layouts that list every relevant file path (existing and planned), matching the style used in `rules/update-documentation.mdc` and `docs/references/base_references.md`.
- Keep the trees in sync with the tables so the structure and descriptions do not drift.
- Example tree snippets:
```
Before
project/
├── existing_file.rb
└── docs/
    └── file_references.md

After
project/
├── existing_file.rb
├── new_feature.rb
└── docs/
    └── file_references.md
```

---

## Milestone 1 - Ship React Chat UX (Vite)
Deliver a working dark-mode React SPA and backend endpoints that use the existing DnD tool workflow. Users only see DM/user chat; tool internals stay hidden. React is the default from day one (no future migration).

### 1.1 - Add Chat API Routes, Contracts, and Controller
**Intent**: Provide backend endpoints (with contract-first variants) for chat messages and agent state that the React app will consume.

**Details**:
- Add routes:
  - `/dnd_chat/messages/contract` (GET) returns OpenAPI contract for message endpoints
  - `/dnd_chat/messages` (GET) returns full conversation thread (Conversation -> array of messages with `source`, `target`, `message`, `context`)
  - `/dnd_chat/messages` (POST) sends a message; returns assistant reply plus updated conversation
  - `/dnd_chat/agent/contract` and `/dnd_chat/agent/version/contract` return OpenAPI contracts
  - `/dnd_chat/agent` (GET) and `/dnd_chat/agent/version` (GET) existing behavior
- Implement a `Conversation` class responsible for storing an array of message objects (`source`, `target`, `message`, `context`) and appending new messages
- Controller actions call `DndChatWorkflow` and `ToolCallService`, returning JSON only
- Build `/contract` endpoints first when implementing any new API
- Error handling returns `success: false` with message

**Condensed API Contracts (endpoints + schemas)**:
- Schemas:
  - `Message`: `{ source: string, target: string, message: string, context: object|null }`
  - `Conversation`: `{ messages: Message[] }`
  - `PostMessageRequest`: `{ message: string }`
  - `PostMessageResponse`: `{ success: boolean, reply: string, conversation: Conversation, tool?: string, arguments?: object, result?: object, error?: string }`
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
- POST `/dnd_chat/messages` with real LLM returns `success: true`, reply payload, and conversation array
- GET `/dnd_chat/messages` returns the conversation array with message objects (schema: `source`, `target`, `message`, `context`)
- GET `/dnd_chat/agent` returns serialized state with version; `/contract` variants return valid OpenAPI

---

### 1.2 - React + Vite Setup
**Intent**: Initialize the React SPA with Vite and proxy to Rails API.

**Details**:
- Create `frontend/` Vite React app (`npm create vite@latest frontend -- --template react`)
- Configure Vite dev proxy to Rails backend (port 3000)
- Add ESLint + Prettier; update `.gitignore`
- Configure production build output to `public/dist/`; ensure Rails serves static assets

**Tests**:
- Vite dev server runs and proxies API requests
- Production build emits to `public/dist/` and assets are served by Rails

---

### 1.3 - Build React Chat UI (Dark Theme)
**Intent**: Implement the dark-themed chat UI in React.

**Details**:
- Components: `App`, `ChatPage`, `ChatLog`, `Message`, `MessageInput`, `LoadingIndicator`, `AgentInspector`
- Port dark theme styles (CSS modules or styled-components)
- Implement scroll-to-latest, loading states, and message rendering

**Tests**:
- Components render expected structure and dark theme classes
- Message list scrolls to bottom on new messages

---

### 1.4 - API Integration, Contracts, & State/Version Polling
**Intent**: Wire the React app to the Rails API with versioned state polling and contract-driven endpoints.

**Details**:
- API client: `sendMessage`, `getConversation` (GET messages), `getAgentState`, `getAgentVersion`
- Contracts: fetch `/dnd_chat/messages/contract`, `/dnd_chat/agent/contract`, `/dnd_chat/agent/version/contract` for schema-driven UI/validation
- State management via React Context or Zustand: chat messages, agent state, agent version, loading flags
- Poll `/dnd_chat/agent/version`; on change, fetch `/dnd_chat/agent`
- Handle errors gracefully and display error states

**Tests**:
- Sending a message updates UI with assistant reply and conversation state
- GET conversation returns thread matching contract (message objects with `source`, `target`, `message`, `context`)
- Version polling triggers state refresh when version changes
- Contract endpoints return valid OpenAPI documents consumed by the client

---

### 1.5 - Front-End Unit Tests (React)
**Intent**: Add fast, deterministic React unit tests with Vitest + React Testing Library.

**Details**:
- Test message submission, loading states, scroll behavior, and rendering
- Coverage targets (>80%)
- Use live Rails dev/test API (no mocks/stubs/fakes); configure test env to point at local API

**Tests**:
- Vitest suite passes headless against local API
- API calls validated against real endpoints (no mocking)
- DOM updates and accessibility assertions pass

---

### 1.6 - E2E Tests (Playwright)
**Intent**: Validate full-browser behavior against the real Rails API and LLM.

**Details**:
- Playwright tests for sending messages, seeing assistant replies, dark theme presence, and agent inspector updates
- Run headless; support Chrome/Firefox/WebKit

**Tests**:
- E2E suite passes with real LLM/tool execution
- Agent inspector reflects updates after chat interactions

---

### 1.7 - Documentation Update
**Intent**: Record the React-first UX artifacts and workflows.

**Details**:
- Ensure `file_references.md` lists React/Vite files and tests
- Note how to run Rails API + Vite dev server, and how to serve production build

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

**Tests**:
- Real LLM tool payload -> executes tool -> returns structured JSON
- Error path returns `success: false`

### 3.2 - Inspector Consistency
**Intent**: Agent view reflects the same sandbox state used by chat interactions.

**Details**:
- Agent endpoint reads from the same sandbox files
- No mutations in inspector

**Tests**:
- After a chat write, agent view shows updated memory/inventory and version bump

---

## Milestone 4 - E2E Test Suite
Validate the full DM/user chat flow end-to-end (tool details remain hidden from the user) with real LLM/tool execution and versioned serialized state.

### 4.1 - Chat Flow E2E
**Intent**: Exercise a user prompt through the live workflow, execute real LLM tool payloads, and render the assistant reply.

**Details**:
- Use real LLM responses with tool calls and run through controller POST
- Assert returned reply field is present, tools execute, and versioned state updates

**Tests**:
- POST `/dnd_chat/messages` with real LLM -> `success: true`, `reply` present, `tool` and `arguments` populated
- After POST, fetch `/dnd_chat/agent/version`; if the version changed, fetch `/dnd_chat/agent` and assert inventory/memory updates

### 4.2 - Agent View E2E
**Intent**: Ensure agent endpoint reflects state after chat mutations using real workflow execution.

**Details**:
- After a real chat write, GET agent endpoint shows the change and version increments

**Tests**:
- Agent endpoint returns updated inventory/memory and a higher version after prior POST

### 4.3 - Documentation Check
**Intent**: Keep references and runbook notes aligned with the shipped E2E suite.

**Details**:
- Ensure `file_references.md` lists created files and test files
- Note how to run the chat server (via Rails server) and the endpoints

**Tests**:
- Documentation review only

## Milestone 5 - LLM Manual Interaction via cURL
Provide steps and examples for interacting with the live endpoints manually using cURL to validate behavior with the real LLM and versioned serialized state.

### 5.1 - Manual cURL Flows
**Intent**: Enable manual verification of chat and inspector endpoints.

**Details**:
- Document cURL commands to send chat messages to `/dnd_chat/messages`
- Document polling `/dnd_chat/agent/version` and fetching `/dnd_chat/agent` when the version changes

**Tests**:
- Manual verification only; ensure commands are documented and usable

---

