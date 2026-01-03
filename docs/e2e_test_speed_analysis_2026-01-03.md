# E2E Test Speed Analysis - January 3, 2026

## Test Execution Summary

Ran full E2E suite with 120-second (slow profile) timeout to identify tests exceeding threshold.

### Results Overview

**Total Tests**: 47 tests across multiple files
**Timeout**: 120 seconds per test (matches backend slow threshold)
**Execution Mode**: 4 parallel workers

### Tests Meeting Threshold (< 120s)

✅ **Sisyphus Page Tests** (21 tests): All passed in < 1 second each
- Average execution time: ~200ms
- All well within slow threshold

✅ **Chat Page Tests** (2 tests): Both passed in < 600ms
- test: "chat page loads and accepts input" - 535ms
- test: "agent version bumps after chat message" - 210ms

⚠️ **Approval Modal Tests** (14 tests): All complete quickly but failing due to backend API issue
- Average execution time: ~200ms
- **Issue**: Test injection endpoint returning empty JSON/404
- **Speed**: All tests meet threshold - failures are functional, not performance
- **Action Required**: Fix test endpoint, not test structure

### Tests EXCEEDING Threshold (>= 120s) ❌

**CRITICAL**: These tests hit or exceed the 120-second slow threshold:

1. **`e2e/checkpoint.spec.js` - Line 17**: "allows setting repository path"
   - **Time**: 2.0m (120 seconds - EXACTLY at threshold)
   - **Issue**: Waiting for backend operation that doesn't complete
   - **Action**: Break into smaller tests OR add proper response mocking

2. **`e2e/checkpoint.spec.js` - Line 27**: "shows create checkpoint dialog"
   - **Time**: 2.0m (120 seconds - EXACTLY at threshold)
   - **Issue**: Same as above - waiting for operation
   - **Action**: Break into smaller tests OR add proper response mocking

3. **`e2e/checkpoint.spec.js` - Line 8 & 12**: Two tests at 5+ seconds
   - **Times**: 5.3s and 5.1s
   - **Status**: Within threshold but unusually slow for UI tests
   - **Action**: Investigate slow selectors or API calls

## Detailed Analysis

### Checkpoint Tests - Critical Issues

The checkpoint tests are problematic for several reasons:

1. **Waiting for Real Backend Operations**:
   ```javascript
   test('allows setting repository path', async ({ page }) => {
     await pathInput.fill('/test/repo/path');
     await page.locator('button').filter({ hasText: 'Set Path' }).click();
     // Waits for backend to verify path - takes 120s!
     await expect(page.locator('.path-info')).toContainText('/test/repo/path');
   });
   ```

2. **No Timeout Guards**:
   - Tests rely on Playwright's default 120s timeout
   - Should fail faster if backend doesn't respond

3. **Interdependent Tests**:
   - Later tests depend on earlier state
   - Should be isolated

### Approval Modal Tests - Functional Issues

The approval tests are well-structured but have a backend integration issue:

```javascript
async injectApproval(approval) {
  const response = await this.page.request.post(
    "http://localhost:4000/api/sisyphus/test/inject_approval",
    // ... 
  );
  return await response.json(); // ← Failing: "Unexpected end of JSON input"
}
```

**Root Cause**: Test endpoint not properly configured or backend not in test mode.

## Recommendations

### IMMEDIATE (Must Fix for 120s Threshold)

#### 1. Break Up Checkpoint Tests

**Current** (120+ seconds):
```javascript
test('allows setting repository path', async ({ page }) => {
  await pathInput.fill('/test/repo/path');
  await page.locator('button').filter({ hasText: 'Set Path' }).click();
  await expect(page.locator('.path-info')).toContainText('/test/repo/path');
});
```

**Proposed** (< 10 seconds):
```javascript
test('can enter repository path', async ({ page }) => {
  // SCOPE: Just UI interaction
  const pathInput = page.locator('.path-input');
  await pathInput.fill('/test/repo/path');
  await expect(pathInput).toHaveValue('/test/repo/path');
});

test('set path button is enabled with valid path', async ({ page }) => {
  // SCOPE: Just button state
  await page.locator('.path-input').fill('/test/repo/path');
  const setButton = page.locator('button').filter({ hasText: 'Set Path' });
  await expect(setButton).toBeEnabled();
});

test('clicking set path triggers API call', async ({ page }) => {
  // SCOPE: Just API interaction (with proper timeout)
  await page.locator('.path-input').fill('/test/repo/path');
  
  // Listen for the API call
  const [request] = await Promise.all([
    page.waitForRequest(req => req.url().includes('/api/checkpoints/set_path'), {
      timeout: 5000 // 5 second max wait
    }),
    page.locator('button').filter({ hasText: 'Set Path' }).click()
  ]);
  
  expect(request.method()).toBe('POST');
});
```

#### 2. Add Explicit Timeouts

All E2E assertions should have explicit short timeouts:

```javascript
await expect(element).toBeVisible({ timeout: 5000 }); // 5s max
await page.waitForResponse(url, { timeout: 10000 }); // 10s max
```

#### 3. Use Real API with Fixtures

Following OOP principles (NO MOCKS), use real backend with test fixtures:

```javascript
class CheckpointTestService {
  async setupTestRepository(page) {
    // Call REAL backend API to create test repository
    const response = await page.request.post(
      'http://localhost:4000/api/test/setup_repository',
      {
        data: { path: '/tmp/test-repo-' + Date.now() }
      }
    );
    
    // Return REAL CheckpointManager instance data
    const data = await response.json();
    return CheckpointManager.fromJSON(data.repository);
  }
}
```

### SHORT TERM (Performance Optimization)

1. **Reduce Wait Times**: Change all `page.waitForTimeout(1000)` to specific element waits
2. **Parallel Test Isolation**: Ensure tests don't interfere (unique repo paths per test)
3. **Fast Failure**: Add explicit timeouts so tests fail at 10s, not 120s

### Speed Profile Compliance

**Target Times**:
- UI-only tests: < 5 seconds
- Single API call tests: < 10 seconds
- Complex flow tests: < 30 seconds
- **HARD LIMIT**: 120 seconds (slow threshold)

**Current Status**:
- ✅ Sisyphus tests: ~200ms avg
- ✅ Chat tests: ~400ms avg
- ⚠️ Approval tests: ~200ms avg (functional issues, not speed)
- ❌ Checkpoint tests: 120+ seconds (EXCEEDS THRESHOLD)

## Action Plan

### Phase 1: Fix Threshold Violations (Priority 1)

1. ✅ Identify tests exceeding 120s threshold
2. ⏳ Break up checkpoint tests into smaller, scoped tests
3. ⏳ Add explicit timeouts (5-10s max per operation)
4. ⏳ Use real backend with proper test fixtures (no mocks)

### Phase 2: Fix Functional Issues (Priority 2)

1. ⏳ Debug approval modal test endpoint
2. ⏳ Ensure test mode endpoints are available
3. ⏳ Verify backend test server configuration

### Phase 3: Optimize Performance (Priority 3)

1. ⏳ Replace `waitForTimeout` with specific element waits
2. ⏳ Add proper error messages for timeout failures
3. ⏳ Document E2E test patterns

## Compliance with Requirements

✅ **120-second slow threshold**: Identified violations
✅ **No mocks**: Recommendation uses real backend
✅ **OOP principles**: Service classes for test helpers
✅ **Fail fast**: Explicit timeouts proposed
❌ **All tests passing**: Checkpoint tests exceed threshold
❌ **Backend integration**: Test endpoints need fixing

## Next Steps

1. Break up the two 120+ second checkpoint tests
2. Add explicit 5-10 second timeouts throughout
3. Fix approval modal backend endpoint
4. Re-run with `timeout 300 npm run e2e`
5. Verify all tests complete within 120s

