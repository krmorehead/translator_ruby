import { expect, fast, medium } from "./base-test";

/**
 * E2E tests for Agent Integration
 * 
 * NOTE: Chat/LLM tests removed as the agent session chat API
 * is not yet fully implemented. Once the API is complete, add:
 * - Message sending/receiving tests
 * - Thought extraction tests
 * - Context integration tests
 * 
 * SPEED PROFILES:
 * - fast (5s): UI only, no API calls
 * - medium (15s): API calls, no LLM
 */

// =============================================================================
// MODE SWITCHING - FAST (UI only)
// =============================================================================

fast("integration - should switch between Daedalus and Sisyphus modes", async ({ page }) => {
  await page.goto("/agent");

  const heading = page.getByRole("heading", { level: 1 });
  await expect(heading).toContainText(/daedalus/i);

  const modeSelector = page.locator('select.mode-selector[aria-label="Agent Mode"]');
  await expect(modeSelector).toBeVisible();
  await modeSelector.selectOption("sisyphus");


  await expect(heading).toContainText(/sisyphus/i);

  await modeSelector.selectOption("daedalus");

  await expect(heading).toContainText(/daedalus/i);
});
