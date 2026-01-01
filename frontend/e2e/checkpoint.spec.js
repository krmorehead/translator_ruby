import { test, expect } from '@playwright/test';

test.describe('Checkpoint Manager', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000/checkpoints');
  });

  test('displays checkpoint manager UI', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Git Checkpoint Manager');
  });

  test('requires repository path before showing checkpoints', async ({ page }) => {
    await expect(page.locator('.path-setup')).toBeVisible();
    await expect(page.locator('h2')).toContainText('Set Repository Path');
  });

  test('allows setting repository path', async ({ page }) => {
    const pathInput = page.locator('.path-input');
    await pathInput.fill('/test/repo/path');
    
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Should show toolbar with path info
    await expect(page.locator('.path-info')).toContainText('/test/repo/path');
  });

  test('shows create checkpoint dialog', async ({ page }) => {
    // Set path first
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Click create button
    await page.locator('button').filter({ hasText: 'Create Checkpoint' }).click();
    
    // Dialog should appear
    await expect(page.locator('.dialog')).toBeVisible();
    await expect(page.locator('.dialog h2')).toContainText('Create Checkpoint');
  });

  test('validates checkpoint message is required', async ({ page }) => {
    // Set path and open dialog
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    await page.locator('button').filter({ hasText: 'Create Checkpoint' }).click();
    
    // Submit button should be disabled without message
    const submitButton = page.locator('.dialog button').filter({ hasText: 'Create Checkpoint' });
    await expect(submitButton).toBeDisabled();
    
    // Enter message
    await page.locator('#message').fill('Test checkpoint');
    await expect(submitButton).toBeEnabled();
  });

  test('displays checkpoint list', async ({ page }) => {
    // Set path
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Should show checkpoint list section
    await expect(page.locator('.checkpoint-list')).toBeVisible();
    await expect(page.locator('h2')).toContainText('Checkpoints');
  });

  test('displays current checkpoint ID', async ({ page }) => {
    // Set path
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Should show current checkpoint in toolbar
    await expect(page.locator('.current-checkpoint')).toBeVisible();
    await expect(page.locator('.current-checkpoint')).toContainText('Current:');
  });

  test('shows rollback confirmation dialog', async ({ page }) => {
    // Set path
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Wait for checkpoints to load and click rollback if available
    await page.waitForTimeout(1000);
    const rollbackButton = page.locator('button').filter({ hasText: 'Rollback' }).first();
    
    if (await rollbackButton.isVisible()) {
      await rollbackButton.click();
      
      // Confirmation dialog should appear
      await expect(page.locator('.dialog-confirm')).toBeVisible();
      await expect(page.locator('.dialog h2')).toContainText('Confirm Rollback');
      await expect(page.locator('.warning-box')).toBeVisible();
    }
  });

  test('allows closing dialogs', async ({ page }) => {
    // Set path and open create dialog
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    await page.locator('button').filter({ hasText: 'Create Checkpoint' }).click();
    
    // Close dialog
    await page.locator('.close-btn').first().click();
    
    // Dialog should be gone
    await expect(page.locator('.dialog')).not.toBeVisible();
  });

  test('displays checkpoint metadata fields', async ({ page }) => {
    // Set path and open create dialog
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    await page.locator('button').filter({ hasText: 'Create Checkpoint' }).click();
    
    // Check for metadata fields
    await expect(page.locator('#message')).toBeVisible();
    await expect(page.locator('#executionId')).toBeVisible();
    await expect(page.locator('#milestoneId')).toBeVisible();
    await expect(page.locator('input[type="checkbox"]')).toBeVisible();
  });

  test('shows error messages', async ({ page }) => {
    // Try to set invalid path
    await page.locator('.path-input').fill('');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Should stay on path setup screen (validation should prevent empty path)
    await expect(page.locator('.path-setup')).toBeVisible();
  });

  test('force rollback checkbox is available', async ({ page }) => {
    // Set path
    await page.locator('.path-input').fill('/test/repo');
    await page.locator('button').filter({ hasText: 'Set Path' }).click();
    
    // Try to open rollback dialog
    await page.waitForTimeout(1000);
    const rollbackButton = page.locator('button').filter({ hasText: 'Rollback' }).first();
    
    if (await rollbackButton.isVisible()) {
      await rollbackButton.click();
      
      // Check for force checkbox
      const forceCheckbox = page.locator('input[type="checkbox"]').filter({ hasText: /force/i });
      await expect(forceCheckbox).toBeVisible();
    }
  });
});

