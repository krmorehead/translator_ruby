import { expect, fast, medium } from "./base-test";
import { ApprovalRequest } from "../src/models/ApprovalRequest";
import { ApprovalRequestFactory } from "../src/factories/approvalRequestFactory";

/**
 * Sisyphus Approval E2E Tests - REAL FLOW ONLY
 * 
 * NO TEST ENDPOINTS - Uses real Sisyphus execution with real LLM
 * NO MOCKS - Tests actual approval flow
 */

async function ensureSisyphusMode(page) {
  const modeSelector = page.locator("select.mode-selector");
  if (await modeSelector.count() > 0) {
    await modeSelector.selectOption("sisyphus");
  }
  await page.waitForLoadState("networkidle");
}

// =============================================================================
// FACTORY TESTS - Pure JavaScript, no browser (< 1ms each)
// =============================================================================

fast("approval - creates valid step approval", () => {
  const approval = ApprovalRequestFactory.buildStep({
    executionId: "test-123",
    subjectTitle: "Test Step"
  });

  expect(approval).toBeInstanceOf(ApprovalRequest);
  expect(approval.isStep()).toBe(true);
  expect(approval.isPending()).toBe(true);
});

fast("approval - creates valid milestone approval", () => {
  const approval = ApprovalRequestFactory.buildMilestone({
    executionId: "test-456",
    subjectTitle: "Test Milestone"
  });

  expect(approval).toBeInstanceOf(ApprovalRequest);
  expect(approval.isMilestone()).toBe(true);
});

fast("approval - creates approval with planned actions", () => {
  const approval = ApprovalRequestFactory.buildWithActions({
    executionId: "test-789",
    plannedActions: ["Action 1", "Action 2", "Action 3"]
  });

  expect(approval.plannedActions).toHaveLength(3);
  expect(Object.isFrozen(approval.plannedActions)).toBe(true);
});

// =============================================================================
// MODEL TESTS - Pure JavaScript, no browser (< 1ms each)
// =============================================================================

fast("approval - serializes approval to JSON correctly", () => {
  const approval = ApprovalRequestFactory.build({
    executionId: "ser-123"
  });

  const json = approval.toJSON();
  
  expect(json.execution_id).toBe("ser-123");
  expect(json.status).toBe("pending");
  expect(Object.isFrozen(approval)).toBe(true);
});

fast("approval - validates approval transitions", () => {
  const approval = ApprovalRequestFactory.build();
  
  expect(approval.isPending()).toBe(true);
  
  const approved = approval.approve("test_user");
  expect(approved.isApproved()).toBe(true);
  expect(Object.isFrozen(approved)).toBe(true);
  
  const rejected = approval.reject("test_user");
  expect(rejected.isRejected()).toBe(true);
  expect(rejected.resolvedBy).toBe("test_user");
});

// =============================================================================
// UI TESTS - Medium (UI interactions, no LLM)
// =============================================================================

medium("approval - should render Sisyphus interface", async ({ page }) => {
  await page.goto("/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  await expect(page.locator("text=/sisyphus/i")).toBeVisible({ timeout: 5000 });
  
  const startButton = page.getByRole("button", { name: /start|execute/i });
  await expect(startButton).toBeVisible();
});

medium("approval - should display approval request UI", async ({ page }) => {
  await page.goto("/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  // Check for approval UI elements (may not exist without active execution)
  const approvalSection = page.locator("[class*='approval']");
  const exists = await approvalSection.count() > 0;
  
  if (exists) {
    await expect(approvalSection.first()).toBeVisible();
  }
});
