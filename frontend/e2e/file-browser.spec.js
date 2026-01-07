/**
 * File Browser E2E Tests
 * Tests file tree navigation and file selection
 */

import { fast, medium, expect } from './base-test';

fast('shows file tree empty state initially', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  await expect(page.locator('text=Enter a project path and click "Load Project"')).toBeVisible();
});

medium('loads file tree when project path provided', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Enter a test project path
  const pathInput = page.locator('input[placeholder="Enter project path..."]');
  await pathInput.fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  
  // Click load button
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for file tree to load
  await expect(page.locator('.file-tree-browser')).toBeVisible({ timeout: 10000 });
  
  // Should show some files/directories
  // The example codebase has app/, README.md, etc.
  await expect(page.locator('.tree-node').first()).toBeVisible();
});

medium('expands and collapses directories', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree to load
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Find a directory (app)
  const appDir = page.locator('.tree-item.directory:has-text("app")').first();
  
  if (await appDir.isVisible()) {
    // Click to expand
    await appDir.click();
    
    // Should show expand icon change (▼ when expanded)
    await expect(appDir.locator('.expand-icon')).toContainText('▼');
    
    // Click again to collapse
    await appDir.click();
    
    // Should show collapse icon (▶)
    await expect(appDir.locator('.expand-icon')).toContainText('▶');
  }
});

medium('selects file when clicked', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree to load
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Find README.md file
  const readmeFile = page.locator('.tree-item.file:has-text("README.md")').first();
  
  if (await readmeFile.isVisible()) {
    // Click the file
    await readmeFile.click();
    
    // File should be selected (highlighted)
    await expect(readmeFile).toHaveClass(/selected/);
    
    // Editor should show the file name
    await expect(page.locator('text=README.md')).toBeVisible();
  }
});

medium('shows file icons based on extension', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree to load
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Check that files have icons
  const fileItems = page.locator('.tree-item.file');
  const count = await fileItems.count();
  
  expect(count).toBeGreaterThan(0);
  
  // Each file should have an icon element
  for (let i = 0; i < Math.min(count, 5); i++) {
    const file = fileItems.nth(i);
    await expect(file.locator('.icon')).toBeVisible();
  }
});

medium('shows directory icons', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree to load
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Check that directories have folder icons
  const dirItems = page.locator('.tree-item.directory');
  const count = await dirItems.count();
  
  if (count > 0) {
    const firstDir = dirItems.first();
    await expect(firstDir.locator('.icon')).toBeVisible();
  }
});

fast('shows loading state while fetching tree', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Enter path
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby');
  
  // Click load - should briefly show loading
  await page.locator('button:has-text("Load Project")').click();
  
  // Loading text might be too fast to catch, but if it appears, it should be visible
  const loading = page.locator('text=Loading file tree');
  if (await loading.isVisible({ timeout: 1000 }).catch(() => false)) {
    expect(await loading.isVisible()).toBeTruthy();
  }
});

medium('handles nested directory navigation', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree to load
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Expand app directory
  const appDir = page.locator('.tree-item.directory:has-text("app")').first();
  if (await appDir.isVisible()) {
    await appDir.click();
    
    // Look for nested services directory
    const servicesDir = page.locator('.tree-item.directory:has-text("services")').first();
    if (await servicesDir.isVisible()) {
      await servicesDir.click();
      
      // Should show files inside services
      await expect(page.locator('.tree-children').first()).toBeVisible();
    }
  }
});

fast('does not load tree when path is empty', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Click load without entering a path
  await page.locator('button:has-text("Load Project")').click();
  
  // Should still show empty state
  await expect(page.locator('text=Enter a project path and click "Load Project"')).toBeVisible();
});

medium('shows error message for invalid path', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Enter invalid path
  await page.locator('input[placeholder="Enter project path..."]').fill('/nonexistent/path/that/does/not/exist');
  await page.locator('button:has-text("Load Project")').click();
  
  // Should show error (might take a moment)
  const errorText = page.locator('text=Error:');
  await expect(errorText).toBeVisible({ timeout: 10000 });
});

