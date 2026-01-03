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

