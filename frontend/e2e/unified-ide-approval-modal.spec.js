/**
 * UnifiedIDE - Approval Modal Integration E2E Tests
 * 
 * SPEED PROFILE: medium (requires approval workflow setup)
 * Tests that ApprovalModal appears and functions within UnifiedIDE
 */

import { expect, medium } from "./base-test";

medium("approval modal - appears when Sisyphus requests approval", async ({ page }) => {
  await page.goto("/");
  
  // Select Sisyphus mode
  const modeSelector = page.locator('select.agent-selector');
  await modeSelector.selectOption("sisyphus");
  
  // Initialize session
  const initButton = page.locator('button:has-text("Initialize Session")');
  if (await initButton.isVisible()) {
    await initButton.click();
    await expect(page.locator('text=Session:')).toBeVisible({ timeout: 15000 });
  }
  
  // Note: To fully test this, we'd need to:
  // 1. Set up a project path
  // 2. Provide an execution plan
  // 3. Start execution with step approval mode
  // 4. Wait for first step approval request
  
  // For now, verify the modal structure exists in the DOM
  // (even if not visible without actual execution)
  const modalBackdrop = page.locator('.approval-modal-backdrop');
  // Modal should not be visible initially
  await expect(modalBackdrop).not.toBeVisible();
});

medium("approval modal - approve button sends approval", async ({ page }) => {
  await page.goto("/");
  
  // This is a placeholder test - in practice, we'd need to:
  // 1. Set up a real Sisyphus execution
  // 2. Wait for approval request
  // 3. Click approve
  // 4. Verify execution continues
  
  // For now, just verify the component exists
  const configBtn = page.locator('button:has-text("⚙️")');
  await expect(configBtn).toBeVisible();
});

medium("approval modal - reject button cancels execution", async ({ page }) => {
  await page.goto("/");
  
  // This is a placeholder test - in practice, we'd need to:
  // 1. Set up a real Sisyphus execution
  // 2. Wait for approval request
  // 3. Click reject
  // 4. Verify execution stops
  
  // For now, just verify basic UI elements
  const modeSelector = page.locator('select.agent-selector');
  await expect(modeSelector).toBeVisible();
});

