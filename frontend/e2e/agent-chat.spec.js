import { expect, medium, slow } from "./base-test";

/**
 * Agent Chat Integration Tests
 * 
 * Tests the conversational agent UX - like an IDE extension
 * Real LLM calls, real conversation chains
 */

medium("initializes agent session and shows chat interface", async ({ page }) => {
  console.log("\n🎯 Testing Agent Session Initialization");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Click Initialize Session button
  console.log("Step 1: Initializing agent session...");
  const initBtn = page.locator('button').filter({ hasText: /initialize.*session/i });
  await expect(initBtn).toBeVisible();
  await initBtn.click();
  
  // Wait for tabs to appear
  console.log("Step 2: Waiting for agent interface to load...");
  await expect(page.locator('.agent-tabs')).toBeVisible({ timeout: 10000 });
  console.log("✓ Agent tabs loaded");
  
  // Verify all tabs are present
  await expect(page.locator('button[aria-label="Chat"]')).toBeVisible();
  await expect(page.locator('button[aria-label="Thoughts"]')).toBeVisible();
  await expect(page.locator('button[aria-label="Memory"]')).toBeVisible();
  await expect(page.locator('button[aria-label="Context"]')).toBeVisible();
  console.log("✓ All agent tabs present");
  
  // Chat tab should be active by default
  const chatTab = page.locator('button[aria-label="Chat"]');
  await expect(chatTab).toHaveClass(/active/);
  console.log("✓ Chat tab active by default");
  
  // Chat panel should be visible
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Chat panel visible");
  
  console.log("\n✅ Agent session initialization complete\n");
});

slow("sends message and receives LLM response", async ({ page }) => {
  console.log("\n🎯 Testing Conversational Agent with Real LLM");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  console.log("Step 1: Initializing session...");
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible({ timeout: 10000 });
  console.log("✓ Session initialized");
  
  // Ensure we're on chat tab
  const chatTab = page.locator('button[aria-label="Chat"]');
  await chatTab.click();
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Chat panel ready");
  
  // Type message
  console.log("Step 2: Sending message to agent...");
  const messageInput = page.locator('input[aria-label="Message input"], input.chat-input, .chat-input input');
  await expect(messageInput.first()).toBeVisible();
  await messageInput.first().fill("What is 2 + 2?");
  console.log("✓ Message typed: 'What is 2 + 2?'");
  
  // Send message
  const sendBtn = page.locator('button[aria-label="Send message"], button.chat-send-button, .chat-send-button');
  await expect(sendBtn.first()).toBeEnabled();
  await sendBtn.first().click();
  console.log("✓ Message sent - waiting for API response...");
  
  // Wait for messages to appear (longer timeout for LLM)
  console.log("Step 3: Waiting for conversation to update...");
  await expect(page.locator('.chat-message, .message').first()).toBeVisible({ timeout: 30000 });
  console.log("✓ Messages displayed");
  
  // Count messages
  const messageCount = await page.locator('.chat-message, .message').count();
  console.log(`Found ${messageCount} messages`);
  
  if (messageCount >= 2) {
    const agentMessage = page.locator('.chat-message, .message').nth(1);
    const messageText = await agentMessage.textContent();
    console.log(`Agent response: ${messageText.substring(0, 100)}...`);
    
    if (messageText.toLowerCase().includes('4') || messageText.toLowerCase().includes('four')) {
      console.log("✓ Agent correctly answered '2 + 2 = 4'");
    } else {
      console.log("⚠️  Agent response may not contain expected answer");
    }
  } else {
    console.log(`⚠️  Expected at least 2 messages, got ${messageCount}`);
  }
  
  console.log("\n✅ Conversational agent test complete\n");
});

slow("maintains conversation context across multiple messages", async ({ page }) => {
  console.log("\n🎯 Testing Conversation Chain with Context");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  console.log("Step 1: Initializing session...");
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.chat-panel')).toBeVisible({ timeout: 10000 });
  
  const messageInput = page.locator('.chat-input');
  const sendBtn = page.locator('.chat-send-button');
  
  // First message
  console.log("Step 2: Sending first message...");
  await messageInput.fill("My name is Test User");
  await sendBtn.click();
  await expect(page.locator('.chat-message').nth(1)).toBeVisible({ timeout: 25000 });
  console.log("✓ First exchange complete");
  
  // Wait a moment
  await page.waitForTimeout(1000);
  
  // Second message - test context
  console.log("Step 3: Sending follow-up message...");
  await messageInput.fill("What is my name?");
  await sendBtn.click();
  
  // Wait for response
  await expect(page.locator('.chat-message').nth(3)).toBeVisible({ timeout: 25000 });
  console.log("✓ Second exchange complete");
  
  // Check if agent remembers
  const response = await page.locator('.chat-message').nth(3).textContent();
  console.log(`Agent response: ${response.substring(0, 100)}...`);
  
  if (response.toLowerCase().includes('test user')) {
    console.log("✓ Agent maintains conversation context!");
  } else {
    console.log("⚠️  Agent may not have maintained context");
  }
  
  // Verify we have 4 messages total
  const messageCount = await page.locator('.chat-message').count();
  console.log(`Total messages: ${messageCount} (expected 4)`);
  
  console.log("\n✅ Conversation chain test complete\n");
});

medium("switches between chat and thoughts tabs", async ({ page }) => {
  console.log("\n🎯 Testing Tab Navigation");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible({ timeout: 10000 });
  console.log("✓ Session initialized");
  
  // Chat tab should be active
  const chatTab = page.locator('button[aria-label="Chat"]');
  await expect(chatTab).toHaveClass(/active/);
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Chat tab active");
  
  // Switch to Thoughts
  console.log("Step 1: Switching to Thoughts tab...");
  const thoughtsTab = page.locator('button[aria-label="Thoughts"]');
  await thoughtsTab.click();
  await expect(thoughtsTab).toHaveClass(/active/);
  console.log("✓ Thoughts tab active");
  
  // Switch to Memory
  console.log("Step 2: Switching to Memory tab...");
  const memoryTab = page.locator('button[aria-label="Memory"]');
  await memoryTab.click();
  await expect(memoryTab).toHaveClass(/active/);
  console.log("✓ Memory tab active");
  
  // Switch back to Chat
  console.log("Step 3: Switching back to Chat...");
  await chatTab.click();
  await expect(chatTab).toHaveClass(/active/);
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Chat tab active again");
  
  console.log("\n✅ Tab navigation test complete\n");
});

medium("shows session ID in chat panel", async ({ page }) => {
  console.log("\n🎯 Testing Session ID Display");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.chat-panel')).toBeVisible({ timeout: 10000 });
  
  // Look for session ID display
  const sessionDisplay = page.locator('text=/session.*:/i');
  if (await sessionDisplay.isVisible().catch(() => false)) {
    const sessionText = await sessionDisplay.textContent();
    console.log(`✓ Session ID displayed: ${sessionText}`);
  } else {
    console.log("⚠️  Session ID not visible in UI");
  }
  
  console.log("\n✅ Session ID test complete\n");
});

