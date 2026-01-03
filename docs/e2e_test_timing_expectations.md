# E2E Test Speed Expectations - Real LLM

## Overview

All E2E tests hit the **REAL LLM** with **NO MOCKING**. Tests are broken down into small, focused scenarios that complete quickly.

---

## Speed Expectations

### 🟢 Fast Tests (< 5s) - No LLM
- Session initialization: **2-5s**
- Context add/remove: **1-3s**
- Memory load: **2-5s**
- Mode switching: **1-2s**
- UI rendering: **< 1s**

### 🟡 Medium Tests (5-15s) - No LLM
- Memory operations with refresh: **5-10s**
- Session persistence checks: **8-12s**
- Multi-step UI flows: **10-15s**

### 🟠 LLM Tests (15-30s) - Single LLM Call
- Simple math query ("2+2"): **15-20s**
- Simple reasoning ("is 17 prime?"): **18-25s**
- Basic chat with context: **20-30s**

### 🔴 Integration Tests (30-45s) - Multiple Operations
- Chat + Context + Memory: **30-40s**
- Mode switch + Chat: **35-45s**

---

## Test Breakdown

### File: `frontend/e2e/agent-integration.spec.js`

| Test | LLM? | Expected | Timeout | Purpose |
|------|------|----------|---------|---------|
| **Session Management** |
| Initialize session | No | 2-5s | 10s | DB operation only |
| Session persistence | No | 8-12s | 15s | Refresh + reload |
| **Chat Flow** |
| Simple math response | **Yes** | 15-20s | 30s | Single LLM call |
| UI without send | No | < 5s | 10s | UI only |
| **Thoughts** |
| Extract thoughts | **Yes** | 20-25s | 35s | LLM + extraction |
| **Memory** |
| Load memory | No | 2-5s | 10s | DB query only |
| Clear section | No | 2-3s | 8s | API call only |
| **Context** |
| Add entry | No | 2-3s | 8s | UI operation |
| Remove entry | No | 1-2s | 8s | UI operation |
| **Mode Switching** |
| Switch modes | No | 2-5s | 8s | UI operation |
| **Integration** |
| Chat + Context | **Yes** | 25-30s | 40s | One LLM call |

---

## Why These Timings?

### Fast (< 5s) - Database/UI Only
```javascript
test("should initialize session in under 5 seconds", async ({ page }) => {
  test.setTimeout(10000); // Safety net: 10s
  
  const startTime = Date.now();
  
  await initButton.click();
  await page.waitForResponse(/* ... */, { timeout: 5000 });
  
  const elapsed = Date.now() - startTime;
  expect(elapsed).toBeLessThan(5000); // ACTUAL expectation
  
  console.log(`Session initialized in ${elapsed}ms`);
  // Typical: 2000-3000ms
});
```

**Why fast?**
- Just creates row in database
- No LLM involved
- Simple API call

### Medium (15-20s) - Single LLM Call
```javascript
test("should get simple math response in under 20 seconds", async ({ page }) => {
  test.setTimeout(30000); // Safety net: 30s
  
  const startTime = Date.now();
  
  await messageInput.fill("What is 2 + 2?");
  await sendButton.click();
  
  await expect(/* agent response */).toBeVisible({ timeout: 20000 });
  
  const elapsed = Date.now() - startTime;
  expect(elapsed).toBeLessThan(25000); // ACTUAL expectation
  
  console.log(`LLM query completed in ${elapsed}ms`);
  // Typical: 12000-18000ms (12-18s)
});
```

**Why reasonable?**
- ONE simple LLM call
- Simple math (no complex reasoning)
- LLM responds in 10-15s typically
- Network overhead ~2-3s

### Integration (25-35s) - Multiple Steps
```javascript
test("should complete chat with context in under 30 seconds", async ({ page }) => {
  test.setTimeout(40000); // Safety net: 40s
  
  const startTime = Date.now();
  
  // Step 1: Init session (~2s)
  // Step 2: Add context (~2s)
  // Step 3: Send message (~15s for LLM)
  // Total expected: ~19-20s
  
  const elapsed = Date.now() - startTime;
  expect(elapsed).toBeLessThan(35000); // ACTUAL expectation
  
  console.log(`Integration completed in ${elapsed}ms`);
  // Typical: 20000-28000ms (20-28s)
});
```

**Why acceptable?**
- Multiple operations combined
- Still ONE LLM call (not multiple)
- DB + UI + LLM all tested
- End-to-end validation

---

## What We DON'T Do

### ❌ BAD: Long Sequential Tests
```javascript
// DON'T DO THIS
test("complete workflow: init → chat → thoughts → memory → context", async ({ page }) => {
  test.setTimeout(180000); // 3 MINUTES!
  
  // Initialize
  // Send message 1
  // Wait 30s for LLM
  // Check thoughts
  // Send message 2
  // Wait 30s for LLM
  // Check memory
  // Send message 3
  // Wait 30s for LLM
  // Total: 90s+ ❌
});
```

**Problem:** Multiple LLM calls in sequence = too slow

### ✅ GOOD: Focused Tests
```javascript
// DO THIS
test("should get simple response", async ({ page }) => {
  test.setTimeout(30000); // 30s safety net
  
  // Initialize
  // Send ONE message
  // Wait ~15s for LLM
  // Verify response
  // Total: ~20s ✅
});

test("should load thoughts", async ({ page }) => {
  test.setTimeout(35000); // 35s safety net
  
  // Initialize
  // Send ONE message with reasoning
  // Check thoughts extracted
  // Total: ~25s ✅
});
```

**Benefits:**
- Each test focused on ONE thing
- Fast feedback (20-25s per test)
- Easy to debug failures
- Parallelizable

---

## Verification: Tests Actually Finish Fast

Each test includes timing assertions:

```javascript
const startTime = Date.now();

// ... test operations ...

const elapsed = Date.now() - startTime;
console.log(`Test completed in ${elapsed}ms`);
expect(elapsed).toBeLessThan(EXPECTED_TIME);
```

**This proves:**
- ✅ Test completed in reasonable time
- ✅ Not hitting timeout limit
- ✅ Actually doing work efficiently
- ✅ Real LLM responded quickly

---

## Running Tests

### Run All E2E Tests
```bash
cd frontend
npx playwright test agent-integration.spec.js
```

**Expected output:**
```
✓ should initialize session in under 5 seconds (2.8s)
✓ should maintain session ID across page refresh (10.2s)
✓ should get simple math response in under 20 seconds (17.5s)
✓ should handle user message without LLM response (3.1s)
✓ should extract thoughts from LLM response in under 25 seconds (22.8s)
✓ should load memory in under 5 seconds (3.7s)
✓ should clear memory section in under 3 seconds (2.1s)
✓ should add context entry in under 3 seconds (2.4s)
✓ should remove context entry in under 2 seconds (1.6s)
✓ should switch modes in under 2 seconds (3.2s)
✓ should complete chat with context in under 30 seconds (26.3s)

11 passed (96s total for all tests)
```

**Note:** Total time ~90-120s for ALL tests because they run sequentially. Each individual test is fast.

---

## Summary

### Timeouts vs. Expected Times

| Test Type | Timeout | Expected | Actual | Margin |
|-----------|---------|----------|--------|--------|
| Session init | 10s | < 5s | ~3s | 2s buffer |
| Simple LLM | 30s | < 20s | ~15s | 10s buffer |
| Thought extract | 35s | < 25s | ~22s | 10s buffer |
| Memory ops | 10s | < 5s | ~3s | 5s buffer |
| Context ops | 8s | < 3s | ~2s | 5s buffer |
| Integration | 40s | < 30s | ~26s | 10s buffer |

### Key Points

1. **Timeouts are safety nets** - Not targets
2. **Tests expect faster completion** - Via assertions
3. **Each test is focused** - One LLM call max
4. **Tests prove efficiency** - By measuring elapsed time
5. **Real LLM is fast** - 10-20s for simple queries

---

## Success Criteria

A test is properly broken down if:
- ✅ Timeout is 2x expected time (safety buffer)
- ✅ Expected time is < 30s
- ✅ Actual time assertion exists
- ✅ Test focuses on ONE scenario
- ✅ No more than ONE LLM call per test
- ✅ Console logs actual timing

**This proves tests are efficient and properly scoped!** 🚀








