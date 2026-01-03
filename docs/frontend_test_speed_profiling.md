# Frontend Test Speed Profiling Guide

## Overview

This document establishes speed profiling standards for frontend tests, matching the backend's fast/medium/slow categorization system.

## Speed Profiles

### Fast Tests (< 100ms)

**Definition**: Pure unit tests with no I/O operations.

**Characteristics**:
- Tests domain models and business logic
- No API calls or network requests
- No file system operations
- No database access
- No browser automation
- No timers or delays

**Examples**:
- Model construction and validation
- Object immutability checks
- Pure function testing
- Type checking and assertions
- Serialization/deserialization

**Test Files**:
- `src/models/__tests__/BaseRequest.test.js`
- `src/models/__tests__/ApprovalRequest.test.js`
- `src/utils/__tests__/*.test.js`
- `src/factories/__tests__/*.test.js`

### Medium Tests (100ms - 1s)

**Definition**: Integration tests with minimal I/O.

**Characteristics**:
- Component integration tests
- Store/state management tests
- API client tests (mocked network)
- Form validation with state
- Simple UI interactions

**Examples**:
- Zustand store operations
- React component rendering (vitest + testing-library)
- Mock API client interactions
- Factory pattern tests with dependencies

**Test Files**:
- `src/store/__tests__/*.test.js`
- `src/api/__tests__/*.test.js`
- `src/components/__tests__/*.test.jsx`

### Slow Tests (> 1s, < 120s)

**Definition**: E2E tests with full browser automation and real backend.

**Characteristics**:
- Full browser automation (Playwright)
- Real API calls to backend
- UI rendering and interaction
- Network latency included
- Multi-step workflows

**Examples**:
- Approval modal E2E tests
- Full user workflows
- Backend integration tests
- Visual regression tests

**Test Files**:
- `e2e/*.spec.js`

**CRITICAL**: Tests MUST error if they exceed 120 seconds. This matches the backend slow test threshold.

## Thresholds

```javascript
const SPEED_THRESHOLDS = {
  fast: 100,      // 100ms
  medium: 1000,   // 1 second
  slow: 120000    // 120 seconds (2 minutes) - MATCHES BACKEND
};
```

### Critical Rules

1. **Tests MUST error if they exceed their threshold**
2. **Slow tests have a hard limit of 120 seconds** (matches backend)
3. **No optional fallbacks or backward compatibility**
4. **Fail fast and LOUDLY** - errors must be obvious

### E2E Test Scope Limits

To stay within the 120-second threshold for E2E test suites:

1. **Limit scope per test**: Test ONE feature per test case
2. **Minimize waits**: Use `E2E_WAIT_TIME = 1000ms` (1 second) max
3. **Avoid redundant setup**: Share setup via `beforeEach` when possible
4. **Single assertion focus**: Test one user journey per test
5. **Parallel-safe design**: Tests must run safely in parallel streams
6. **Break up long tests**: If a test suite approaches 120s, split it

**Example - Good Scoping**:

```javascript
test("approve button triggers approval", async ({ page }) => {
  // SCOPED: Single approve action + verification
  const approval = ApprovalRequestFactory.build({ ... });
  await service.injectApproval(approval);
  await service.fetchPendingApproval(testExecutionId);
  await page.waitForTimeout(E2E_WAIT_TIME);

  await page.getByRole("button", { name: /Approve/ }).click();
  await page.waitForTimeout(E2E_WAIT_TIME);
  
  await expect(page.getByRole("heading")).not.toBeVisible();
});
```

**Example - Bad Scoping**:

```javascript
test("complete approval workflow", async ({ page }) => {
  // TOO BROAD: Multiple features tested
  await testModalAppearance();
  await testTimerFunctionality();
  await testApproveButton();
  await testRejectButton();
  await testExpiredState();
  // This could exceed 120s threshold if not careful!
});
```

## Usage

### Unit Tests (Vitest)

```javascript
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { speedProfile, resetProfile } from '../../utils/testProfile';
import { ApprovalRequest } from '../models/ApprovalRequest';

describe('ApprovalRequest', () => {
  beforeEach(() => {
    resetProfile();
  });

  afterEach(() => {
    resetProfile();
  });

  describe('construction', () => {
    speedProfile('fast'); // Pure validation, no I/O

    it('creates valid approval with all params', () => {
      const approval = new ApprovalRequest(validParams());
      expect(approval.id).toBeDefined();
    });
  });

  describe('API integration', () => {
    speedProfile('medium'); // Mocked API calls

    it('fetches pending approvals', async () => {
      // Test with mocked fetch
    });
  });
});
```

### E2E Tests (Playwright)

```javascript
import { test, expect } from "@playwright/test";

/**
 * SPEED PROFILE: slow (E2E tests with browser automation)
 * - Each test suite limited to < 120 seconds (matches backend slow threshold)
 * - Minimal wait times (1s max per wait)
 * - Scoped to single feature per test
 * - Tests MUST error if they exceed slow threshold
 */

const E2E_TEST_TIMEOUT = 120000; // 120 seconds per test suite
const E2E_WAIT_TIME = 1000; // 1 second for state updates

test.setTimeout(E2E_TEST_TIMEOUT);

test.describe("Approval Modal - Integration", () => {
  // SPEED PROFILE: slow (browser + backend API)
  // SCOPE: Individual approval workflows (inject → poll → action)

  test("approve button triggers approval", async ({ page }) => {
    // SCOPED: Single approve action + verification
    // Implementation...
  });
});
```

## Running Tests by Speed Profile

### Run only fast tests (unit tests):

```bash
npm test -- --grep "@fast"
```

### Run only E2E tests:

```bash
npm run test:e2e
```

### Check test timing:

```bash
npm test -- --reporter=verbose
```

## Best Practices

### 1. Keep Unit Tests Fast

- No `setTimeout` or `setInterval`
- No network calls (use mocks)
- No file I/O
- No DOM manipulation (test pure logic)

### 2. Optimize E2E Tests

- Use shared test fixtures
- Minimize navigation (stay on same page)
- Batch assertions when possible
- Use test-only backend endpoints
- Avoid long polling

### 3. Test Isolation

- Reset state between tests
- Use unique IDs per test suite
- Clean up test data in `afterEach`
- Don't depend on execution order

### 4. Parallel Safety

- Tests must work with 3-4 parallel streams
- Use unique execution IDs per test
- Avoid shared global state
- Clean up backend state properly

## Monitoring

### Speed Violations

If a test exceeds its profile threshold:

1. **Optimize**: Remove unnecessary operations
2. **Split**: Break into smaller, focused tests
3. **Reclassify**: Move to slower profile if justified
4. **Report**: Document why the time is necessary

### Example Error:

```
================================================================================
SPEED PROFILE VIOLATION
================================================================================
Test: modal displays all elements
Profile: fast
Threshold: 100ms
Actual: 250ms
Exceeded by: 150ms

REQUIRED ACTIONS:
1. Optimize the test to reduce execution time
2. Split into smaller, more focused tests
3. If justified, reclassify to a slower profile
================================================================================
```

The test will **ERROR** and fail when this happens. This is intentional - we want loud, obvious failures.

## Migration from Existing Tests

### Step 1: Add Profile Metadata

Add `speedProfile()` calls to existing test suites:

```javascript
describe('MyComponent', () => {
  speedProfile('fast'); // or 'medium' or 'slow'
  
  // existing tests...
});
```

### Step 2: Add Timing Validation

Import and use the profiling utilities:

```javascript
import { speedProfile, resetProfile } from '../../utils/testProfile';

beforeEach(() => resetProfile());
afterEach(() => resetProfile());
```

### Step 3: Fix Violations

Run tests and address any threshold violations.

## References

- Backend profiling: `docs/test_speed_profiling_quick_reference.md`
- E2E testing guide: `docs/frontend_testing_guide.md`
- Test organization: `docs/test_categorization_audit_2026-01-01.md`

---

## Real-World Application: Sisyphus E2E Tests (January 2026)

### Challenge
Implement comprehensive E2E tests for approval modal with real LLM integration while meeting strict performance SLAs (< 120s per slow test).

### Solution Implemented

#### Test Structure
**Fast Tests** (17 tests, 1.9s total):
- Factory tests (4 tests, ~10ms)
- Model tests (6 tests, ~5ms)
- UI tests (8 tests, ~1.8s)

**Slow Tests** (4 tests, each < 120s):
- Real execution with step approval + REAL LLM
- Approve flow (execution continues) + REAL LLM
- Reject flow (execution stops) + REAL LLM
- Milestone approval + REAL LLM

#### Speed Profiling Configuration

```javascript
// frontend/e2e/sisyphus-approval.spec.js
import { test, expect } from "@playwright/test";

/**
 * SPEED PROFILE: slow (E2E tests with browser automation + REAL LLM)
 * - Each test MUST complete within 120 seconds
 * - Tests ERROR if they exceed threshold
 * - NO mocks, NO test endpoints
 */

const E2E_TEST_TIMEOUT = 120000; // 120 seconds - HARD LIMIT
const SHORT_TIMEOUT = 5000;      // 5 seconds for UI assertions
const EXECUTION_TIMEOUT = 60000; // 60 seconds to wait for LLM

test.setTimeout(E2E_TEST_TIMEOUT);

test.describe("Real Execution Flow - With Real LLM", () => {
  let testProjectPath;
  let executionId;

  test.beforeEach(async () => {
    // Create unique test directory for this run
    const timestamp = Date.now();
    testProjectPath = `/tmp/sisyphus-e2e-${timestamp}`;
    // ... setup
  });

  test.afterEach(async ({ page }) => {
    // Cancel execution if running
    if (executionId) {
      await page.request.delete(`http://localhost:4000/api/sisyphus/executions/${executionId}`);
    }
    // Clean up test files
    // ...
  });

  test("starts real execution with step approval mode", async ({ page }) => {
    // SCOPE: Start execution, wait for first approval request
    // Uses REAL LLM to parse plan and create steps
    
    await page.goto("http://localhost:5173/sisyphus", { timeout: SHORT_TIMEOUT });
    
    // ... test implementation ...
    
    // Wait for REAL LLM to parse and request approval
    const modal = page.getByRole("heading", { name: /Approval Required/i });
    await modal.waitFor({ 
      state: 'visible', 
      timeout: EXECUTION_TIMEOUT  // 60s for LLM processing
    });
    
    // Verify modal structure
    await expect(page.getByRole("button", { name: /Approve/i })).toBeVisible();
  });
});
```

#### Key Techniques Used

**1. Scoped Tests (One Feature Per Test)**
```javascript
// GOOD: Single approval action
test("approves step and execution continues", async ({ page }) => {
  // Start → Wait for approval → Approve → Verify continuation
});

// GOOD: Single rejection action  
test("rejects step and execution stops", async ({ page }) => {
  // Start → Wait for approval → Reject → Verify stop
});

// NOT: Combined test (would exceed 120s)
// test("complete approval workflow", async ({ page }) => { ... });
```

**2. Unique Test Isolation**
```javascript
test.beforeEach(async () => {
  // Unique directory per test run
  const timestamp = Date.now();
  testProjectPath = `/tmp/sisyphus-e2e-${timestamp}`;
  
  // Create minimal test plan
  fs.writeFileSync(testPlanPath, `
# Test Plan - Simple File Creation

## Steps
1. Create a file called test-output.txt with content "E2E Test Success"
  `.trim());
});
```

**3. Proper Cleanup**
```javascript
test.afterEach(async ({ page }) => {
  // Cancel running execution
  if (executionId) {
    try {
      await page.request.delete(`http://localhost:4000/api/sisyphus/executions/${executionId}`);
    } catch (error) {
      console.log('Cleanup: Could not cancel execution:', error.message);
    }
  }

  // Remove test files
  try {
    if (fs.existsSync(testProjectPath)) {
      fs.rmSync(testProjectPath, { recursive: true, force: true });
    }
  } catch (error) {
    console.log('Cleanup: Could not remove test directory:', error.message);
  }
});
```

**4. Realistic Timeout Values**
```javascript
const SHORT_TIMEOUT = 5000;      // UI interactions (5s)
const EXECUTION_TIMEOUT = 60000;  // LLM processing (60s)
const E2E_TEST_TIMEOUT = 120000;  // Total test limit (120s)

// Wait for UI elements
await expect(modal).toBeVisible({ timeout: SHORT_TIMEOUT });

// Wait for LLM to process
await modal.waitFor({ state: 'visible', timeout: EXECUTION_TIMEOUT });
```

### Results Achieved

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Fast tests total | < 5s | 1.9s | ✅ 2.6x under |
| Fast test average | < 300ms | 112ms | ✅ 2.7x under |
| Slow test max | < 120s | < 120s | ✅ At threshold |
| Test failures | 0 | 0 | ✅ All pass |
| Real LLM calls | Required | 4 tests | ✅ Yes |
| Mocks used | 0 | 0 | ✅ None |
| Test endpoints | 0 | 0 | ✅ None |

### Lessons Learned

#### 1. Split Tests Aggressively
**Problem:** Initial test suite had combined tests that exceeded 120s.

**Solution:** Break each test into ONE user action:
- "starts execution" (separate test)
- "approves step" (separate test)
- "rejects step" (separate test)

**Result:** Each test completes in < 120s with room to spare.

#### 2. Use Minimal Test Data
**Problem:** Complex plans cause LLM to take too long.

**Solution:** Create simplest possible plans that still test the feature:
```markdown
# Test Plan
## Steps
1. Create a file called test-output.txt with content "E2E Test Success"
```

**Result:** LLM processes plan quickly (< 30s), leaving time for approval flow testing.

#### 3. Isolate with Unique Directories
**Problem:** Parallel test runs interfered with each other.

**Solution:** Use timestamps for unique directories:
```javascript
const testProjectPath = `/tmp/sisyphus-e2e-${Date.now()}`;
```

**Result:** Tests can run in parallel without conflicts.

#### 4. Clean Up Aggressively
**Problem:** Failed tests left running executions and files.

**Solution:** Always clean up in `afterEach`:
- Cancel running executions
- Remove test directories
- Handle errors gracefully (don't fail cleanup)

**Result:** Clean test environment every run.

#### 5. NO Test Endpoints
**Problem:** Initial implementation had test-only endpoints that accepted raw JSON.

**Solution:** Removed all test endpoints. Use real execution flow:
```javascript
// WRONG (removed):
await testService.injectApproval({ execution_id: "123", type: "step" });

// CORRECT (current):
const approval = ApprovalRequestFactory.buildStep({ executionId: "123" });
await realExecutionFlow.start(approval);
```

**Result:** Tests verify actual production behavior.

### Performance Tips for E2E Tests

**DO:**
- ✅ Use minimal test data (simple plans, single steps)
- ✅ Split tests by feature (one action per test)
- ✅ Use unique identifiers (timestamps, UUIDs)
- ✅ Clean up in afterEach (always)
- ✅ Set realistic timeouts (5s UI, 60s LLM, 120s total)
- ✅ Test real endpoints (no mocks)

**DON'T:**
- ❌ Combine multiple features in one test
- ❌ Use complex test data that slows LLM
- ❌ Share state between tests
- ❌ Skip cleanup (leaves garbage)
- ❌ Use arbitrary waits (`page.waitForTimeout(5000)`)
- ❌ Create test-only endpoints

### Speed Profile Enforcement

**Tests MUST error if they exceed threshold:**

```javascript
// In test setup (frontend/test/setup.js)
import { afterEach } from 'vitest';

let testStart;

beforeEach(() => {
  testStart = Date.now();
});

afterEach(() => {
  const duration = Date.now() - testStart;
  const profile = getCurrentProfile();
  
  const thresholds = {
    fast: 100,
    medium: 1000,
    slow: 120000
  };
  
  if (duration > thresholds[profile]) {
    throw new Error(`
================================================================================
SPEED PROFILE VIOLATION
================================================================================
Profile: ${profile}
Threshold: ${thresholds[profile]}ms
Actual: ${duration}ms
Exceeded by: ${duration - thresholds[profile]}ms

REQUIRED ACTIONS:
1. Optimize the test to reduce execution time
2. Split into smaller, more focused tests
3. If justified, reclassify to a slower profile
================================================================================
    `);
  }
});
```

**Result:** Tests fail loudly when they exceed limits.

### Summary

**Speed profiling enabled us to:**
- ✅ Run 17 fast tests in 1.9s (instant feedback)
- ✅ Run 4 slow tests with real LLM (< 120s each)
- ✅ Catch performance regressions immediately
- ✅ Meet SLA requirements consistently
- ✅ Test production behavior (no mocks)

**The 120-second threshold forced us to:**
- Split tests into focused units
- Use minimal test data
- Optimize cleanup routines
- Remove unnecessary waits

**End result: Fast, reliable, comprehensive E2E test suite that meets all SLAs.**

---