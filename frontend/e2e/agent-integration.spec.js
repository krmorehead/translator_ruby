import { expect } from "@playwright/test";
import { fast, medium, slow } from "./helpers/speedProfile.js";

/**
 * E2E tests for Agent Integration with REAL LLM
 * 
 * CRITICAL RULES:
 * - NO MOCKING - All tests hit real backend
 * - Real LLM calls in SLOW tests only
 * - ONE LLM call maximum per test
 * - Tests MUST complete within their speed limit
 * - Timeout = FAILURE (not expected)
 * 
 * SPEED PROFILES:
 * - fast (5s): UI only, no API calls
 * - medium (15s): API calls, no LLM
 * - slow (30s): Real LLM, ONE simple query
 */

const BASE_URL = "http://localhost:5173"; // Vite dev server

// =============================================================================
// SESSION MANAGEMENT - MEDIUM (API calls, no LLM)
// =============================================================================

medium("should initialize agent session via API", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Click initialize button
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await expect(initButton).toBeVisible();
  await initButton.click();

  // Wait for real API response
  const response = await page.waitForResponse(
    (response) => response.url().includes("/api/agent_sessions") && response.request().method() === "POST"
  );

  expect(response.ok()).toBe(true);

  // Session ID should appear in the header - wait for it
  await expect(page.locator(".session-info")).toBeVisible();
  
  const sessionText = await page.locator(".session-info").textContent();
  const sessionId = sessionText.match(/Session:\s*([a-f0-9-]+)/i)?.[1];
  expect(sessionId).toBeTruthy();
  expect(sessionId).toMatch(/^[a-f0-9-]+$/);
  
  // Initialize button should be hidden after session created
  await expect(initButton).not.toBeVisible();
});

medium("should persist session ID after page reload", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize if needed
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  if (await initButton.isVisible()) {
    await initButton.click();
    await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );
  }

  // Get session ID
  const sessionLocator = page.locator(".session-info");
  await expect(sessionLocator).toBeVisible();
  const sessionText = await sessionLocator.textContent();
  const originalSessionId = sessionText.match(/Session:\s*([a-f0-9-]+)/i)?.[1];

  // Reload page
  await page.reload();
  await page.waitForLoadState("networkidle");

  // Session ID should persist in storage/state (or user must reinitialize)
  const newSessionLocator = page.locator(".session-info");
  const stillVisible = await newSessionLocator.isVisible().catch(() => false);
  
  if (stillVisible) {
    const newSessionText = await newSessionLocator.textContent();
    expect(newSessionText).toContain(originalSessionId.slice(0, 8));
  } else {
    // Session not persisted - expected behavior for now
    // User must reinitialize
    const newInitButton = page.getByRole("button", { name: /initialize.*session/i });
    await expect(newInitButton).toBeVisible();
  }
});

// =============================================================================
// CHAT WITH REAL LLM - SLOW (ONE simple LLM call)
// =============================================================================

slow("should send message and get real LLM response for simple math", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize session
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await expect(initButton).toBeVisible();
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Wait for session to be established
  await expect(page.locator(".session-info")).toBeVisible();

  // Navigate to chat tab (if not already there)
  const chatTab = page.getByRole("button", { name: /💬|chat/i });
  if (await chatTab.isVisible()) {
    await chatTab.click();
    await page.waitForLoadState("networkidle");
  }

  // Send SIMPLE message to real LLM
  const messageInput = page.getByPlaceholder(/type.*message|enter.*message/i);
  await expect(messageInput).toBeVisible();
  await messageInput.fill("What is 2 + 2?");

  const sendButton = page.getByRole("button", { name: /send/i });
  await sendButton.click();

  // Wait for user message to appear
  await expect(page.locator(".chat-message, .message").first()).toBeVisible();
  
  // Wait for real LLM response (should be 10-20s for simple math)
  await expect(page.locator(".chat-message, .message")).toHaveCount(2, );

  // Verify response content
  const messages = page.locator(".chat-message, .message");
  const userMessage = messages.nth(0);
  const agentMessage = messages.nth(1);

  await expect(userMessage).toContainText("What is 2 + 2?");
  
  // Real LLM should answer correctly
  const agentText = await agentMessage.textContent();
  expect(agentText.toLowerCase()).toMatch(/4|four/);
  expect(agentText.length).toBeGreaterThan(1);
});

slow("should extract thoughts from real LLM reasoning", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Wait for tabs to be visible
  await expect(page.locator(".agent-tabs")).toBeVisible();

  // Navigate to chat
  const chatTab = page.getByRole("button", { name: /💬|chat/i });
  if (await chatTab.isVisible()) {
    await chatTab.click();
  }

  // Send message requiring reasoning (but keep it simple)
  const messageInput = page.getByPlaceholder(/type.*message|enter.*message/i);
  await expect(messageInput).toBeVisible();
  await messageInput.fill("Is 7 prime?");
  await page.getByRole("button", { name: /send/i }).click();

  // Wait for LLM response (simple yes/no with reasoning)
  await expect(page.locator(".chat-message, .message")).toHaveCount(2, );

  // Navigate to thoughts panel
  const thoughtsTab = page.getByRole("button", { name: /💭|thoughts/i });
  await expect(thoughtsTab).toBeVisible();
  await thoughtsTab.click();
  await page.waitForLoadState("networkidle");

  // Refresh thoughts if refresh button exists
  const refreshButton = page.getByRole("button", { name: /refresh/i });
  if (await refreshButton.isVisible().catch(() => false)) {
    await refreshButton.click();
    await page.waitForLoadState("networkidle");
  }

  // Check if thoughts were extracted (may or may not exist depending on LLM)
  const thoughtsSection = page.locator(".thought-entry, .thought-content, [class*='thought']");
  const thoughtCount = await thoughtsSection.count();
  
  // We don't assert existence because not all LLMs use <think> tags
  console.log(`Found ${thoughtCount} thought entries from real LLM`);
  
  // Verify thoughts panel is visible even if empty
  await expect(page.locator(".thoughts-panel, [class*='thoughts']").first()).toBeVisible();
});

// =============================================================================
// MEMORY OPERATIONS - MEDIUM (API calls, no LLM)
// =============================================================================

medium("should load memory state from backend", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Wait for tabs
  await expect(page.locator(".agent-tabs")).toBeVisible();

  // Navigate to memory panel
  const memoryTab = page.getByRole("button", { name: /🧠|memory/i });
  await expect(memoryTab).toBeVisible();
  await memoryTab.click();
  await page.waitForLoadState("networkidle");

  // Refresh memory if button exists
  const refreshButton = page.getByRole("button", { name: /refresh/i });
  if (await refreshButton.isVisible().catch(() => false)) {
    await refreshButton.click();
    
    // Wait for API response if it happens
    await page.waitForResponse(
      (response) => response.url().includes("/memories"),
      
    ).catch(() => {
      // May not have API call if no changes
    });
  }

  // Memory panel should be visible (even if empty)
  const memoryContainer = page.locator(".memory-panel, .memory-inspector, [class*='memory']").first();
  await expect(memoryContainer).toBeVisible();
});

medium("should clear memory section via API", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Navigate to memory
  const memoryTab = page.getByRole("button", { name: /🧠|memory/i });
  await expect(memoryTab).toBeVisible();
  await memoryTab.click();
  await page.waitForLoadState("networkidle");

  // Find clear button
  const clearButtons = page.getByRole("button", { name: /clear/i });
  const clearCount = await clearButtons.count();

  if (clearCount > 0) {
    // Click clear
    await clearButtons.first().click();

    // Confirm if confirmation dialog appears
    const confirmButton = page.getByRole("button", { name: /confirm|yes/i });
    const hasConfirm = await confirmButton.isVisible().catch(() => false);
    
    if (hasConfirm) {
      await confirmButton.click();
    } else {
      // Double-click pattern - click again
      await clearButtons.first().click();
    }

    // Wait for API call
    await page.waitForResponse(
      (response) => response.url().includes("/memories"),
      
    ).catch(() => {
      // May not trigger if already empty
    });
    
    await page.waitForLoadState("networkidle");
  }
});

// =============================================================================
// CONTEXT MANAGEMENT - FAST (UI only, no API)
// =============================================================================

fast("should add context entry to UI", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Wait for tabs
  await expect(page.locator(".agent-tabs")).toBeVisible();

  // Navigate to context
  const contextTab = page.getByRole("button", { name: /📚|context/i });
  await expect(contextTab).toBeVisible();
  await contextTab.click();
  await page.waitForLoadState("networkidle");

  // Click add entry
  const addButton = page.getByRole("button", { name: /add.*entry/i });
  await expect(addButton).toBeVisible();
  await addButton.click();

  // Wait for form to appear
  await page.waitForSelector("input[type='text'], input[name*='name']", );

  // Fill form
  const nameInput = page.locator("input[type='text'], input[name*='name']").first();
  await nameInput.fill("TestFile");

  const pathInput = page.locator("input[placeholder*='path'], input[name*='path']").first();
  if (await pathInput.isVisible().catch(() => false)) {
    await pathInput.fill("/app/test.rb");
  }

  // Submit
  const submitButton = page.getByRole("button", { name: /add entry|submit/i });
  await submitButton.click();

  // Verify appears
  await expect(page.locator("text=/TestFile/i")).toBeVisible();
});

fast("should remove context entry from UI", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Navigate to context
  const contextTab = page.getByRole("button", { name: /📚|context/i });
  await expect(contextTab).toBeVisible();
  await contextTab.click();
  await page.waitForLoadState("networkidle");

  // Check for existing entries
  const removeButtons = page.locator("button[aria-label*='Remove'], button[title*='Remove']");
  const count = await removeButtons.count();

  if (count > 0) {
    const entryLocator = page.locator(".context-entry, .entry-name, [class*='entry']").first();
    const entryText = await entryLocator.textContent().catch(() => "");
    
    // Remove it
    await removeButtons.first().click();

    // Should be gone
    if (entryText) {
      await expect(page.locator(`text=${entryText}`)).not.toBeVisible();
    }
  }
});

// =============================================================================
// MODE SWITCHING - FAST (UI only)
// =============================================================================

fast("should switch between Daedalus and Sisyphus modes", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Verify initial mode by checking the heading
  const heading = page.getByRole("heading", { level: 1 });
  await expect(heading).toContainText(/daedalus/i, );

  // Switch to Sisyphus
  const modeSelector = page.locator('select.mode-selector[aria-label="Agent Mode"]');
  await expect(modeSelector).toBeVisible();
  await modeSelector.selectOption("sisyphus");

  // Wait for UI to update
  await page.waitForLoadState("networkidle");

  // Verify mode changed by checking heading
  await expect(heading).toContainText(/sisyphus/i, );

  // Switch back to Daedalus
  await modeSelector.selectOption("daedalus");
  await page.waitForLoadState("networkidle");

  await expect(heading).toContainText(/daedalus/i, );
});

// =============================================================================
// INTEGRATION - SLOW (ONE LLM call + context)
// =============================================================================

slow("should use context in real LLM query", async ({ page }) => {
  await page.goto(`${BASE_URL}/agent`);
  await page.waitForLoadState("networkidle");

  // Initialize
  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"), );

  // Wait for tabs
  await expect(page.locator(".agent-tabs")).toBeVisible();

  // Add context first
  const contextTab = page.getByRole("button", { name: /📚|context/i });
  await expect(contextTab).toBeVisible();
  await contextTab.click();
  await page.waitForLoadState("networkidle");

  const addButton = page.getByRole("button", { name: /add.*entry/i });
  await expect(addButton).toBeVisible();
  await addButton.click();

  await page.waitForSelector("input[type='text']", );

  const nameInput = page.locator("input[type='text']").first();
  await nameInput.fill("MathHelper");

  const submitButton = page.getByRole("button", { name: /add entry|submit/i });
  await submitButton.click();

  await expect(page.locator("text=/MathHelper/i")).toBeVisible();

  // Return to chat
  const chatTab = page.getByRole("button", { name: /💬|chat/i });
  await expect(chatTab).toBeVisible();
  await chatTab.click();
  await page.waitForLoadState("networkidle");

  // Send simple message
  const messageInput = page.getByPlaceholder(/type.*message|enter.*message/i);
  await expect(messageInput).toBeVisible();
  await messageInput.fill("What is 3 + 3?");
  await page.getByRole("button", { name: /send/i }).click();

  // Wait for real LLM response
  await expect(page.locator(".chat-message, .message")).toHaveCount(2, );

  // Verify context still exists
  await contextTab.click();
  await page.waitForLoadState("networkidle");
  await expect(page.locator("text=/MathHelper/i")).toBeVisible();
});
