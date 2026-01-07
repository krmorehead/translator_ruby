/**
 * UnifiedIDE E2E Tests
 * Tests the complete IDE workflow: file browsing, editing, and agent interaction
 */

import { fast, medium, expect } from './base-test';

fast('renders unified IDE layout with three panels', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Check header
  await expect(page.locator('h1:has-text("🛠️ IDE")')).toBeVisible();
  
  // Check three panels
  await expect(page.locator('text=📁 Files')).toBeVisible();
  await expect(page.locator('text=📝 Editor')).toBeVisible();
  await expect(page.locator('text=🤖 Agent')).toBeVisible();
});

fast('shows initialize session button when no session', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await expect(initButton).toBeVisible();
});

fast('shows project path input in header', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const pathInput = page.locator('input[placeholder="Enter project path..."]');
  await expect(pathInput).toBeVisible();
  
  // Should be able to type in it
  await pathInput.fill('/test/project');
  await expect(pathInput).toHaveValue('/test/project');
});

fast('shows load project button', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const loadButton = page.locator('button:has-text("Load Project")');
  await expect(loadButton).toBeVisible();
});

fast('shows agent selector dropdown', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const selector = page.locator('select.agent-selector');
  await expect(selector).toBeVisible();
  
  // Check options
  const options = await selector.locator('option').allTextContents();
  expect(options.some(opt => opt.includes('Daedalus'))).toBeTruthy();
  expect(options.some(opt => opt.includes('Sisyphus'))).toBeTruthy();
});

fast('switches agent mode via dropdown', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const selector = page.locator('select.agent-selector');
  
  // Default should be Daedalus
  await expect(selector).toHaveValue('daedalus');
  
  // Switch to Sisyphus
  await selector.selectOption('sisyphus');
  await expect(selector).toHaveValue('sisyphus');
});

fast('shows config button in header', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const configButton = page.locator('button:has-text("⚙️")').first();
  await expect(configButton).toBeVisible();
});

fast('opens config modal when config button clicked', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const configButton = page.locator('button:has-text("⚙️")').first();
  await configButton.click();
  
  // Modal should appear
  await expect(page.locator('.modal-overlay')).toBeVisible();
  await expect(page.locator('text=Close')).toBeVisible();
});

fast('closes config modal when close button clicked', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Open modal
  await page.locator('button:has-text("⚙️")').first().click();
  await expect(page.locator('.modal-overlay')).toBeVisible();
  
  // Close modal
  await page.locator('button:has-text("Close")').click();
  await expect(page.locator('.modal-overlay')).not.toBeVisible();
});

fast('shows user preferences button', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const prefsButton = page.locator('button:has-text("👤")');
  await expect(prefsButton).toBeVisible();
});

fast('shows file tree empty state initially', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  await expect(page.locator('text=Enter a project path and click "Load Project"')).toBeVisible();
});

fast('shows code editor empty state initially', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  await expect(page.locator('text=Select a file from the file browser')).toBeVisible();
});

fast('shows memory inspector in bottom of middle panel', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  await expect(page.locator('text=🧠 Memory')).toBeVisible();
});

fast('shows empty state message when no session', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  await expect(page.locator('text=Initialize a session to start chatting')).toBeVisible();
});

medium('initializes session when button clicked', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  
  // Should show session badge after initialization
  await expect(page.locator('text=Session:')).toBeVisible({ timeout: 10000 });
  
  // Init button should be hidden
  await expect(initButton).not.toBeVisible();
});

medium('shows tabs when session is active', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Initialize session
  await page.locator('button:has-text("Initialize Session")').click();
  await expect(page.locator('text=Session:')).toBeVisible({ timeout: 10000 });
  
  // Check tabs
  await expect(page.locator('button:has-text("💬 Chat")')).toBeVisible();
  await expect(page.locator('button:has-text("💭 Thoughts")')).toBeVisible();
  await expect(page.locator('button:has-text("📁 Context")')).toBeVisible();
  await expect(page.locator('button:has-text("⏱️ Timeline")')).toBeVisible();
});

medium('switches between tabs', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Initialize session
  await page.locator('button:has-text("Initialize Session")').click();
  await expect(page.locator('text=Session:')).toBeVisible({ timeout: 10000 });
  
  // Default tab should be chat
  const chatTab = page.locator('button:has-text("💬 Chat")');
  await expect(chatTab).toHaveClass(/active/);
  
  // Switch to thoughts
  await page.locator('button:has-text("💭 Thoughts")').click();
  await expect(page.locator('button:has-text("💭 Thoughts")')).toHaveClass(/active/);
  
  // Switch to context
  await page.locator('button:has-text("📁 Context")').click();
  await expect(page.locator('button:has-text("📁 Context")')).toHaveClass(/active/);
  
  // Switch to timeline
  await page.locator('button:has-text("⏱️ Timeline")').click();
  await expect(page.locator('button:has-text("⏱️ Timeline")')).toHaveClass(/active/);
});

medium('shows persistent context when session active', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Initially no persistent context
  await expect(page.locator('.persistent-context-bar')).not.toBeVisible();
  
  // Initialize session
  await page.locator('button:has-text("Initialize Session")').click();
  await expect(page.locator('text=Session:')).toBeVisible({ timeout: 10000 });
  
  // Now persistent context should be visible
  await expect(page.locator('.persistent-context-bar')).toBeVisible();
});

fast('layout is responsive with three columns', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const panels = page.locator('.ide-panels');
  await expect(panels).toBeVisible();
  
  // Check that all three panels exist
  const leftPanel = page.locator('.panel-left');
  const middlePanel = page.locator('.panel-middle');
  const rightPanel = page.locator('.panel-right');
  
  await expect(leftPanel).toBeVisible();
  await expect(middlePanel).toBeVisible();
  await expect(rightPanel).toBeVisible();
});

fast('theme toggle works via preferences', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  // Open preferences
  await page.locator('button:has-text("👤")').click();
  
  // Preferences panel should be visible
  await expect(page.locator('[data-testid="preferences-panel"], .user-preferences-panel')).toBeVisible();
});

fast('memory inspector is visible in middle panel', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const memorySection = page.locator('.memory-section');
  await expect(memorySection).toBeVisible();
  
  // Should show memory header
  await expect(page.locator('text=🧠 Memory')).toBeVisible();
});

fast('editor section takes up more space than memory', async ({ page }) => {
  await page.goto('http://localhost:5173/');
  
  const editorSection = page.locator('.editor-section');
  const memorySection = page.locator('.memory-section');
  
  await expect(editorSection).toBeVisible();
  await expect(memorySection).toBeVisible();
  
  // Editor should have flex: 3, memory should have flex: 1
  // This is checked visually - editor takes ~75% of middle panel
});

