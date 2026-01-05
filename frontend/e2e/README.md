# E2E Testing Guide - Daedalus & Sisyphus

## Overview

This directory contains End-to-End (E2E) tests for both Daedalus (planning) and Sisyphus (execution) using **Playwright**. These tests verify complete user workflows with real backend API and LLM integration in a browser environment.

## Test Framework

- **Playwright**: Browser automation framework
- **Speed Profiling**: All tests must use `fast()`, `medium()`, or `slow()` from `base-test.ts`
- **Real Integration**: Tests use actual backend APIs and LLM - NO MOCKS
- **Test Environment**: Rails runs in TEST mode with `.env.test` configuration

## Directory Structure

```
frontend/
├── e2e/
│   ├── sisyphus.spec.js              # Main Sisyphus page tests
│   ├── sisyphus-approval.spec.js     # Approval modal tests
│   ├── chat.spec.js                  # Existing chat tests
│   ├── checkpoint.spec.js            # Existing checkpoint tests
│   └── playwright.config.js          # Playwright configuration
├── src/
│   └── components/
│       └── __tests__/                # Component unit tests (Vitest)
└── package.json
```

## Running Tests

### Recommended: Use Test Script (Manages Servers Automatically)

From project root:
```bash
# Run all E2E tests (script starts Rails in TEST mode + Vite)
bin/test-e2e

# Run by speed profile
bin/test-e2e fast      # UI only, no backend (< 5s each)
bin/test-e2e medium    # API calls, no LLM (< 15s each)
bin/test-e2e slow      # Real LLM integration (< 30s each)

# Pass additional playwright options
bin/test-e2e slow --project=chromium --grep "plan generation"
bin/test-e2e medium --max-failures=1
```

The script automatically:
- ✅ Starts Rails in `RAILS_ENV=test` (uses `.env.test`)
- ✅ Starts Vite frontend with proxy to backend
- ✅ Waits for servers to be ready
- ✅ Runs tests with proper environment
- ✅ Cleans up servers after completion

### Manual: Servers Already Running

If you're managing servers yourself:
```bash
# Terminal 1: Rails in TEST mode
RAILS_ENV=test bundle exec rails server -p 4000

# Terminal 2: Vite frontend  
cd frontend && npm run dev

# Terminal 3: Run tests
cd frontend/e2e
SKIP_WEBSERVER=1 npx playwright test
SKIP_WEBSERVER=1 TEST_SPEED_FILTER=slow npx playwright test
```

### Development/Debug Mode

```bash
# Run with visible browser
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --headed

# Step-by-step debugging
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --debug

# Interactive UI mode
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --ui

# Specific browser
cd frontend/e2e && SKIP_WEBSERVER=1 npx playwright test --project=chromium

# View test report
cd frontend/e2e && npx playwright show-report
```

## Speed Profiling & Unified Timeout System

**CRITICAL RULES:**
- ✅ **ALWAYS** import `{ fast, medium, slow, expect }` from `"./base-test"`
- ❌ **NEVER** import `test` directly from `"@playwright/test"`  
- ❌ **NEVER** use explicit timeouts: `{ timeout: X }` is FORBIDDEN
- ❌ **NEVER** use `await page.waitForLoadState("networkidle")` - WASTEFUL

### Speed Profiles with Unified Timeout System

All timeouts (test, assertions, page actions) are controlled by speed profile:

```javascript
import { fast, medium, slow, expect } from "./base-test";

// FAST (< 5s): UI only, no network calls, no backend needed
fast("renders Daedalus form", async ({ page }) => {
  await page.goto("/agent");
  await expect(page.locator("h1")).toContainText("Daedalus");
  // All timeouts = 5s (test, assertions, page actions)
});

// MEDIUM (< 15s): API calls, no LLM
medium("loads configuration", async ({ page }) => {
  await page.goto("/agent");
  // API call to fetch config
  await expect(page.locator(".capability-card")).toBeVisible();
  // All timeouts = 15s
});

// SLOW (< 30s): Real LLM integration - ONE simple query MAX
slow("generates execution plan with real LLM", async ({ page }) => {
  await page.goto("/agent");
  await page.locator("#goal").fill("Add health endpoint");
  await page.locator("button").filter({ hasText: /generate/i }).click();
  // Real LLM call happens here - NO explicit timeout needed!
  await expect(page.locator(".plan-result")).toBeVisible();
  // All timeouts = 30s
});
```

### How Unified Timeout System Works

1. **Config Level** (`playwright.config.ts`):
   - `expect.timeout` reads from `E2E_TEST_SPEED_FILTER` env var
   - `actionTimeout: 0` and `navigationTimeout: 0` disable defaults

2. **Test Level** (`base-test.ts`):
   - `playwrightTest.setTimeout(timeout)` - overall test timeout
   - `page.setDefaultTimeout(timeout)` - page action timeout
   - `page.setDefaultNavigationTimeout(timeout)` - navigation timeout

3. **Result**: Single source of truth per speed profile - NO conflicts!

### Why This Approach?

1. **Enforces Timeout Limits**: Tests must complete within profile or fail immediately
2. **Catches Real Problems**: Timeouts indicate actual issues, not CI flakiness
3. **Prevents Workarounds**: Can't hide problems with explicit timeouts
4. **Clear Error Messages**: Shows expected vs actual time with helpful diagnostic info
5. **OOP Principles**: Tests create unique instances (UUIDs), preventing collisions

### Test Speed Guidelines

- **FAST tests** (`< 5s`): No network, no file I/O, pure UI interactions
- **MEDIUM tests** (`< 15s`): API calls to config/status endpoints, no LLM
- **SLOW tests** (`< 30s`): Real LLM calls, ONE simple query MAX
  - **Keep it minimal**: Don't chain multiple LLM calls
  - **Break it down**: Split complex workflows into multiple tests
  - **Use proper selectors**: Wait for specific elements, not networkidle

## Test Coverage

### Sisyphus Page Tests (`sisyphus.spec.js`)

**Basic UI Elements**:
- ✅ Page loads with correct title
- ✅ Three-panel layout (Project Setup, Execution Monitor, Configuration)
- ✅ Project path input
- ✅ Plan path input
- ✅ Start Execution button (enabled/disabled states)
- ✅ Browse Files button (enabled/disabled states)

**Execution Options**:
- ✅ Dry-run mode checkbox toggle
- ✅ "PREVIEW ONLY" badge visibility
- ✅ Description text updates
- ✅ Approval mode selector (3 options)
- ✅ Approval mode descriptions

**Responsive Design**:
- ✅ Mobile viewport (375x667)
- ✅ Tablet viewport (768x1024)

**Test Count**: 20 tests

### Approval Modal Tests (`sisyphus-approval.spec.js`)

**Modal Structure** (with backend integration):
- ⏸️ Modal appearance when approval required
- ⏸️ Countdown timer updates
- ⏸️ Planned actions list display
- ⏸️ Estimated changes display
- ⏸️ Approve/Reject buttons
- ⏸️ Close button behavior
- ⏸️ Backdrop click to close

**Visual Elements**:
- ⏸️ Step/Milestone badges
- ⏸️ Expired state warning
- ⏸️ Mobile responsive layout

**Test Count**: 14 tests (8 skipped, pending backend integration)

**Note**: Tests marked with `test.skip()` require:
1. Running Rails backend with approval endpoints
2. Mocked approval state, OR
3. Test fixtures

## Writing New Tests

### Test Structure

```javascript
import { test, expect } from "@playwright/test";

test.describe("Feature Name", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/sisyphus");
  });

  test("should do something", async ({ page }) => {
    // Arrange
    await page.getByPlaceholder("/path/to/project").fill("/test/path");
    
    // Act
    await page.getByRole("button", { name: /Start/ }).click();
    
    // Assert
    await expect(page.getByText("Success")).toBeVisible();
  });
});
```

### Best Practices

1. **Use Semantic Selectors**:
   ```javascript
   // Good - semantic, accessible
   page.getByRole("button", { name: /Submit/ })
   page.getByPlaceholder("Enter email")
   page.getByLabel("Username")
   
   // Avoid - brittle
   page.locator(".btn-primary")
   page.locator("#submit-button")
   ```

2. **Wait for Elements**:
   ```javascript
   // Playwright auto-waits, but be explicit for clarity
   await expect(page.getByText("Loading...")).toBeVisible();
   await expect(page.getByText("Loaded!")).toBeVisible({ timeout: 10000 });
   ```

3. **Test User Flows, Not Implementation**:
   ```javascript
   // Good - tests user workflow
   test("user can submit form", async ({ page }) => {
     await page.getByLabel("Name").fill("John");
     await page.getByRole("button", { name: /Submit/ }).click();
     await expect(page.getByText("Success")).toBeVisible();
   });
   
   // Avoid - tests implementation details
   test("setState is called", async ({ page }) => {
     // Don't test internal state management
   });
   ```

4. **Use Page Object Pattern for Complex Flows**:
   ```javascript
   // pages/SisyphusPage.js
   export class SisyphusPage {
     constructor(page) {
       this.page = page;
       this.projectInput = page.getByPlaceholder("/path/to/project");
       this.planInput = page.getByPlaceholder("/path/to/plan.md");
       this.startButton = page.getByRole("button", { name: /Start Execution/ });
     }
     
     async fillForm(projectPath, planPath) {
       await this.projectInput.fill(projectPath);
       await this.planInput.fill(planPath);
     }
     
     async startExecution() {
       await this.startButton.click();
     }
   }
   
   // In test
   const sisyphusPage = new SisyphusPage(page);
   await sisyphusPage.fillForm("/project", "/plan.md");
   await sisyphusPage.startExecution();
   ```

## Testing with Backend

### Option 1: Test Backend Server

Run a separate Rails server for testing:

```bash
# Terminal 1: Start test backend
RAILS_ENV=test rails server -p 3001

# Terminal 2: Run E2E tests
BASE_URL=http://localhost:3001 npm run e2e
```

### Option 2: Mock API Responses

Use Playwright's `route` to mock API calls:

```javascript
test("handles API error gracefully", async ({ page }) => {
  // Mock API failure
  await page.route("/api/sisyphus/executions", route => {
    route.fulfill({
      status: 500,
      body: JSON.stringify({ error: "Server error" })
    });
  });
  
  await page.goto("/sisyphus");
  await page.getByRole("button", { name: /Start/ }).click();
  
  await expect(page.getByText("Error")).toBeVisible();
});
```

### Option 3: Inject Store State

Directly manipulate frontend state for testing:

```javascript
test("approval modal with mocked data", async ({ page }) => {
  await page.goto("/sisyphus");
  
  // Inject approval into store
  await page.evaluate(() => {
    const mockApproval = {
      id: "test-123",
      type: "step",
      subject_title: "Test Step",
      // ... other fields
    };
    
    // Access Zustand store (if exposed globally)
    window.sisyphusStore?.setState({ pendingApproval: mockApproval });
  });
  
  await expect(page.getByRole("heading", { name: /Approval Required/ })).toBeVisible();
});
```

## Debugging Failed Tests

### 1. View Test Report
```bash
npx playwright show-report
```

### 2. Run in Debug Mode
```bash
npm run e2e -- --debug sisyphus.spec.js
```

### 3. Check Screenshots
Failed tests automatically capture screenshots in `test-results/`:
```
test-results/
└── sisyphus-page-loads-chromium/
    ├── test-failed-1.png
    └── trace.zip
```

### 4. View Trace
```bash
npx playwright show-trace test-results/.../trace.zip
```

### 5. Slow Down Test
```javascript
test.use({ slowMo: 500 }); // Slow down by 500ms per action
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        working-directory: frontend
        run: npm ci
      
      - name: Install Playwright Browsers
        working-directory: frontend
        run: npx playwright install --with-deps
      
      - name: Start Backend (if needed)
        run: |
          # Start Rails server in background
          RAILS_ENV=test rails server -p 3001 &
          sleep 5
      
      - name: Run E2E tests
        working-directory: frontend
        run: npm run e2e
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: frontend/test-results/
```

## Test Data Management

### Fixtures

Create reusable test data:

```javascript
// fixtures/approval.js
export const mockApproval = {
  step: {
    id: "approval-step-123",
    type: "step",
    status: "pending",
    subject_title: "Create file",
    planned_actions: ["Create hello.rb"],
    estimated_changes: { files_to_create: 1 },
    timeout_at: new Date(Date.now() + 300000).toISOString()
  },
  milestone: {
    id: "approval-milestone-456",
    type: "milestone",
    status: "pending",
    subject_title: "Setup Project",
    planned_actions: ["Create files", "Install deps"],
    estimated_changes: { files_to_create: 5, commands_to_run: 2 },
    timeout_at: new Date(Date.now() + 300000).toISOString()
  }
};

// In test
import { mockApproval } from "./fixtures/approval";

test("step approval", async ({ page }) => {
  await page.evaluate((approval) => {
    window.sisyphusStore?.setState({ pendingApproval: approval });
  }, mockApproval.step);
});
```

## Performance Testing

### Check Page Load Time
```javascript
test("page loads within 2 seconds", async ({ page }) => {
  const startTime = Date.now();
  
  await page.goto("/sisyphus");
  await page.waitForLoadState("networkidle");
  
  const loadTime = Date.now() - startTime;
  expect(loadTime).toBeLessThan(2000);
});
```

### Check Bundle Size Impact
```javascript
test("initial bundle is reasonable", async ({ page }) => {
  const metrics = await page.evaluate(() => performance.getEntriesByType("resource"));
  
  const jsFiles = metrics.filter(m => m.name.endsWith(".js"));
  const totalSize = jsFiles.reduce((sum, file) => sum + file.transferSize, 0);
  
  // Should be under 500KB
  expect(totalSize).toBeLessThan(500 * 1024);
});
```

## Accessibility Testing

```javascript
import { test, expect } from "@playwright/test";
import { injectAxe, checkA11y } from "axe-playwright";

test("page is accessible", async ({ page }) => {
  await page.goto("/sisyphus");
  await injectAxe(page);
  await checkA11y(page);
});
```

## Visual Regression Testing

```javascript
test("page matches screenshot", async ({ page }) => {
  await page.goto("/sisyphus");
  await expect(page).toHaveScreenshot("sisyphus-page.png");
});
```

## Resources

- **Playwright Docs**: https://playwright.dev
- **Testing Library**: https://testing-library.com
- **Vitest Docs**: https://vitest.dev
- **Zustand Testing**: https://github.com/pmndrs/zustand#testing

## Troubleshooting

### Tests Timeout

**DO NOT increase timeout!** Timeouts indicate real problems. Instead:

1. **Check if backend is running** (Rails on port 4000)
2. **Check if LLM is accessible** (ports 52003/52004)
3. **View trace** to see where test got stuck:
   ```bash
   npx playwright show-trace test-results/.../trace.zip
   ```
4. **Check selectors** - wrong selector = wait until timeout
5. **Break down test** - if legitimately too slow, split into smaller tests
6. **Remove wasteful waits** - NO `networkidle`, wait for specific elements

### Element Not Found

1. **Use debug mode** to inspect page:
   ```bash
   npx playwright test --debug
   ```
2. **Check if element is in iframe**:
   ```javascript
   const frame = page.frameLocator('iframe[name="content"]');
   await frame.locator('.element').click();
   ```
3. **Verify selector** - use Playwright Inspector to test selectors
4. **Wait for specific state**:
   ```javascript
   // Good - wait for specific element
   await expect(page.locator('.result')).toBeVisible();
   
   // Bad - wait for everything
   await page.waitForLoadState("networkidle"); // FORBIDDEN
   ```

### Flaky Tests (Test Sometimes Passes, Sometimes Fails)

**Flaky tests are CODE BUGS, not test infrastructure problems!**

1. **Check for race conditions** in the application code
2. **Ensure unique test data** - use UUIDs, not hardcoded IDs
3. **Follow OOP principles** - tests should create unique instances
4. **Use proper element waits**:
   ```javascript
   // Good - wait for specific element state
   await expect(page.locator('.loading')).toBeHidden();
   await expect(page.locator('.content')).toBeVisible();
   
   // Bad - arbitrary timeout
   await page.waitForTimeout(1000); // AVOID
   ```
5. **Check parallel test isolation** - tests should not share state

### Backend 500 Errors

1. **Check Rails logs**: `log/test.log`
2. **Ensure `.env.test` is loaded**
3. **Verify database is clean** between tests
4. **Check for missing environment variables**

### Store/State Issues

- **Don't access store directly** - test through UI interactions
- **Use API mocking** for controlled test scenarios
- **Component tests** (Vitest) for store logic, E2E for user flows

---

**Last Updated**: January 2, 2026  
**Test Count**: 34 total (20 active, 14 pending backend integration)  
**Coverage**: ~80% of Sisyphus UI workflows








