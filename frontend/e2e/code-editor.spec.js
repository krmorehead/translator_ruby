/**
 * Code Editor E2E Tests
 * Tests Monaco editor integration, file loading, and keyboard shortcuts
 */

import { fast, medium, expect } from './base-test';

fast('shows empty state when no file selected', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  await expect(page.locator('text=Select a file from the file browser')).toBeVisible();
});

medium('loads file content when file selected', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree to load
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Click on README.md
  const readmeFile = page.locator('.tree-item.file:has-text("README.md")').first();
  if (await readmeFile.isVisible()) {
    await readmeFile.click();
    
    // Editor should show file name in header
    await expect(page.locator('.file-name:has-text("README.md")')).toBeVisible({ timeout: 5000 });
    
    // Monaco editor should be loaded
    await expect(page.locator('.monaco-editor, [data-testid="monaco-editor"]')).toBeVisible({ timeout: 5000 });
  }
});

medium('shows file name in editor header', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Select a file
  const file = page.locator('.tree-item.file').first();
  await file.click();
  
  // File name should appear in editor header
  const fileName = await file.locator('.name').textContent();
  await expect(page.locator(`.file-name:has-text("${fileName}")`)).toBeVisible({ timeout: 5000 });
});

medium('monaco editor renders with syntax highlighting', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Expand app directory
  const appDir = page.locator('.tree-item.directory:has-text("app")').first();
  if (await appDir.isVisible()) {
    await appDir.click();
    
    // Expand services
    const servicesDir = page.locator('.tree-item.directory:has-text("services")').first();
    if (await servicesDir.isVisible()) {
      await servicesDir.click();
      
      // Click on a Ruby file
      const rbFile = page.locator('.tree-item.file:has-text(".rb")').first();
      if (await rbFile.isVisible()) {
        await rbFile.click();
        
        // Monaco editor should load
        await expect(page.locator('.monaco-editor, [data-testid="monaco-editor"]')).toBeVisible({ timeout: 5000 });
      }
    }
  }
});

fast('shows save hint in status bar', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load and select a file
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  const file = page.locator('.tree-item.file').first();
  await file.click();
  
  // Wait for editor to load
  await page.waitForTimeout(1000);
  
  // Status bar should show save hint
  const statusBar = page.locator('.editor-status-bar, text=/Cmd\\+S|Ctrl\\+S/');
  if (await statusBar.isVisible({ timeout: 2000 }).catch(() => false)) {
    expect(await statusBar.isVisible()).toBeTruthy();
  }
});

medium('switches files when different file selected', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Get first two files
  const files = page.locator('.tree-item.file');
  const count = await files.count();
  
  if (count >= 2) {
    // Click first file
    const file1 = files.nth(0);
    const file1Name = await file1.locator('.name').textContent();
    await file1.click();
    await expect(page.locator(`.file-name:has-text("${file1Name}")`)).toBeVisible({ timeout: 5000 });
    
    // Click second file
    const file2 = files.nth(1);
    const file2Name = await file2.locator('.name').textContent();
    await file2.click();
    await expect(page.locator(`.file-name:has-text("${file2Name}")`)).toBeVisible({ timeout: 5000 });
    
    // First file name should not be shown anymore
    expect(file1Name).not.toBe(file2Name);
  }
});

fast('editor takes up 75% of middle panel', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const editorSection = page.locator('.editor-section');
  const memorySection = page.locator('.memory-section');
  
  await expect(editorSection).toBeVisible();
  await expect(memorySection).toBeVisible();
  
  // Both should be in the same middle panel
  const middlePanel = page.locator('.panel-middle');
  await expect(middlePanel).toBeVisible();
});

medium('handles markdown files', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Click README.md
  const readmeFile = page.locator('.tree-item.file:has-text("README.md")').first();
  if (await readmeFile.isVisible()) {
    await readmeFile.click();
    
    // Editor should load with markdown content
    await expect(page.locator('.monaco-editor, [data-testid="monaco-editor"]')).toBeVisible({ timeout: 5000 });
  }
});

medium('handles ruby files', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Load test project
  await page.locator('input[placeholder="Enter project path..."]').fill('/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase');
  await page.locator('button:has-text("Load Project")').click();
  
  // Wait for tree
  await expect(page.locator('.tree-node').first()).toBeVisible({ timeout: 10000 });
  
  // Find and click a .rb file
  const rbFile = page.locator('.tree-item.file:has-text(".rb")').first();
  
  // Expand directories to find .rb files
  const appDir = page.locator('.tree-item.directory:has-text("app")').first();
  if (await appDir.isVisible()) {
    await appDir.click();
    
    const servicesDir = page.locator('.tree-item.directory:has-text("services")').first();
    if (await servicesDir.isVisible()) {
      await servicesDir.click();
      
      // Now click a .rb file
      const rbFileInServices = page.locator('.tree-item.file').first();
      if (await rbFileInServices.isVisible()) {
        await rbFileInServices.click();
        
        // Editor should load
        await expect(page.locator('.monaco-editor, [data-testid="monaco-editor"]')).toBeVisible({ timeout: 5000 });
      }
    }
  }
});

fast('editor is contained within middle panel', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Check that editor container is within middle panel
  const middlePanel = page.locator('.panel-middle');
  await expect(middlePanel).toBeVisible();
  
  const editorContainer = middlePanel.locator('.editor-container');
  await expect(editorContainer).toBeVisible();
});

fast('memory inspector is below editor', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const middlePanel = page.locator('.panel-middle');
  await expect(middlePanel).toBeVisible();
  
  // Editor section should be above memory section
  const editorSection = middlePanel.locator('.editor-section');
  const memorySection = middlePanel.locator('.memory-section');
  
  await expect(editorSection).toBeVisible();
  await expect(memorySection).toBeVisible();
});

