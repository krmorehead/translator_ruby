# Testing Guide

This project uses a consistent testing approach across both backend and frontend with speed profile filtering.

## Test Speed Profiles

Tests are categorized by speed to enable efficient test runs:

- **Fast** (`<10s`): Unit tests, model tests, quick integrations
- **Medium** (`<60s`): Controller tests, workflows without LLM calls
- **Slow** (`<120s`): Full integrations with LLM calls, E2E tests

## Backend Testing (Rails)

### Commands

```bash
# Run all tests
bin/test

# Run fast tests only
bin/test fast

# Run medium tests only
bin/test medium

# Run slow tests only
bin/test slow

# Run full suite (fast → medium → slow)
bin/test all
```

### Implementation

- Test speed profiles are defined in `test/support/speed_profile.rb`
- Tests are tagged with `:fast`, `:medium`, or `:slow`
- Timeouts are automatically enforced
- Research worker tests are excluded by default

### Example Test

```ruby
class MyTest < ActiveSupport::TestCase
  speed_profile :fast
  
  test "something quick" do
    # Test that completes in < 10s
  end
end
```

## Frontend Testing (React/Vitest)

### Unit/Integration Tests

```bash
# Run all tests (exits after completion)
npm test

# Run tests in watch mode (for development)
npm run test:watch

# Run fast tests only
npm run test:fast

# Run medium tests only
npm run test:medium

# Run slow tests only
npm run test:slow

# Run full suite (fast → medium → slow)
npm run test:all
```

### E2E Tests (Playwright)

**IMPORTANT:** E2E tests require Rails backend in TEST mode with `.env.test` loaded.

#### Speed Profiles (Strict Enforcement)

E2E tests have **strict timeout enforcement** with unified timeout system:

- **Fast** (`<5s`): UI-only tests, no network calls, no backend needed
- **Medium** (`<15s`): API integration tests, no LLM calls
- **Slow** (`<30s`): Full integration with real LLM (ONE simple query max)

**Timeout Rules:**
- ❌ **NEVER** use explicit `{ timeout: X }` in test code
- ❌ **NEVER** use `await page.waitForLoadState("networkidle")`
- ✅ Speed profile controls **all** timeouts (test, assertions, page actions)
- ✅ Tests fail immediately if timeout exceeded

#### Recommended Usage (with automatic server management)

From project root:
```bash
# Run all E2E tests (script manages servers)
bin/test-e2e

# Run only fast E2E tests (UI only, no backend)
bin/test-e2e fast

# Run only medium E2E tests (API calls, no LLM)
bin/test-e2e medium

# Run only slow E2E tests (real LLM integration)
bin/test-e2e slow

# Pass additional playwright arguments
bin/test-e2e slow --project=chromium --grep "plan generation"
```

The `bin/test-e2e` script automatically:
- Kills and restarts Rails in TEST environment (loads `.env.test`)
- Manages Vite frontend via Playwright's webServer
- Waits for both servers to be ready
- Runs Playwright tests with proper speed filtering
- Cleans up servers after tests complete

#### Manual Usage (servers already running)

If you're running servers manually in test mode:
```bash
# Terminal 1: Start Rails in TEST mode
RAILS_ENV=test bundle exec rails server -p 4000

# Terminal 2: Start Vite frontend
cd frontend && npm run dev

# Terminal 3: Run E2E tests
cd frontend/e2e
SKIP_WEBSERVER=1 npx playwright test

# Or with speed filter
SKIP_WEBSERVER=1 TEST_SPEED_FILTER=slow npx playwright test
```

#### Debug/Development Mode

```bash
# Run with headed browser (see what's happening)
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --headed

# Run with debug mode (step through tests)
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --debug

# Run with UI mode (interactive)
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --ui

# View test report
cd frontend/e2e && npx playwright show-report
```

### Implementation

**ALL E2E tests MUST use the speed-profiled test functions from `base-test.ts`:**

```javascript
// ❌ WRONG - Do NOT import test directly from playwright
import { test } from '@playwright/test';

// ✅ CORRECT - Import fast/medium/slow from base-test
import { fast, medium, slow, expect } from './base-test';
```

- Speed profiles are enforced at the test level via `base-test.ts`
- Unified timeout system in `playwright.config.ts` and `base-test.ts`
- Timeouts automatically applied to test execution, assertions, and page actions
- No explicit timeouts allowed in test code

### Example Test

```javascript
import { fast, medium, slow, expect } from './base-test';

// Fast test: UI only, no network
fast('renders form with all fields', async ({ page }) => {
  await page.goto('/agent');
  await expect(page.locator('#goal')).toBeVisible();
  await expect(page.locator('.file-path-input')).toBeVisible();
  // Completes in < 5s
});

// Medium test: API call, no LLM
medium('loads configuration from API', async ({ page }) => {
  await page.goto('/agent');
  await page.locator('button').filter({ hasText: /configuration/i }).click();
  await expect(page.locator('.config-panel')).toBeVisible();
  // Completes in < 15s
});

// Slow test: Real LLM integration
slow('generates plan with real LLM', async ({ page }) => {
  await page.goto('/agent');
  await page.locator('#goal').fill('Add health check endpoint');
  await page.locator('button').filter({ hasText: /generate/i }).click();
  await expect(page.locator('.plan-result-section')).toBeVisible();
  // Completes in < 30s
});
```

### E2E Test Best Practices

1. **Use proper speed profile function** - `fast()`, `medium()`, or `slow()`
2. **Never use explicit timeouts** - `{ timeout: X }` is forbidden
3. **Never use networkidle** - `waitForLoadState("networkidle")` wastes time
4. **Wait for specific elements** - Use `expect().toBeVisible()` instead
5. **Follow OOP principles** - Tests should create unique instances (UUIDs)
6. **Break down complex tests** - One slow test = ONE LLM query max
7. **Let tests fail fast** - Timeouts indicate real problems, not CI flakiness

## CI/CD Integration

### Running Tests in CI

```bash
# Backend - run all speed levels
bin/test all

# Frontend - run all speed levels
cd frontend && npm run test:all

# E2E tests
cd frontend && npm run e2e
```

### Timeouts

**Backend (Rails):**
- Fast tests timeout after 10s (fail if exceeded)
- Medium tests timeout after 60s (fail if exceeded)
- Slow tests timeout after 120s (fail if exceeded)

**Frontend E2E (Playwright):**
- Fast tests timeout after 5s (fail if exceeded)
- Medium tests timeout after 15s (fail if exceeded)
- Slow tests timeout after 30s (fail if exceeded)

**Critical:** Timeouts apply to test execution, assertions, and page actions uniformly.
No explicit timeout parameters are allowed in test code.

## Excluding Tests

### Backend

Research-related tests are automatically excluded:
- `test/workers/codebase_researcher_test.rb`
- `test/workflows/research_workflow_test.rb`

### Frontend

Use `test.skip` or test filtering:

```javascript
test.skip('not ready yet', () => {
  // Skipped test
});
```

## Debugging

### Backend

```bash
# Run specific test file
bundle exec rails test test/path/to/test.rb

# Run specific test by line number
bundle exec rails test test/path/to/test.rb:42

# Run with verbose output
bundle exec rails test test/path/to/test.rb -v
```

### Frontend

```bash
# Run specific test file
npm test -- src/path/to/test.js

# Run in watch mode for debugging
npm run test:watch

# Run with UI (Vitest UI)
npx vitest --ui
```

## Best Practices

1. **Always categorize new tests** with the appropriate speed profile
2. **Tests timing out are NOT passing** - they are failures
3. **Follow OOP patterns** from `docs/references/oop-patterns.md`
4. **Use real instances** over mocks when possible
5. **Test real integrations** not isolated units in slow tests
6. **Keep fast tests fast** - mock expensive operations
7. **Use factories** for easy test data setup
8. **Fail-fast validation** in constructors to catch errors early

## Continuous Improvement

If you find a test is consistently timing out:

1. **Review the speed profile** - is it categorized correctly?
2. **Optimize the test** - can expensive operations be mocked for faster profiles?
3. **Move to slower profile** - if the test genuinely needs time (LLM calls, etc.)
4. **Check for bugs** - timeouts can indicate real issues in the code

## Summary

- Use `bin/test fast` or `npm run test:fast` for quick feedback during development
- Use `bin/test all` or `npm run test:all` for comprehensive testing before commits
- All tests should complete within their timeout limits
- Consistent test structure across backend and frontend for predictability

