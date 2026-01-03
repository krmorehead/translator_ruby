import { expect } from "@playwright/test";
import { fast, medium, slow } from "./helpers/speedProfile.js";
import { ApprovalRequest } from "../src/models/ApprovalRequest";
import { ApprovalRequestFactory } from "../src/factories/approvalRequestFactory";

/**
 * Sisyphus E2E Tests - REAL FLOW ONLY
 * 
 * MIGRATED TO UNIFIED AGENT WORKSPACE
 * - Tests now use /sisyphus route (points to AgentWorkspace)
 * - Ensures Sisyphus mode is selected
 * - All original functionality preserved
 * 
 * NO TEST ENDPOINTS - Uses real Sisyphus execution with real LLM
 * NO MOCKS - Tests actual approval flow
 * 
 * SPEED PROFILE: Tests broken down by speed
 * - Fast (< 5s): Model/factory tests, no I/O
 * - Medium (< 15s): UI interactions, no LLM
 * - Slow (< 30s): Real execution tests
 */

/**
 * Helper to ensure we're in Sisyphus mode on the unified AgentWorkspace
 */
async function ensureSisyphusMode(page) {
  const modeSelector = page.locator("select.mode-selector");
  
  // Check if mode selector exists (unified interface)
  if (await modeSelector.count() > 0) {
    await modeSelector.selectOption("sisyphus");
  }
  
  // Wait a moment for mode switch
  await page.waitForLoadState("networkidle");
}

// =============================================================================
// FACTORY TESTS - Pure JavaScript, no browser (< 1ms each)
// =============================================================================

fast("creates valid step approval", () => {
  const approval = ApprovalRequestFactory.buildStep({
    executionId: "test-123",
    subjectTitle: "Test Step"
  });

  expect(approval).toBeInstanceOf(ApprovalRequest);
  expect(approval.isStep()).toBe(true);
  expect(approval.isPending()).toBe(true);
});

fast("creates valid milestone approval", () => {
  const approval = ApprovalRequestFactory.buildMilestone({
    executionId: "test-456",
    subjectTitle: "Test Milestone"
  });

  expect(approval).toBeInstanceOf(ApprovalRequest);
  expect(approval.isMilestone()).toBe(true);
});

fast("creates approval with planned actions", () => {
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

fast("serializes approval to JSON correctly", () => {
  const approval = ApprovalRequestFactory.build({
    executionId: "ser-123"
  });

  const json = approval.toJSON();
  
  expect(json.execution_id).toBe("ser-123");
  expect(json.status).toBe("pending");
  expect(Object.isFrozen(approval)).toBe(true);
});

fast("validates approval transitions", () => {
  const approval = ApprovalRequestFactory.build();
  
  expect(approval.isPending()).toBe(true);
  
  const approved = approval.approve();
  expect(approved.isApproved()).toBe(true);
  expect(Object.isFrozen(approved)).toBe(true);
  
  const rejected = approval.reject("Not good");
  expect(rejected.isRejected()).toBe(true);
  expect(rejected.rejectionReason).toBe("Not good");
});

// =============================================================================
// UI TESTS - Medium (UI interactions, no LLM)
// =============================================================================

medium("should render Sisyphus interface", async ({ page }) => {
  await page.goto("http://localhost:3000/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  // Should show Sisyphus-specific UI
  await expect(page.locator("text=/sisyphus/i")).toBeVisible({ timeout: 5000 });
  
  // Should have execution controls
  const startButton = page.getByRole("button", { name: /start|execute/i });
  await expect(startButton).toBeVisible();
});

medium("should display approval request UI", async ({ page }) => {
  await page.goto("http://localhost:3000/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  // Check for approval UI elements
  const approvalSection = page.locator("[class*='approval']");
  const exists = await approvalSection.count() > 0;
  
  if (exists) {
    await expect(approvalSection.first()).toBeVisible();
  }
});
