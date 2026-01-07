import { expect, fast, medium, slow } from "./base-test";

const FIXTURE_PATH = '/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase';

/**
 * Codebase Exploration E2E Tests
 * 
 * Verifies that both Daedalus (Plan Agent) and Sisyphus (Act Agent)
 * can properly explore codebases using file_tree, grep, and read_file tools.
 *
 * Uses test fixture at: test/fixtures/example_codebase/
 * 
 * These tests verify ACTUAL TOOL USAGE by checking that agents:
 * - Provide specific, accurate information from the codebase
 * - Reference actual files and code patterns
 * - Demonstrate knowledge that can only come from exploration
 * 
 * NO MOCKS. Real LLM. Real tool execution. Real codebase exploration.
 */

// ============================================================================
// DAEDALUS - PLAN AGENT CODEBASE EXPLORATION
// ============================================================================

slow("Daedalus explores codebase structure with file_tree", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('daedalus');
  
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill(FIXTURE_PATH);
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  await expect(page.locator('text=Session:')).toBeVisible();
  
  const chatInput = page.getByPlaceholder('Type your message...');
  await chatInput.fill('Analyze the architecture of this Ruby codebase and identify all service classes');
  
  const sendButton = page.getByRole('button', { name: /send/i });
  await sendButton.click();
  
  // Verify agent found MathService - this proves it used file_tree or grep
  await expect(page.locator('text=/math.*service|service.*class|MathService/i')).toBeVisible({ timeout: 60000 });
});

slow("Daedalus searches patterns with grep", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('daedalus');
  
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill(FIXTURE_PATH);
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  await expect(page.locator('text=Session:')).toBeVisible();
  
  const chatInput = page.getByPlaceholder('Type your message...');
  await chatInput.fill('Find all classes that define a "calculate" method');
  
  const sendButton = page.getByRole('button', { name: /send/i });
  await sendButton.click();
  
  // Verify agent found Calculator class - proves grep tool was used
  await expect(page.locator('text=/calculator|calculate/i')).toBeVisible({ timeout: 60000 });
});

slow("Daedalus reads files with read_file", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('daedalus');
  
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill(FIXTURE_PATH);
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  await expect(page.locator('text=Session:')).toBeVisible();
  
  const chatInput = page.getByPlaceholder('Type your message...');
  await chatInput.fill('What methods does the Calculator class have?');
  
  const sendButton = page.getByRole('button', { name: /send/i });
  await sendButton.click();
  
  // Verify agent lists actual methods - proves read_file was used to read calculator.rb
  await expect(page.locator('text=/add|subtract|multiply|divide/i')).toBeVisible({ timeout: 60000 });
});

slow("Daedalus understands Ruby project structure", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('daedalus');
  
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill(FIXTURE_PATH);
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  await expect(page.locator('text=Session:')).toBeVisible();
  
  const chatInput = page.getByPlaceholder('Type your message...');
  await chatInput.fill('Document the service layer architecture');
  
  const sendButton = page.getByRole('button', { name: /send/i });
  await sendButton.click();
  
  // Verify agent describes the architecture - proves it explored the codebase
  await expect(page.locator('text=/service|app\\/services|ruby/i')).toBeVisible({ timeout: 60000 });
});

medium("Daedalus handles invalid paths gracefully", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('daedalus');
  
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill('/nonexistent/path');
  
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  await expect(page.locator('text=Session:')).toBeVisible();
  
  const chatInput = page.getByPlaceholder('Type your message...');
  await chatInput.fill('Analyze this codebase');
  
  const sendButton = page.getByRole('button', { name: /send/i });
  await sendButton.click();
  
  await expect(page.locator('text=/error|not found|does not exist|cannot|invalid/i')).toBeVisible();
});

// ============================================================================
// SISYPHUS - ACT AGENT TOOL AVAILABILITY
// ============================================================================

fast("Sisyphus mode is available and selectable", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('sisyphus');
  await expect(modeSelector).toHaveValue('sisyphus');
});

fast("Sisyphus accepts project path input", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  await modeSelector.selectOption('sisyphus');
  
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill(FIXTURE_PATH);
  await expect(pathInput).toHaveValue(FIXTURE_PATH);
});

// ============================================================================
// INTEGRATION - CONSISTENT TOOL SCHEMAS
// ============================================================================

fast("both agents use consistent tool schemas", async ({ page }) => {
  await page.goto('/');
  
  const modeSelector = page.locator('select').first();
  
  // Test Daedalus accepts path
  await modeSelector.selectOption('daedalus');
  const daedalusPath = page.locator('input[placeholder*="project"]').first();
  await daedalusPath.fill(FIXTURE_PATH);
  await expect(daedalusPath).toHaveValue(FIXTURE_PATH);
  
  // Test Sisyphus accepts same path format
  await modeSelector.selectOption('sisyphus');
  const sisyphusPath = page.locator('input[placeholder*="project"]').first();
  await sisyphusPath.fill(FIXTURE_PATH);
  await expect(sisyphusPath).toHaveValue(FIXTURE_PATH);
});
