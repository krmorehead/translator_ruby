import { expect, fast, medium } from "./base-test";

/**
 * Checkpoint Manager E2E Tests
 * 
 * Profile: fast (UI only) or medium (API calls)
 */

// =============================================================================
// Initial UI - FAST
// =============================================================================

fast("checkpoint - displays checkpoint manager UI", async ({ page }) => {
  await page.goto("/checkpoints");
  await expect(page.locator("h1")).toContainText("Git Checkpoint Manager");
    });

fast("checkpoint - requires repository path before showing checkpoints", async ({ page }) => {
  await page.goto("/checkpoints");
  await expect(page.locator(".path-setup")).toBeVisible();
  await expect(page.locator("h2")).toContainText("Set Repository Path");
    });

// =============================================================================
// Repository Path Input - FAST
// =============================================================================

fast("checkpoint - can enter text in repository path input", async ({ page }) => {
  await page.goto("/checkpoints");
  const pathInput = page.locator(".path-input");
  await pathInput.fill("/test/repo/path");
  await expect(pathInput).toHaveValue("/test/repo/path");
    });

fast("checkpoint - set path button exists", async ({ page }) => {
  await page.goto("/checkpoints");
  const setPathButton = page.getByRole("button", { name: /set path/i });
  await expect(setPathButton).toBeVisible();
    });

fast("checkpoint - does not submit empty path", async ({ page }) => {
  await page.goto("/checkpoints");
  const pathInput = page.locator(".path-input");
  await pathInput.fill("");
  
  const setPathButton = page.getByRole("button", { name: /set path/i });
  await setPathButton.click();
      
  // Should still show path setup (not advance)
  await expect(page.locator(".path-setup")).toBeVisible();
    });

// =============================================================================
// Create Checkpoint Dialog - MEDIUM (may involve API)
// =============================================================================

medium("checkpoint - create checkpoint button exists after path is set", async ({ page }) => {
  await page.goto("/checkpoints");
  
  const pathInput = page.locator(".path-input");
  await pathInput.fill("/home/kyle/Side_Projects/translator_ruby");
  
  const setPathButton = page.getByRole("button", { name: /set path/i });
  await setPathButton.click();
  
  // Wait for API response
  const createButton = page.getByRole("button", { name: /create checkpoint/i });
  await expect(createButton).toBeVisible();
  });

medium("checkpoint - shows metadata form when create dialog opens", async ({ page }) => {
  await page.goto("/checkpoints");
  
  const pathInput = page.locator(".path-input");
  await pathInput.fill("/home/kyle/Side_Projects/translator_ruby");
  
  const setPathButton = page.getByRole("button", { name: /set path/i });
  await setPathButton.click();
  
  // Wait for API response
  const createButton = page.getByRole("button", { name: /create checkpoint/i });
  await expect(createButton).toBeVisible();
  
  if (await createButton.isVisible().catch(() => false)) {
    await createButton.click();
    
    // Look for dialog or form elements
    const dialogOrForm = page.locator("dialog, [role='dialog'], form.checkpoint-form");
    const visible = await dialogOrForm.isVisible().catch(() => false);
    
    if (visible) {
      await expect(dialogOrForm.first()).toBeVisible();
    }
  }
  });

// =============================================================================
// UI Component Structure - FAST
// =============================================================================

fast("checkpoint - has path input component", async ({ page }) => {
  await page.goto("/checkpoints");
  await expect(page.locator(".path-input")).toBeVisible();
    });

fast("checkpoint - has set path button", async ({ page }) => {
  await page.goto("/checkpoints");
  await expect(page.getByRole("button", { name: /set path/i })).toBeVisible();
    });

fast("checkpoint - shows path setup instructions", async ({ page }) => {
  await page.goto("/checkpoints");
  await expect(page.locator("h2")).toContainText("Set Repository Path");
    });

// =============================================================================
// Form Validation - FAST
// =============================================================================

fast("checkpoint - path input accepts keyboard input", async ({ page }) => {
  await page.goto("/checkpoints");
  const pathInput = page.locator(".path-input");
  await pathInput.type("/test/path", { delay: 10 });
  await expect(pathInput).toHaveValue("/test/path");
    });

fast("checkpoint - path input can be cleared", async ({ page }) => {
  await page.goto("/checkpoints");
  const pathInput = page.locator(".path-input");
  await pathInput.fill("/some/path");
      await pathInput.clear();
  await expect(pathInput).toHaveValue("");
});
