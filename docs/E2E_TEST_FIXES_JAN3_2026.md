# E2E Test Infrastructure Fixes - Jan 3, 2026

## Problem
E2E tests were timing out and failing because the UI wasn't updating after clicking the "Initialize Session" button. The aggressive timeout system correctly identified the issue and forced us to investigate.

## Root Causes Identified

### 1. **Stale Vite Dev Server** (CRITICAL)
- Vite process had been running for 3+ hours without restarting
- Code changes weren't being picked up by Hot Module Replacement (HMR)
- `pkill -f "vite.*5173"` wasn't killing the process properly
- **Fix**: Use `kill -9 $(lsof -ti:5173)` to forcefully kill the Vite process by port

### 2. **Wrong Playwright baseURL** (CRITICAL)
- Playwright was configured to use `http://localhost:3000` (Rails server)
- Rails server serves pre-built static assets, not the live Vite dev server
- **Fix**: Changed `playwright.config.js` to use `http://localhost:5173` (Vite dev server)

### 3. **Missing Vite API Proxy** (CRITICAL)
- Vite proxy was only configured for `/dnd_chat` and `/daedalus`
- API calls to `/api/*` weren't being proxied to the Rails backend
- **Fix**: Added `/api` proxy rule in `vite.config.js` pointing to `http://localhost:3000`

### 4. **Test Selector Too Broad**
- Test used `page.locator("text=/Session:.*/i")` which matched multiple elements
- **Fix**: Changed to `page.locator(".session-info")` for specific targeting

### 5. **Store Field Naming Inconsistency**
- Store defined `currentSessionId` but component was reading `sessionId`
- **Fix**: Updated component to use `state.currentSessionId`

### 6. **API Response Parsing Error**
- Store was trying to read `data.session.session_id`
- Backend actually returns `data.session_id` at top level
- **Fix**: Changed to `data.session_id`

## Files Modified

### Frontend Configuration
- **`frontend/playwright.config.js`**: Changed baseURL from port 3000 to 5173
- **`frontend/vite.config.js`**: Added `/api` proxy rule

### Frontend Components & Store
- **`frontend/src/components/AgentWorkspace.jsx`**: Fixed store selector to use `currentSessionId`
- **`frontend/src/store/agentStore.js`**: Fixed API response parsing and added error throwing

### E2E Tests
- **`frontend/e2e/agent-integration.spec.js`**: Changed BASE_URL to Vite (5173), fixed selector to `.session-info`
- **`frontend/e2e/helpers/speedProfile.js`**: Working correctly - aggressive timeouts forced investigation

## Test Results

### Before Fixes
```
❌ Test timed out at 15s (MEDIUM profile limit)
❌ UI not updating after button click
❌ Console logs not appearing
```

### After Fixes
```
✅ Test passed in 1.0 seconds
✅ UI updates correctly with session ID
✅ Speed profiler validated test completed well within limits (1s out of 15s)
```

## Lessons Learned

1. **Aggressive timeouts work!** - They forced us to find the real issues instead of just increasing limits
2. **Dev server state matters** - Long-running Vite processes can get stale
3. **Always verify the environment** - Check which server is actually serving the code
4. **Proxy configuration is critical** - Frontend dev servers need proper backend proxying
5. **Test with the live dev server** - Don't test against pre-built assets during development

## Testing Checklist for Future

- [ ] Verify Vite dev server is freshly restarted
- [ ] Confirm Playwright baseURL matches dev environment (5173 for dev, 3000 for CI)
- [ ] Check Vite proxy includes all necessary API routes
- [ ] Use specific selectors (classes/IDs) over broad text matchers
- [ ] Verify store field names match between definition and usage

## Commands for Fresh E2E Test Run

```bash
# Kill and restart Vite
kill -9 $(lsof -ti:5173) && cd frontend && npm run dev &

# Run E2E tests
cd frontend && npx playwright test
```

## Speed Profile Success

The aggressive timeout system worked exactly as intended:
- ✅ Caught the real issue (UI not updating)
- ✅ Prevented moving on to other tests
- ✅ Forced systematic debugging
- ✅ Test now completes in 1s (well under 15s MEDIUM limit)


