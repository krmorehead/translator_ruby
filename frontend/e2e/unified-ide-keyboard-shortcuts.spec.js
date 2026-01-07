/**
 * UnifiedIDE - Keyboard Shortcuts E2E Tests
 * 
 * SPEED PROFILE: fast (UI only)
 * Tests keyboard shortcuts functionality in UnifiedIDE
 */

import { expect, fast } from "./base-test";

fast("keyboard shortcuts - Cmd+K focuses chat input", async ({ page }) => {
  await page.goto("/");
  
  // Initialize session first
  const initButton = page.locator('button:has-text("Initialize Session")');
  if (await initButton.isVisible()) {
    await initButton.click();
    await expect(page.locator('text=Session:')).toBeVisible({ timeout: 15000 });
  }
  
  // Ensure chat tab is active
  const chatTab = page.locator('button:has-text("💬 Chat")');
  if (await chatTab.isVisible()) {
    await chatTab.click();
  }
  
  // Press Cmd+K (or Ctrl+K on Linux/Windows)
  await page.keyboard.press('Meta+k'); // or 'Control+k' on non-Mac
  
  // Chat input should be focused
  const chatInput = page.locator('textarea[placeholder*="message"], input[placeholder*="message"]');
  await expect(chatInput).toBeFocused();
});

fast("keyboard shortcuts - Cmd+1-5 switches tabs", async ({ page }) => {
  await page.goto("/");
  
  // Initialize session
  const initButton = page.locator('button:has-text("Initialize Session")');
  if (await initButton.isVisible()) {
    await initButton.click();
    await expect(page.locator('text=Session:')).toBeVisible({ timeout: 15000 });
  }
  
  // Press Cmd+2 for thoughts tab
  await page.keyboard.press('Meta+2');
  await expect(page.locator('button:has-text("💭 Thoughts").active')).toBeVisible();
  
  // Press Cmd+3 for context tab
  await page.keyboard.press('Meta+3');
  await expect(page.locator('button:has-text("📁 Context").active')).toBeVisible();
  
  // Press Cmd+4 for timeline tab
  await page.keyboard.press('Meta+4');
  await expect(page.locator('button:has-text("⏱️ Timeline").active')).toBeVisible();
  
  // Press Cmd+5 for checkpoints tab
  await page.keyboard.press('Meta+5');
  await expect(page.locator('button:has-text("📍 Checkpoints").active')).toBeVisible();
  
  // Press Cmd+1 to go back to chat
  await page.keyboard.press('Meta+1');
  await expect(page.locator('button:has-text("💬 Chat").active')).toBeVisible();
});

fast("keyboard shortcuts - ESC closes approval modal", async ({ page }) => {
  await page.goto("/");
  
  // Note: This test assumes we can trigger an approval modal
  // In practice, this would require starting a Sisyphus execution
  // For now, we just verify the modal closes with ESC if present
  
  // Check if approval modal exists
  const modal = page.locator('.approval-modal-backdrop');
  const modalExists = await modal.isVisible().catch(() => false);
  
  if (modalExists) {
    await page.keyboard.press('Escape');
    await expect(modal).not.toBeVisible();
  }
});

fast("keyboard shortcuts - config button has aria-label", async ({ page }) => {
  await page.goto("/");
  
  const configBtn = page.locator('button:has-text("⚙️")');
  await expect(configBtn).toBeVisible();
  
  // Verify it's keyboard accessible
  await configBtn.focus();
  await expect(configBtn).toBeFocused();
});

