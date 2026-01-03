# E2E Test Philosophy: No Explicit Timeouts

## Core Principle
**Tests should respond naturally to the environment, not arbitrary time limits.**

## What We Removed
- ❌ `{ timeout: 3000 }` on expect calls
- ❌ `{ timeout: 5000 }` on waitForResponse
- ❌ `page.waitForTimeout(500)` arbitrary waits
- ❌ All hardcoded millisecond values

## What We Use Instead
✅ **Playwright's built-in waiting mechanisms:**
- `await expect(element).toBeVisible()` - waits until visible
- `await page.waitForLoadState("networkidle")` - waits for network activity to settle
- `await page.waitForResponse(condition)` - waits for specific API call
- `await page.waitForSelector(selector)` - waits for element to exist

✅ **Speed Profiler enforces overall limits:**
- `fast()` - 5 seconds MAX for entire test
- `medium()` - 15 seconds MAX for entire test
- `slow()` - 30 seconds MAX for entire test (real LLM)

## Why This Matters

### Before (Bad):
```javascript
await expect(button).toBeVisible({ timeout: 3000 });
await page.waitForTimeout(500); // arbitrary
await expect(response).toBeVisible({ timeout: 10000 });
```
**Problems:**
- Timeouts hide real issues (UI not rendering fast enough)
- Tests become flaky (sometimes 500ms isn't enough, sometimes it's too much)
- Harder to debug (which timeout is the problem?)
- Artificial speed expectations

### After (Good):
```javascript
await expect(button).toBeVisible();
await page.waitForLoadState("networkidle");
await expect(response).toBeVisible();
```
**Benefits:**
- Tests wait as long as needed (up to Playwright default ~30s)
- Speed profiler catches if ENTIRE test is too slow
- Tests respond to actual environment speed
- Failures point to real problems, not arbitrary timeouts

## Speed Profiler is the Safety Net

If a test takes too long, the speed profiler will:
1. ✅ Stop the test with a clear error
2. ✅ Show exactly which profile was violated
3. ✅ Force you to fix the real problem (not just increase timeout)
4. ✅ Ensure tests are broken down appropriately

## Example: Session Initialization Test

```javascript
medium("should initialize agent session via API", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await expect(initButton).toBeVisible(); // NO TIMEOUT!
  await initButton.click();

  const response = await page.waitForResponse(
    (r) => r.url().includes("/api/agent_sessions") && r.request().method() === "POST"
  ); // NO TIMEOUT!

  expect(response.ok()).toBe(true);
  await expect(page.locator(".session-info")).toBeVisible(); // NO TIMEOUT!
});
```

This test:
- ✅ Completes in ~1 second (well under 15s MEDIUM limit)
- ✅ Waits naturally for each element/response
- ✅ Will be caught by speed profiler if environment is slow
- ✅ Failures indicate real problems (API down, UI broken, etc.)

## When Speed Profiler Triggers

If this test started taking 16+ seconds:
```
❌❌❌ E2E TEST TIMEOUT - STOP AND FIX THIS NOW ❌❌❌

Test: "should initialize agent session via API"
Profile: medium
Limit: 15000ms (15s)
Actual: 16234ms (16.23s)

🛑 THIS TEST TIMED OUT - SOMETHING IS BROKEN
```

This forces you to:
1. Check if backend is running
2. Check if API is hanging
3. Check if UI rendering is broken
4. Break test into smaller pieces if doing too much

**You cannot just increase the timeout and move on.**

## Summary

- ✅ No `timeout:` parameters in test code
- ✅ Use Playwright's natural waiting mechanisms
- ✅ Speed profiler enforces overall test duration
- ✅ Tests respond to actual environment performance
- ✅ Failures indicate real problems, not timing issues


