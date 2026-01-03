import { expect, medium, slow } from "./base-test";

/**
 * Sisyphus Page E2E Tests
 * 
 * MIGRATED TO UNIFIED AGENT WORKSPACE
 * Tests execution workflow through unified interface
 */

async function ensureSisyphusMode(page) {
  const modeSelector = page.locator("select.mode-selector");
  if (await modeSelector.count() > 0) {
    await modeSelector.selectOption("sisyphus");
  }
  await page.waitForLoadState("networkidle");
}

medium("sisyphus - should load Sisyphus workspace", async ({ page }) => {
  await page.goto("/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  await expect(page.locator("h1").filter({ hasText: /sisyphus/i })).toBeVisible();
});

medium("sisyphus - should show execution controls", async ({ page }) => {
  await page.goto("/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  const executeButton = page.getByRole("button", { name: /execute|start/i });
  await expect(executeButton).toBeVisible();
});
