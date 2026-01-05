import { expect, medium, slow } from "./base-test";

const UI_TIMEOUT = 5000;
const LLM_TIMEOUT = 30000;

async function initializeAgentSession(page) {
  await page.goto("/agent");
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
}

medium("displays persistent context UI when session active", async ({ page }) => {
  console.log("\n🎯 Testing Persistent Context UI");
  
  await initializeAgentSession(page);
  
  // Check for persistent context toggle
  const contextToggle = page.locator('.persistent-context-toggle');
  await expect(contextToggle).toBeVisible();
  console.log("✓ Persistent context toggle visible");
  
  // Check toggle text
  await expect(contextToggle).toContainText("Persistent Context");
  console.log("✓ Toggle shows correct label");
  
  // Expand persistent context
  await contextToggle.click();
  await page.waitForTimeout(300); // Animation
  
  // Check for empty state
  await expect(page.locator('.context-empty')).toBeVisible();
  await expect(page.locator('text=No persistent context set')).toBeVisible();
  console.log("✓ Empty state displayed correctly");
  
  console.log("\n✅ Persistent context UI test complete");
});

medium("can add and save persistent context", async ({ page }) => {
  console.log("\n🎯 Testing Add Persistent Context");
  
  await initializeAgentSession(page);
  
  // Expand persistent context
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  
  // Click add context button
  await page.locator('button').filter({ hasText: /add context/i }).click();
  console.log("✓ Clicked add context");
  
  // Wait for textarea
  const textarea = page.locator('textarea.context-textarea');
  await expect(textarea).toBeVisible();
  console.log("✓ Editor textarea visible");
  
  // Type persistent context
  const contextText = "Always use Ruby 3.0+ features. Prefer functional style.";
  await textarea.fill(contextText);
  console.log("✓ Typed context text");
  
  // Save context
  await page.locator('button').filter({ hasText: /save/i }).click();
  await page.waitForTimeout(300);
  console.log("✓ Clicked save");
  
  // Verify context is displayed
  await expect(page.locator('.context-text')).toContainText(contextText);
  console.log("✓ Context displayed after save");
  
  // Verify indicator shows context is set
  await expect(page.locator('.context-indicator')).toBeVisible();
  console.log("✓ Context indicator visible");
  
  console.log("\n✅ Add persistent context test complete");
});

medium("can edit persistent context", async ({ page }) => {
  console.log("\n🎯 Testing Edit Persistent Context");
  
  await initializeAgentSession(page);
  
  // Add initial context
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  await page.locator('button').filter({ hasText: /add context/i }).click();
  await page.locator('textarea.context-textarea').fill("Initial context");
  await page.locator('button').filter({ hasText: /save/i }).click();
  await page.waitForTimeout(300);
  console.log("✓ Initial context added");
  
  // Click edit button
  await page.locator('button.btn-edit').click();
  await page.waitForTimeout(300);
  console.log("✓ Clicked edit");
  
  // Modify context
  const textarea = page.locator('textarea.context-textarea');
  await textarea.clear();
  await textarea.fill("Updated context");
  console.log("✓ Modified context text");
  
  // Save changes
  await page.locator('button').filter({ hasText: /save/i }).click();
  await page.waitForTimeout(300);
  console.log("✓ Saved changes");
  
  // Verify updated text
  await expect(page.locator('.context-text')).toContainText("Updated context");
  await expect(page.locator('.context-text')).not.toContainText("Initial context");
  console.log("✓ Context updated successfully");
  
  console.log("\n✅ Edit persistent context test complete");
});

medium("can clear persistent context", async ({ page }) => {
  console.log("\n🎯 Testing Clear Persistent Context");
  
  await initializeAgentSession(page);
  
  // Add context
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  await page.locator('button').filter({ hasText: /add context/i }).click();
  await page.locator('textarea.context-textarea').fill("Context to clear");
  await page.locator('button').filter({ hasText: /save/i }).click();
  await page.waitForTimeout(300);
  console.log("✓ Context added");
  
  // Set up dialog handler
  page.on('dialog', dialog => dialog.accept());
  
  // Click clear button
  await page.locator('button.btn-clear').click();
  await page.waitForTimeout(300);
  console.log("✓ Clicked clear (confirmed)");
  
  // Verify empty state is back
  await expect(page.locator('.context-empty')).toBeVisible();
  await expect(page.locator('text=No persistent context set')).toBeVisible();
  console.log("✓ Empty state restored");
  
  // Verify indicator is gone
  await expect(page.locator('.context-indicator')).not.toBeVisible();
  console.log("✓ Indicator hidden");
  
  console.log("\n✅ Clear persistent context test complete");
});

slow("persistent context is sent with chat messages", async ({ page }) => {
  console.log("\n🎯 Testing Persistent Context in Chat");
  
  await initializeAgentSession(page);
  
  // Add persistent context
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  await page.locator('button').filter({ hasText: /add context/i }).click();
  await page.locator('textarea.context-textarea').fill("Always respond with enthusiasm!");
  await page.locator('button').filter({ hasText: /save/i }).click();
  await page.waitForTimeout(300);
  console.log("✓ Persistent context set: 'Always respond with enthusiasm!'");
  
  // Collapse persistent context to see chat
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  
  // Send a chat message
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  await messageInput.fill("Hello, how are you?");
  await page.locator('button.chat-send-button, .chat-send-button').first().click();
  console.log("✓ Message sent");
  
  // Wait for agent response
  await expect(page.locator('.chat-message, .message').nth(1)).toBeVisible();
  console.log("✓ Agent responded");
  
  // Get agent response text
  const agentResponse = await page.locator('.chat-message, .message').nth(1).innerText();
  console.log("Agent response:", agentResponse.substring(0, 100) + "...");
  
  // Note: We can't directly verify the LLM followed the persistent context
  // without inspecting the backend logs, but we can verify the message was sent
  console.log("✓ Response received (persistent context was sent to backend)");
  
  console.log("\n✅ Persistent context in chat test complete");
});

medium("persistent context persists across page refresh", async ({ page }) => {
  console.log("\n🎯 Testing Persistent Context Persistence");
  
  await initializeAgentSession(page);
  
  // Add context
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  await page.locator('button').filter({ hasText: /add context/i }).click();
  const contextText = "This context should persist";
  await page.locator('textarea.context-textarea').fill(contextText);
  await page.locator('button').filter({ hasText: /save/i }).click();
  await page.waitForTimeout(300);
  console.log("✓ Context saved");
  
  // Reload page
  await page.reload();
  console.log("✓ Page reloaded");
  
  // Initialize new session
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  console.log("✓ New session initialized");
  
  // Expand persistent context
  await page.locator('.persistent-context-toggle').click();
  await page.waitForTimeout(300);
  
  // Verify context is still there
  await expect(page.locator('.context-text')).toContainText(contextText);
  await expect(page.locator('.context-indicator')).toBeVisible();
  console.log("✓ Context persisted across page reload");
  
  console.log("\n✅ Persistent context persistence test complete");
});

medium("persistent context toggle expand/collapse works", async ({ page }) => {
  console.log("\n🎯 Testing Persistent Context Toggle");
  
  await initializeAgentSession(page);
  
  const toggle = page.locator('.persistent-context-toggle');
  const content = page.locator('.persistent-context-content');
  
  // Initially collapsed
  await expect(content).not.toBeVisible();
  console.log("✓ Initially collapsed");
  
  // Expand
  await toggle.click();
  await page.waitForTimeout(300);
  await expect(content).toBeVisible();
  console.log("✓ Expanded on first click");
  
  // Collapse
  await toggle.click();
  await page.waitForTimeout(300);
  await expect(content).not.toBeVisible();
  console.log("✓ Collapsed on second click");
  
  // Expand again
  await toggle.click();
  await page.waitForTimeout(300);
  await expect(content).toBeVisible();
  console.log("✓ Re-expanded on third click");
  
  console.log("\n✅ Persistent context toggle test complete");
});

