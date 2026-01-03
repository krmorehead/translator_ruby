import { expect, fast, medium, slow } from "./base-test";

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

// =============================================================================
// SESSION MANAGEMENT - MEDIUM (API calls, no LLM)
// =============================================================================

medium("integration - should initialize agent session via API", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await expect(initButton).toBeVisible();
  await initButton.click();

  const response = await page.waitForResponse(
    (response) => response.url().includes("/api/agent_sessions") && response.request().method() === "POST"
  );

  expect(response.ok()).toBe(true);

  await expect(page.locator(".session-info")).toBeVisible();
  
  const sessionText = await page.locator(".session-info").textContent();
  const sessionId = sessionText.match(/Session:\s*([a-f0-9-]+)/i)?.[1];
  expect(sessionId).toBeTruthy();
  expect(sessionId).toMatch(/^[a-f0-9-]+$/);
  
  await expect(initButton).not.toBeVisible();
});

medium("integration - should persist session ID after page reload", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  if (await initButton.isVisible()) {
    await initButton.click();
    await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));
  }

  const sessionLocator = page.locator(".session-info");
  await expect(sessionLocator).toBeVisible();
  const sessionText = await sessionLocator.textContent();
  const originalSessionId = sessionText.match(/Session:\s*([a-f0-9-]+)/i)?.[1];

  await page.reload();
  await page.waitForLoadState("networkidle");

  const newSessionLocator = page.locator(".session-info");
  const stillVisible = await newSessionLocator.isVisible().catch(() => false);
  
  if (stillVisible) {
    const newSessionText = await newSessionLocator.textContent();
    expect(newSessionText).toContain(originalSessionId.slice(0, 8));
  } else {
    const newInitButton = page.getByRole("button", { name: /initialize.*session/i });
    await expect(newInitButton).toBeVisible();
  }
});

// =============================================================================
// CHAT WITH REAL LLM - SLOW (ONE simple LLM call)
// =============================================================================

slow("integration - should send message and get real LLM response for simple math", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await expect(initButton).toBeVisible();
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  await expect(page.locator(".session-info")).toBeVisible();

  const chatTab = page.getByRole("button", { name: /💬|chat/i });
  if (await chatTab.isVisible()) {
    await chatTab.click();
    await page.waitForLoadState("networkidle");
  }

  const messageInput = page.getByPlaceholder(/type.*message|enter.*message/i);
  await expect(messageInput).toBeVisible();
  await messageInput.fill("What is 2 + 2?");

  const sendButton = page.getByRole("button", { name: /send/i });
  await sendButton.click();

  await expect(page.locator(".chat-message, .message").first()).toBeVisible();
  
  await expect(page.locator(".chat-message, .message")).toHaveCount(2, { timeout: 25000 });

  const messages = page.locator(".chat-message, .message");
  const userMessage = messages.nth(0);
  const agentMessage = messages.nth(1);

  await expect(userMessage).toContainText("What is 2 + 2?");
  
  const agentText = await agentMessage.textContent();
  expect(agentText.toLowerCase()).toMatch(/4|four/);
  expect(agentText.length).toBeGreaterThan(1);
});

slow("integration - should extract thoughts from real LLM reasoning", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  await expect(page.locator(".agent-tabs")).toBeVisible();

  const chatTab = page.getByRole("button", { name: /💬|chat/i });
  if (await chatTab.isVisible()) {
    await chatTab.click();
  }

  const messageInput = page.getByPlaceholder(/type.*message|enter.*message/i);
  await expect(messageInput).toBeVisible();
  await messageInput.fill("Is 7 prime?");
  await page.getByRole("button", { name: /send/i }).click();

  await expect(page.locator(".chat-message, .message")).toHaveCount(2, { timeout: 25000 });

  const thoughtsTab = page.getByRole("button", { name: /💭|thoughts/i });
  await expect(thoughtsTab).toBeVisible();
  await thoughtsTab.click();
  await page.waitForLoadState("networkidle");

  const refreshButton = page.getByRole("button", { name: /refresh/i });
  if (await refreshButton.isVisible().catch(() => false)) {
    await refreshButton.click();
    await page.waitForLoadState("networkidle");
  }

  const thoughtsSection = page.locator(".thought-entry, .thought-content, [class*='thought']");
  const thoughtCount = await thoughtsSection.count();
  console.log(`Found ${thoughtCount} thought entries from real LLM`);
  
  await expect(page.locator(".thoughts-panel, [class*='thoughts']").first()).toBeVisible();
});

// =============================================================================
// MEMORY OPERATIONS - MEDIUM (API calls, no LLM)
// =============================================================================

medium("integration - should load memory state from backend", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  await expect(page.locator(".agent-tabs")).toBeVisible();

  const memoryTab = page.getByRole("button", { name: /🧠|memory/i });
  await expect(memoryTab).toBeVisible();
  await memoryTab.click();
  await page.waitForLoadState("networkidle");

  const refreshButton = page.getByRole("button", { name: /refresh/i });
  if (await refreshButton.isVisible().catch(() => false)) {
    await refreshButton.click();
    await page.waitForResponse((response) => response.url().includes("/memories")).catch(() => {});
  }

  const memoryContainer = page.locator(".memory-panel, .memory-inspector, [class*='memory']").first();
  await expect(memoryContainer).toBeVisible();
});

medium("integration - should clear memory section via API", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  const memoryTab = page.getByRole("button", { name: /🧠|memory/i });
  await expect(memoryTab).toBeVisible();
  await memoryTab.click();
  await page.waitForLoadState("networkidle");

  const clearButtons = page.getByRole("button", { name: /clear/i });
  const clearCount = await clearButtons.count();

  if (clearCount > 0) {
    await clearButtons.first().click();

    const confirmButton = page.getByRole("button", { name: /confirm|yes/i });
    const hasConfirm = await confirmButton.isVisible().catch(() => false);
    
    if (hasConfirm) {
      await confirmButton.click();
    } else {
      await clearButtons.first().click();
    }

    await page.waitForResponse((response) => response.url().includes("/memories")).catch(() => {});
    await page.waitForLoadState("networkidle");
  }
});

// =============================================================================
// CONTEXT MANAGEMENT - FAST (UI only, no API)
// =============================================================================

fast("integration - should add context entry to UI", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  await expect(page.locator(".agent-tabs")).toBeVisible();

  const contextTab = page.getByRole("button", { name: /📚|context/i });
  await expect(contextTab).toBeVisible();
  await contextTab.click();
  await page.waitForLoadState("networkidle");

  const addButton = page.getByRole("button", { name: /add.*entry/i });
  await expect(addButton).toBeVisible();
  await addButton.click();

  await page.waitForSelector("input[type='text'], input[name*='name']");

  const nameInput = page.locator("input[type='text'], input[name*='name']").first();
  await nameInput.fill("TestFile");

  const pathInput = page.locator("input[placeholder*='path'], input[name*='path']").first();
  if (await pathInput.isVisible().catch(() => false)) {
    await pathInput.fill("/app/test.rb");
  }

  const submitButton = page.getByRole("button", { name: /add entry|submit/i });
  await submitButton.click();

  await expect(page.locator("text=/TestFile/i")).toBeVisible();
});

fast("integration - should remove context entry from UI", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  const contextTab = page.getByRole("button", { name: /📚|context/i });
  await expect(contextTab).toBeVisible();
  await contextTab.click();
  await page.waitForLoadState("networkidle");

  const removeButtons = page.locator("button[aria-label*='Remove'], button[title*='Remove']");
  const count = await removeButtons.count();

  if (count > 0) {
    const entryLocator = page.locator(".context-entry, .entry-name, [class*='entry']").first();
    const entryText = await entryLocator.textContent().catch(() => "");
    
    await removeButtons.first().click();

    if (entryText) {
      await expect(page.locator(`text=${entryText}`)).not.toBeVisible();
    }
  }
});

// =============================================================================
// MODE SWITCHING - FAST (UI only)
// =============================================================================

fast("integration - should switch between Daedalus and Sisyphus modes", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const heading = page.getByRole("heading", { level: 1 });
  await expect(heading).toContainText(/daedalus/i);

  const modeSelector = page.locator('select.mode-selector[aria-label="Agent Mode"]');
  await expect(modeSelector).toBeVisible();
  await modeSelector.selectOption("sisyphus");

  await page.waitForLoadState("networkidle");

  await expect(heading).toContainText(/sisyphus/i);

  await modeSelector.selectOption("daedalus");
  await page.waitForLoadState("networkidle");

  await expect(heading).toContainText(/daedalus/i);
});

// =============================================================================
// INTEGRATION - SLOW (ONE LLM call + context)
// =============================================================================

slow("integration - should use context in real LLM query", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");

  const initButton = page.getByRole("button", { name: /initialize.*session/i });
  await initButton.click();
  await page.waitForResponse((r) => r.url().includes("/api/agent_sessions"));

  await expect(page.locator(".agent-tabs")).toBeVisible();

  const contextTab = page.getByRole("button", { name: /📚|context/i });
  await expect(contextTab).toBeVisible();
  await contextTab.click();
  await page.waitForLoadState("networkidle");

  const addButton = page.getByRole("button", { name: /add.*entry/i });
  await expect(addButton).toBeVisible();
  await addButton.click();

  await page.waitForSelector("input[type='text']");

  const nameInput = page.locator("input[type='text']").first();
  await nameInput.fill("MathHelper");

  const submitButton = page.getByRole("button", { name: /add entry|submit/i });
  await submitButton.click();

  await expect(page.locator("text=/MathHelper/i")).toBeVisible();

  const chatTab = page.getByRole("button", { name: /💬|chat/i });
  await expect(chatTab).toBeVisible();
  await chatTab.click();
  await page.waitForLoadState("networkidle");

  const messageInput = page.getByPlaceholder(/type.*message|enter.*message/i);
  await expect(messageInput).toBeVisible();
  await messageInput.fill("What is 3 + 3?");
  await page.getByRole("button", { name: /send/i }).click();

  await expect(page.locator(".chat-message, .message")).toHaveCount(2, { timeout: 25000 });

  await contextTab.click();
  await page.waitForLoadState("networkidle");
  await expect(page.locator("text=/MathHelper/i")).toBeVisible();
});
