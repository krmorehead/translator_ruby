# DnD Chat Frontend

React + Vite SPA for the DnD chat experience.

## Scripts
- `npm run dev` — start Vite dev server
- `npm run build` — production build
- `npm run preview` — preview the build locally
- `npm run lint` — run ESLint
- `npm test` — run Vitest (configured in later milestones)

## Dev Notes
- API requests proxy to the Rails backend (port 3000) via Vite dev server.
- Requires Node 18+.
- Chat responses are narration-only; tool metadata stays on the server/inspector endpoints.

## cURL quickstart (Rails port 4000 in test/dev)
- Send a message:
  - `curl -X POST http://localhost:4000/dnd_chat/messages -H "Content-Type: application/json" -d '{"message":"Scout the tavern"}'`
- Check agent version:
  - `curl http://localhost:4000/dnd_chat/agent/version`
- Fetch agent state:
  - `curl http://localhost:4000/dnd_chat/agent`

