import { expect } from "@playwright/test";
import { medium, slow } from "./helpers/speedProfile.js";

/**
 * Sisyphus Page E2E Tests
 * 
 * MIGRATED TO UNIFIED AGENT WORKSPACE
 * Tests execution workflow through unified interface
 * 
 * SPEED PROFILE:
 * - medium (15s): UI only, no LLM
 * - slow (30s): With real execution/LLM
 */

async function ensureSisyphusMode(page) {
  const modeSelector = page.locator("select.mode-selector");
  if (await modeSelector.count() > 0) {
    await modeSelector.selectOption("sisyphus");
  }
  await page.waitForLoadState("networkidle");
}

medium("should load Sisyphus workspace", async ({ page }) => {
  await page.goto("http://localhost:3000/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  await expect(page.locator("text=/sisyphus/i")).toBeVisible({ timeout: 5000 });
});

medium("should show execution controls", async ({ page }) => {
  await page.goto("http://localhost:3000/sisyphus");
  await page.waitForLoadState("networkidle");
  
  await ensureSisyphusMode(page);
  
  const executeButton = page.getByRole("button", { name: /execute|start/i });
  await expect(executeButton).toBeVisible();
});
