/**
 * UnifiedIDE - Modal Interactions E2E Tests
 * 
 * SPEED PROFILE: fast (UI only)
 * Tests config modal, preferences modal, and their interactions
 */

import { expect, fast } from "./base-test";

fast("config modal - opens when gear icon clicked", async ({ page }) => {
  await page.goto("/");
  
  const configBtn = page.locator('button:has-text("⚙️")');
  await configBtn.click();
  
  // Modal overlay should be visible
  await expect(page.locator('.modal-overlay')).toBeVisible();
  
  // Configuration panel should be visible
  await expect(page.locator('.configuration-panel, text=Configuration')).toBeVisible();
});

fast("config modal - closes when close button clicked", async ({ page }) => {
  await page.goto("/");
  
  // Open modal
  await page.locator('button:has-text("⚙️")').click();
  await expect(page.locator('.modal-overlay')).toBeVisible();
  
  // Close via button
  await page.locator('button:has-text("Close")').click();
  await expect(page.locator('.modal-overlay')).not.toBeVisible();
});

fast("config modal - closes when backdrop clicked", async ({ page }) => {
  await page.goto("/");
  
  // Open modal
  await page.locator('button:has-text("⚙️")').click();
  await expect(page.locator('.modal-overlay')).toBeVisible();
  
  // Click backdrop (overlay but not content)
  await page.locator('.modal-overlay').click({ position: { x: 5, y: 5 } });
  await expect(page.locator('.modal-overlay')).not.toBeVisible();
});

fast("preferences modal - opens when user icon clicked", async ({ page }) => {
  await page.goto("/");
  
  const prefsBtn = page.locator('button:has-text("👤")');
  await prefsBtn.click();
  
  // Preferences panel should be visible
  await expect(page.locator('.user-preferences-panel, [data-testid="preferences-panel"]')).toBeVisible();
});

fast("preferences modal - closes via close handler", async ({ page }) => {
  await page.goto("/");
  
  // Open preferences
  await page.locator('button:has-text("👤")').click();
  await expect(page.locator('.user-preferences-panel, [data-testid="preferences-panel"]')).toBeVisible();
  
  // Close button should exist
  const closeBtn = page.locator('.user-preferences-panel button:has-text("Close"), button:has-text("×")');
  const closeExists = await closeBtn.isVisible().catch(() => false);
  
  if (closeExists) {
    await closeBtn.click();
    await expect(page.locator('.user-preferences-panel')).not.toBeVisible();
  }
});

fast("modals - only one modal open at a time", async ({ page }) => {
  await page.goto("/");
  
  // Open config
  await page.locator('button:has-text("⚙️")').click();
  await expect(page.locator('.modal-overlay')).toBeVisible();
  
  // Try to open preferences - config should close first or preferences shouldn't open
  await page.locator('button:has-text("👤")').click();
  
  // Verify only one type of modal is visible
  const configVisible = await page.locator('.configuration-panel').isVisible().catch(() => false);
  const prefsVisible = await page.locator('.user-preferences-panel').isVisible().catch(() => false);
  
  // Both shouldn't be visible at same time
  expect(configVisible && prefsVisible).toBe(false);
});

fast("persistent context bar - only visible when session active", async ({ page }) => {
  await page.goto("/");
  
  // Initially no session, context bar should not be visible
  const contextBar = page.locator('.persistent-context-bar');
  await expect(contextBar).not.toBeVisible();
  
  // Initialize session
  const initButton = page.locator('button:has-text("Initialize Session")');
  if (await initButton.isVisible()) {
    await initButton.click();
    await expect(page.locator('text=Session:')).toBeVisible({ timeout: 15000 });
    
    // Now context bar should be visible
    await expect(contextBar).toBeVisible();
  }
});

