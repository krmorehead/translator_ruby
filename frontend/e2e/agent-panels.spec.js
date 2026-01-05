import { expect, medium, slow } from "./base-test";

/**
 * Comprehensive Panel Tests
 * Tests all agent workspace panels (Chat, Thoughts, Memory, Context, Timeline)
 */

// =============================================================================
// THOUGHTS PANEL TESTS
// =============================================================================

medium("thoughts - displays thoughts panel UI", async ({ page }) => {
  console.log("\n🧪 Testing Thoughts Panel");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  // Click Thoughts tab
  const thoughtsTab = page.locator('button[aria-label="Thoughts"]');
  await thoughtsTab.click();
  
  // Check for thoughts panel elements
  await expect(page.locator('.thoughts-panel')).toBeVisible();
  await expect(page.locator('h3').filter({ hasText: /agent reasoning/i })).toBeVisible();
  
  // Check for controls
  await expect(page.locator('input[aria-label="Auto-refresh thoughts"]')).toBeVisible();
  await expect(page.locator('select[aria-label="Filter thoughts"]')).toBeVisible();
  await expect(page.locator('button[aria-label="Refresh thoughts"]')).toBeVisible();
  
  console.log("✓ Thoughts panel UI rendered");
});

medium("thoughts - auto-refresh toggle works", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Thoughts"]').click();
  
  // Auto-refresh should be checked by default
  const autoRefreshCheckbox = page.locator('input[aria-label="Auto-refresh thoughts"]');
  await expect(autoRefreshCheckbox).toBeChecked();
  
  // Toggle it off
  await autoRefreshCheckbox.uncheck();
  await expect(autoRefreshCheckbox).not.toBeChecked();
  
  console.log("✓ Auto-refresh toggle works");
});

medium("thoughts - filter dropdown works", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Thoughts"]').click();
  
  const filterSelect = page.locator('select[aria-label="Filter thoughts"]');
  await expect(filterSelect).toBeVisible();
  
  // Check options exist (don't check visibility, options are hidden in selects)
  const optionCount = await filterSelect.locator('option').count();
  expect(optionCount).toBeGreaterThanOrEqual(2);
  
  // Change filter
  await filterSelect.selectOption("recent");
  await expect(filterSelect).toHaveValue("recent");
  
  console.log("✓ Filter dropdown works");
});

// =============================================================================
// MEMORY INSPECTOR TESTS
// =============================================================================

medium("memory - displays memory inspector UI", async ({ page }) => {
  console.log("\n🧪 Testing Memory Inspector");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  // Click Memory tab
  const memoryTab = page.locator('button[aria-label="Memory"]');
  await memoryTab.click();
  
  // Check for memory inspector elements
  await expect(page.locator('.memory-inspector')).toBeVisible();
  await expect(page.locator('h3').filter({ hasText: /memory inspector/i })).toBeVisible();
  await expect(page.locator('button[aria-label="Refresh memory"]')).toBeVisible();
  
  console.log("✓ Memory inspector UI rendered");
});

medium("memory - shows empty state initially", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Memory"]').click();
  
  // Should show empty state
  await expect(page.locator('.memory-empty-state')).toBeVisible();
  await expect(page.locator('text=/no memory sections/i')).toBeVisible();
  
  console.log("✓ Memory empty state shown");
});

medium("memory - refresh button works", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Memory"]').click();
  
  const refreshBtn = page.locator('button[aria-label="Refresh memory"]');
  await expect(refreshBtn).toBeVisible();
  await expect(refreshBtn).toBeEnabled();
  
  // Click refresh
  await refreshBtn.click();
  
  console.log("✓ Memory refresh button works");
});

// =============================================================================
// CONTEXT MANAGER TESTS
// =============================================================================

medium("context - displays context manager UI", async ({ page }) => {
  console.log("\n🧪 Testing Context Manager");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  // Click Context tab
  const contextTab = page.locator('button[aria-label="Context"]');
  await contextTab.click();
  
  // Check for context manager elements
  await expect(page.locator('.context-manager')).toBeVisible();
  await expect(page.locator('h3').filter({ hasText: /context manager/i })).toBeVisible();
  await expect(page.locator('button[aria-label="Add context entry"]')).toBeVisible();
  
  console.log("✓ Context manager UI rendered");
});

medium("context - add entry form appears on button click", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Context"]').click();
  
  // Click add button
  const addBtn = page.locator('button[aria-label="Add context entry"]');
  await addBtn.click();
  
  // Form should appear
  await expect(page.locator('.add-entry-form')).toBeVisible();
  await expect(page.locator('input[placeholder*="UserService"]')).toBeVisible();
  
  console.log("✓ Add entry form appears");
});

medium("context - can add context entry", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Context"]').click();
  
  // Open form
  await page.locator('button[aria-label="Add context entry"]').click();
  
  // Fill form
  await page.locator('input[placeholder*="UserService"]').fill("TestService");
  await page.locator('input[placeholder*="/app/services"]').fill("/app/services/test_service.rb");
  
  // Submit
  await page.locator('button[type="submit"]').filter({ hasText: /add entry/i }).click();
  
  // Entry should appear
  await expect(page.locator('.context-entry').filter({ hasText: /TestService/i })).toBeVisible();
  
  console.log("✓ Can add context entry");
});

medium("context - shows entry count", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Context"]').click();
  
  // Add an entry
  await page.locator('button[aria-label="Add context entry"]').click();
  await page.locator('input[placeholder*="UserService"]').fill("TestService");
  await page.locator('button[type="submit"]').filter({ hasText: /add entry/i }).click();
  
  // Should show stats
  await expect(page.locator('.context-stats')).toBeVisible();
  await expect(page.locator('text=/1 entries/i')).toBeVisible();
  
  console.log("✓ Shows entry count");
});

// =============================================================================
// TIMELINE VIEW TESTS
// =============================================================================

medium("timeline - displays timeline view UI", async ({ page }) => {
  console.log("\n🧪 Testing Timeline View");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  // Click Timeline tab
  const timelineTab = page.locator('button[aria-label="Timeline"]');
  await timelineTab.click();
  
  // Check for timeline elements
  await expect(page.locator('.timeline-view')).toBeVisible();
  await expect(page.locator('h3').filter({ hasText: /action timeline/i })).toBeVisible();
  await expect(page.locator('select[aria-label="Filter actions"]')).toBeVisible();
  
  console.log("✓ Timeline view UI rendered");
});

medium("timeline - filter dropdown has options", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Timeline"]').click();
  
  const filterSelect = page.locator('select[aria-label="Filter actions"]');
  await expect(filterSelect).toBeVisible();
  
  // Check options exist (count them, don't check visibility)
  const optionCount = await filterSelect.locator('option').count();
  expect(optionCount).toBeGreaterThanOrEqual(4); // all, tools, decisions, errors
  
  // Try selecting different filters
  await filterSelect.selectOption("tools");
  await expect(filterSelect).toHaveValue("tools");
  
  console.log("✓ Timeline filter has all options");
});

medium("timeline - shows empty state initially", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  await page.locator('button[aria-label="Timeline"]').click();
  
  // Should show empty state
  await expect(page.locator('.timeline-empty-state')).toBeVisible();
  await expect(page.locator('text=/no actions recorded/i')).toBeVisible();
  
  console.log("✓ Timeline empty state shown");
});

// =============================================================================
// PANEL INTEGRATION TESTS
// =============================================================================

slow("panels - can send message and check all panels", async ({ page }) => {
  console.log("\n🧪 Testing Panel Integration with Real LLM");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  // Send a message
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  const sendBtn = page.locator('button.chat-send-button, .chat-send-button').first();
  
  await messageInput.fill("What is Ruby?");
  await sendBtn.click();
  
  // Wait for response
  await expect(page.locator('.chat-message, .message').first()).toBeVisible();
  console.log("✓ Message sent and response received");
  
  // Check Thoughts tab
  await page.locator('button[aria-label="Thoughts"]').click();
  await expect(page.locator('.thoughts-panel')).toBeVisible();
  console.log("✓ Thoughts panel accessible");
  
  // Check Memory tab
  await page.locator('button[aria-label="Memory"]').click();
  await expect(page.locator('.memory-inspector')).toBeVisible();
  console.log("✓ Memory inspector accessible");
  
  // Check Context tab
  await page.locator('button[aria-label="Context"]').click();
  await expect(page.locator('.context-manager')).toBeVisible();
  console.log("✓ Context manager accessible");
  
  // Check Timeline tab
  await page.locator('button[aria-label="Timeline"]').click();
  await expect(page.locator('.timeline-view')).toBeVisible();
  console.log("✓ Timeline view accessible");
  
  // Go back to Chat
  await page.locator('button[aria-label="Chat"]').click();
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Can navigate back to chat");
  
  // Verify message still there
  const messageCount = await page.locator('.chat-message, .message').count();
  expect(messageCount).toBeGreaterThanOrEqual(2);
  console.log(`✓ Message history preserved (${messageCount} messages)`);
});

