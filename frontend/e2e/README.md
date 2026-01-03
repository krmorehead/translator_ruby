# E2E Testing Guide for Sisyphus Frontend

## Overview

This directory contains End-to-End (E2E) tests for the Sisyphus frontend using **Playwright**. These tests verify the complete user workflows in a real browser environment.

## Test Framework

- **Playwright**: Browser automation framework
- **Vitest**: Unit/component testing (separate, in `src/components/__tests__/`)
- **Testing Library**: Component testing utilities

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

### All E2E Tests
```bash
cd frontend
npm run e2e
```

### Specific Test File
```bash
npm run e2e -- sisyphus.spec.js
```

### Headed Mode (See Browser)
```bash
npm run e2e -- --headed
```

### Debug Mode (Step Through)
```bash
npm run e2e -- --debug
```

### UI Mode (Interactive)
```bash
npx playwright test --ui
```

### Specific Browser
```bash
npm run e2e -- --project=chromium
npm run e2e -- --project=firefox
npm run e2e -- --project=webkit
```

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
- Increase timeout in `playwright.config.js`
- Check if backend is running
- Check network requests in trace viewer

### Element Not Found
- Use `page.pause()` to inspect page
- Check if element is inside iframe
- Verify selector is correct

### Flaky Tests
- Add explicit waits: `await page.waitForLoadState("networkidle")`
- Use `test.setTimeout()` for slow operations
- Avoid `page.waitForTimeout()` - use element waiters instead

### Can't Access Store
- Ensure store is exposed globally or use API mocking
- Consider component-level testing with Vitest for store logic

---

**Last Updated**: January 2, 2026  
**Test Count**: 34 total (20 active, 14 pending backend integration)  
**Coverage**: ~80% of Sisyphus UI workflows


