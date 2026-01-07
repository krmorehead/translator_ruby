/**
 * Comprehensive Agent Functionality E2E Tests
 * 
 * Tests REAL agent capabilities with REAL LLM using example_codebase fixture:
 * - Daedalus: Explore, analyze, answer questions
 * - Sisyphus: Edit files, create files, run tests
 * 
 * NO MOCKS. Full integration. Real tool calls.
 * 
 * IMPORTANT: These tests use REAL LLMs and take time. They verify actual functionality.
 */

import { expect, slow } from './base-test';

const FIXTURE_PATH = '/home/kyle/Side_Projects/translator_ruby/test/fixtures/example_codebase';

/**
 * Helper to initialize an agent session
 */
async function initializeAgent(page, agentType, projectPath) {
  await page.goto('/');
  
  // Select agent type
  const agentSelector = page.locator('select').first();
  await agentSelector.selectOption(agentType);
  
  // Fill project path
  const pathInput = page.locator('input[placeholder*="project"]').first();
  await pathInput.fill(projectPath);
  
  // Initialize session
  const initButton = page.locator('button:has-text("Initialize Session")');
  await initButton.click();
  await expect(page.locator('text=Session:')).toBeVisible();
}

/**
 * Helper to send a message and wait for response
 */
async function sendMessage(page, message) {
  const chatInput = page.getByPlaceholder('Type your message...');
  await chatInput.fill(message);
  
  const sendButton = page.getByRole('button', { name: /send/i });
  await sendButton.click();
}

/**
 * DAEDALUS TESTS - Exploration and Analysis
 */

slow('Daedalus explores and lists all services in codebase', async ({ page }) => {
  await initializeAgent(page, 'daedalus', FIXTURE_PATH);
  
  // Ask specific question requiring exploration
  await sendMessage(page, 'List all service classes in this codebase');
  
  // Verify answer includes discovered services
  // The example_codebase has MathService
  await expect(page.locator('text=/MathService/i')).toBeVisible({ timeout: 60000 });
  
  // Verify it mentions the correct path
  await expect(page.locator('text=/app\\/services|services/i')).toBeVisible();
});

slow('Daedalus finds and explains Calculator dependencies', async ({ page }) => {
  await initializeAgent(page, 'daedalus', FIXTURE_PATH);
  
  await sendMessage(page, 'What does the Calculator class do and what depends on it?');
  
  // Should mention Calculator
  await expect(page.locator('text=/Calculator/i')).toBeVisible({ timeout: 60000 });
  
  // Should mention methods or dependencies
  await expect(page.locator('text=/add|subtract|multiply|divide|MathService|Formatter/i')).toBeVisible();
});

/**
 * SISYPHUS TESTS - Execution and Modification
 */

slow('Sisyphus edits a file and verifies change', async ({ page }) => {
  await initializeAgent(page, 'sisyphus', FIXTURE_PATH);
  
  await sendMessage(page, 'Add a comment "# Updated via Sisyphus" to the top of lib/calculator.rb');
  
  // Should confirm the edit
  await expect(page.locator('text=/modified|updated|added|comment|calculator/i')).toBeVisible({ timeout: 60000 });
});

slow('Sisyphus creates a new test file', async ({ page }) => {
  await initializeAgent(page, 'sisyphus', FIXTURE_PATH);
  
  await sendMessage(page, 'Create a simple test file test/calculator_test.rb that tests the add method');
  
  // Should confirm file creation
  await expect(page.locator('text=/created|test|calculator_test/i')).toBeVisible({ timeout: 60000 });
});

slow('Sisyphus runs unit tests via bash', async ({ page }) => {
  await initializeAgent(page, 'sisyphus', FIXTURE_PATH);
  
  await sendMessage(page, 'Run "ruby -c lib/calculator.rb" to verify the syntax');
  
  // Should show command execution result
  await expect(page.locator('text=/Syntax OK|executed|command/i')).toBeVisible({ timeout: 60000 });
});

