# E2E Test Documentation - Real LLM Integration

## Overview

All E2E tests in this project follow a **STRICT NO MOCKING** policy. Every test that involves the agent **MUST** hit the real LLM backend.

---

## Test Files

### 1. `frontend/e2e/agent-integration.spec.js` (NEW)
**Purpose:** Comprehensive end-to-end testing of the entire agent flow

**What It Tests:**
- ✅ Real LLM chat interactions
- ✅ Thought stream extraction from LLM responses
- ✅ Memory persistence across interactions
- ✅ Context management throughout session
- ✅ Mode switching with state persistence

**Key Features:**
- **NO MOCKS**: Every test makes real API calls to backend
- **Real LLM**: All agent responses come from actual LLM
- **Proper Timeouts**: 60-180s to account for LLM response time
- **Speed Profiled**: Tests marked as SLOW (real LLM calls)

**Test Scenarios:**
1. **Agent Chat Flow**
   - Initialize session with real backend
   - Send message requiring reasoning (e.g., "What is 2 + 2?")
   - Wait for REAL LLM response (10-60s)
   - Verify message structure
   - Check for agent reasoning in thoughts

2. **Thought Display**
   - Send complex query to LLM
   - Extract `<think>` tags from real response
   - Display in ThoughtsPanel
   - Verify reasoning content matches LLM output

3. **Memory Inspection**
   - Trigger agent actions that populate memory
   - Query real memory state from backend
   - Display in MemoryInspector
   - Test clear functionality with real API

4. **Context Management**
   - Add context entries (files/functions)
   - Pass to LLM in subsequent queries
   - Verify LLM uses context in responses
   - Remove context and verify behavior changes

5. **Mode Switching**
   - Switch between Daedalus/Sisyphus
   - Verify session persists (real session ID)
   - Check context survives mode switch
   - Validate state consistency

6. **Full Integration**
   - Complete workflow: Init → Chat → Thoughts → Memory → Context
   - All steps use real LLM
   - 180s timeout for full flow
   - Validates entire system integration

### 2. `frontend/e2e/sisyphus-approval.spec.js` (EXISTING)
**Purpose:** Real execution workflow with approvals

**What It Tests:**
- ✅ Real plan execution
- ✅ Approval request handling
- ✅ Step-by-step execution with LLM
- ✅ File modifications by real agent

**Key Features:**
- Real Sisyphus worker execution
- Real file system operations
- Real approval workflow
- No test endpoints - production code only

### 3. `frontend/e2e/daedalus-api.spec.js` (EXISTING - Updated)
**Purpose:** Real plan generation

**What It Tests:**
- ✅ Real Daedalus plan generation
- ✅ LLM-generated execution plans
- ✅ Codebase analysis

---

## Speed Profiling

### Fast Tests (< 5s)
- Model creation/validation
- Factory pattern tests
- UI rendering (no LLM)
- State management

### Medium Tests (5-30s)
- API endpoint tests
- Database operations
- File system operations

### Slow Tests (30-180s) **← REAL LLM TESTS**
- **Agent chat with LLM response**: 30-60s
- **Complex reasoning queries**: 45-90s
- **Full integration flow**: 120-180s
- **Plan generation**: 30-120s
- **Execution workflow**: 60-180s

---

## Running Tests

### Run All Tests (Including Real LLM)
```bash
cd frontend
npm run test:e2e
```

### Run Only Fast Tests (No LLM)
```bash
npm run test:e2e:fast
```

### Run Only LLM Integration Tests
```bash
npx playwright test agent-integration.spec.js
```

### Run Specific Test
```bash
npx playwright test agent-integration.spec.js -g "should initialize session"
```

---

## Test Requirements

### Backend Must Be Running
```bash
# Terminal 1: Start Rails backend
cd /path/to/translator_ruby
rails server
```

### Frontend Must Be Running
```bash
# Terminal 2: Start React frontend
cd frontend
npm start
```

### LLM Server Must Be Accessible
- Backend must be configured with real LLM endpoints
- Check `.env` for:
  ```
  GENERAL_LLM_PORT=52003
  GENERAL_LLM_URL=http://localhost
  TOOL_CALLING_PORT=52004
  ```
- LLM servers must be running and responding

---

## Verification Checklist

### ✅ No Mocking
- [ ] All tests use real API calls
- [ ] No fake/stub LLM responses
- [ ] No mock objects for domain models
- [ ] Real database operations
- [ ] Real file system access

### ✅ Real LLM Integration
- [ ] Tests wait for actual LLM responses
- [ ] Responses contain genuine LLM reasoning
- [ ] `<think>` tags extracted from real output
- [ ] Agent behavior matches LLM capabilities
- [ ] Timeouts account for LLM latency (30-180s)

### ✅ Real Domain Objects
- [ ] All models use actual class instances
- [ ] ApprovalRequest uses real factory
- [ ] Message/Thought/Memory use domain models
- [ ] Context uses real ContextEntry instances
- [ ] No plain JS objects as substitutes

### ✅ Real API Endpoints
- [ ] `/api/agent_sessions` - Real session creation
- [ ] `/api/agent_sessions/:id/messages` - Real message storage
- [ ] `/api/agent_sessions/:id/thoughts` - Real thought extraction
- [ ] `/api/agent_sessions/:id/memories` - Real memory state
- [ ] `/api/agent_sessions/:id/actions` - Real action log

---

## Test Assertions

### What We Verify

1. **LLM Response Quality**
   - Response contains meaningful content
   - Math problems answered correctly
   - Reasoning is logical and coherent
   - Context is used in responses

2. **Thought Extraction**
   - `<think>` tags properly extracted
   - Reasoning separate from final answer
   - Timestamps accurate
   - Thought content non-empty

3. **Memory Persistence**
   - Memory sections populated correctly
   - Content survives page refresh
   - Clear operation works
   - Section structure valid

4. **Context Usage**
   - Added context appears in subsequent queries
   - LLM references provided context
   - Removed context no longer influences responses
   - Context persists across mode switches

5. **Session Management**
   - Sessions maintain state
   - Session IDs valid UUIDs
   - Multiple sessions independent
   - Session data retrievable

---

## Common Issues & Solutions

### Test Timeout
**Problem:** Test fails with timeout error  
**Cause:** LLM taking longer than expected  
**Solution:** Increase timeout in test (already set to 120-180s)

### LLM Not Responding
**Problem:** Test hangs waiting for LLM  
**Cause:** LLM server not running or misconfigured  
**Solution:** Check LLM server status and `.env` configuration

### Empty Thoughts
**Problem:** No thoughts extracted from response  
**Cause:** LLM didn't use `<think>` tags  
**Solution:** Normal - some responses don't need reasoning. Test handles gracefully.

### Session Not Found
**Problem:** Session ID not persisting  
**Cause:** Backend not storing sessions properly  
**Solution:** Check Rails logs and database

---

## Performance Benchmarks

### Expected Test Times (Real LLM)

| Test | Expected Duration | What It Does |
|------|------------------|--------------|
| Initialize Session | 2-5s | Creates real session in backend |
| Simple Chat (2+2) | 10-30s | LLM processes and responds |
| Complex Reasoning | 30-60s | LLM does deep thinking |
| Full Integration | 120-180s | Complete workflow with multiple LLM calls |
| Memory Inspection | 5-10s | Queries backend state (no LLM) |
| Context Management | 2-5s | Updates frontend state (no LLM) |

### Total Suite Runtime
- **Fast tests only**: ~1-2 seconds
- **With medium tests**: ~30 seconds
- **Full suite with LLM**: **5-10 minutes** (real integration!)

---

## Continuous Integration

### CI Configuration
For CI/CD pipelines:

```yaml
# .github/workflows/e2e-tests.yml
- name: Run Fast Tests
  run: npm run test:e2e:fast
  
- name: Run LLM Integration Tests (nightly only)
  if: github.event.schedule == '0 0 * * *'
  run: npm run test:e2e
  timeout-minutes: 15
```

**Rationale:**
- Fast tests run on every commit (< 5s)
- LLM integration tests run nightly (5-10 min)
- Prevents PR delays while ensuring quality

---

## Success Criteria

A test MUST:
1. ✅ Use real API endpoints (no stubs)
2. ✅ Use real domain model instances (no mocks)
3. ✅ Wait for real LLM responses (no fake data)
4. ✅ Have proper timeouts (30-180s for LLM)
5. ✅ Verify actual behavior (not stubbed responses)
6. ✅ Be speed profiled (SLOW for LLM tests)

---

## Example: Anatomy of a Real LLM Test

```javascript
test("should get real LLM response", async ({ page }) => {
  test.setTimeout(120000); // ✅ 120s timeout for LLM
  
  await page.goto("http://localhost:3000/agent");
  
  // ✅ Real session initialization
  await page.getByRole("button", { name: /initialize/i }).click();
  await page.waitForResponse(
    response => response.url().includes("/api/agent_sessions")
  );
  
  // ✅ Send real message to LLM
  await page.getByLabel("Message input").fill("What is 2 + 2?");
  await page.getByRole("button", { name: /send/i }).click();
  
  // ✅ Wait for REAL LLM response (not mocked)
  await expect(
    page.locator(".chat-message").filter({ hasText: /4|four/i })
  ).toBeVisible({ timeout: 60000 }); // 60s for LLM
  
  // ✅ Verify real LLM behavior
  const agentMessage = page.locator(".chat-message").last();
  await expect(agentMessage).toContainText("Agent");
  
  // Response should be meaningful (real LLM)
  const content = await agentMessage.textContent();
  expect(content.length).toBeGreaterThan(10);
});
```

---

## Summary

**This test suite provides TRUE end-to-end testing:**
- ✅ Real LLM integration (no mocks)
- ✅ Real domain models (no plain objects)
- ✅ Real API calls (no stubs)
- ✅ Real timeouts (accounts for LLM latency)
- ✅ Real assertions (verifies actual behavior)

**Total confidence that the system works in production!** 🚀








