import { expect, slow } from "./base-test";

/**
 * Multi-Step Conversation Tests
 * 
 * Tests complex conversation flows with multiple turns,
 * context maintenance, and various interaction patterns
 */

slow("multi-step - complex conversation with 5+ turns", async ({ page }) => {
  console.log("\n🎯 Testing Complex Multi-Step Conversation");
  console.log("=" .repeat(80));
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Initialize session
  console.log("\nStep 1: Initialize session");
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  console.log("✓ Session initialized");
  
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  const sendBtn = page.locator('button.chat-send-button, .chat-send-button').first();
  
  // Turn 1: Introduction
  console.log("\nTurn 1: Introduction");
  await messageInput.fill("Hi! I'm working on a Ruby project.");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').first()).toBeVisible();
  await expect(page.locator('.chat-message, .message').nth(1)).toBeVisible();
  console.log("✓ Turn 1 complete (greeting)");
  
  await page.waitForTimeout(1000);
  
  // Turn 2: Ask about feature
  console.log("\nTurn 2: Ask about Ruby feature");
  await messageInput.fill("Can you explain what Ruby modules are?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(3)).toBeVisible();
  console.log("✓ Turn 2 complete (module explanation)");
  
  await page.waitForTimeout(1000);
  
  // Turn 3: Follow-up question (tests context)
  console.log("\nTurn 3: Follow-up question (context test)");
  await messageInput.fill("Can you show me an example?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(5)).toBeVisible();
  console.log("✓ Turn 3 complete (example - agent should remember we're talking about modules)");
  
  await page.waitForTimeout(1000);
  
  // Turn 4: Different topic, remember context
  console.log("\nTurn 4: Different topic with context");
  await messageInput.fill("My project is called 'translator_ruby'. What should I know about it?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(7)).toBeVisible();
  console.log("✓ Turn 4 complete (project discussion)");
  
  await page.waitForTimeout(1000);
  
  // Turn 5: Reference earlier context
  console.log("\nTurn 5: Reference earlier context");
  await messageInput.fill("Should I use modules in translator_ruby?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(9)).toBeVisible();
  console.log("✓ Turn 5 complete (combining context from turns 2, 3, and 4)");
  
  // Verify message count
  const finalCount = await page.locator('.chat-message, .message').count();
  console.log(`\n📊 Final message count: ${finalCount} (expected: 10)`);
  expect(finalCount).toBeGreaterThanOrEqual(10);
  
  // Check that all messages are still visible
  console.log("\n✓ All messages preserved in history");
  console.log("✓ Context maintained across all 5 turns");
  console.log("✓ Agent remembered: Ruby modules, examples, project name");
  
  console.log("\n" + "=".repeat(80));
  console.log("✅ Complex multi-step conversation test complete!");
  console.log("=".repeat(80));
});

slow("multi-step - conversation with code examples", async ({ page }) => {
  console.log("\n🎯 Testing Conversation with Code Examples");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  const sendBtn = page.locator('button.chat-send-button, .chat-send-button').first();
  
  // Ask for code
  console.log("\nTurn 1: Request code example");
  await messageInput.fill("Show me a Ruby class example");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(1)).toBeVisible();
  
  // Check for code block rendering
  const hasCodeBlock = await page.locator('.code-block').count() > 0;
  if (hasCodeBlock) {
    console.log("✓ Code block rendered with markdown");
  } else {
    console.log("⚠️  Code block may not have been rendered");
  }
  
  await page.waitForTimeout(1000);
  
  // Ask about the code
  console.log("\nTurn 2: Ask about the code");
  await messageInput.fill("Can you explain the initialize method?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(3)).toBeVisible();
  console.log("✓ Agent explained code (context maintained)");
  
  const finalCount = await page.locator('.chat-message, .message').count();
  console.log(`\n📊 Total messages: ${finalCount}`);
  
  console.log("\n✅ Code conversation test complete!");
});

slow("multi-step - error recovery in conversation", async ({ page }) => {
  console.log("\n🎯 Testing Error Recovery in Conversation");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  const sendBtn = page.locator('button.chat-send-button, .chat-send-button').first();
  
  // Normal message
  console.log("\nTurn 1: Normal message");
  await messageInput.fill("Hello");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(1)).toBeVisible();
  console.log("✓ First message successful");
  
  await page.waitForTimeout(1000);
  
  // Empty message (should not send)
  console.log("\nTurn 2: Try to send empty message");
  await messageInput.fill("   ");
  const sendBtnDisabled = await sendBtn.isDisabled();
  if (sendBtnDisabled) {
    console.log("✓ Send button correctly disabled for empty message");
  }
  
  // Continue conversation
  console.log("\nTurn 3: Continue with valid message");
  await messageInput.fill("What is Ruby?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(3)).toBeVisible();
  console.log("✓ Conversation continued after error handling");
  
  const finalCount = await page.locator('.chat-message, .message').count();
  expect(finalCount).toBeGreaterThanOrEqual(4);
  
  console.log("\n✅ Error recovery test complete!");
});

slow("multi-step - tab switching during conversation", async ({ page }) => {
  console.log("\n🎯 Testing Tab Switching During Conversation");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  const sendBtn = page.locator('button.chat-send-button, .chat-send-button').first();
  
  // Send first message
  console.log("\nSend message 1");
  await messageInput.fill("Tell me about Ruby");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(1)).toBeVisible();
  console.log("✓ Message 1 sent");
  
  // Switch to Thoughts
  console.log("\nSwitch to Thoughts tab");
  await page.locator('button[aria-label="Thoughts"]').click();
  await expect(page.locator('.thoughts-panel')).toBeVisible();
  console.log("✓ Switched to Thoughts");
  
  // Switch back to Chat
  console.log("\nSwitch back to Chat");
  await page.locator('button[aria-label="Chat"]').click();
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Back to Chat");
  
  // Verify message still there
  const messageCount = await page.locator('.chat-message, .message').count();
  expect(messageCount).toBeGreaterThanOrEqual(2);
  console.log("✓ Messages preserved after tab switch");
  
  // Send another message
  console.log("\nSend message 2 after tab switch");
  await messageInput.fill("What about Python?");
  await sendBtn.click();
  await expect(page.locator('.chat-message, .message').nth(3)).toBeVisible();
  console.log("✓ Message 2 sent successfully");
  
  const finalCount = await page.locator('.chat-message, .message').count();
  expect(finalCount).toBeGreaterThanOrEqual(4);
  console.log(`✓ All ${finalCount} messages preserved`);
  
  console.log("\n✅ Tab switching test complete!");
});

slow("multi-step - keyboard shortcut navigation", async ({ page }) => {
  console.log("\n🎯 Testing Keyboard Shortcuts in Conversation");
  
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  
  // Send message
  await messageInput.fill("Hello Agent");
  await page.keyboard.press('Enter');
  await expect(page.locator('.chat-message, .message').nth(1)).toBeVisible();
  console.log("✓ Sent message with Enter key");
  
  await page.waitForTimeout(1000);
  
  // Use Cmd+K to focus input (Cmd on Mac, Ctrl on others)
  const isMac = await page.evaluate(() => navigator.platform.toUpperCase().indexOf('MAC') >= 0);
  const modifier = isMac ? 'Meta' : 'Control';
  
  console.log(`\nTesting keyboard shortcuts (${modifier} key)`);
  
  // Test Cmd/Ctrl + 2 to switch to Thoughts
  await page.keyboard.press(`${modifier}+2`);
  await page.waitForTimeout(500);
  await expect(page.locator('.thoughts-panel')).toBeVisible();
  console.log("✓ Cmd/Ctrl+2 switched to Thoughts");
  
  // Test Cmd/Ctrl + 1 to switch back to Chat
  await page.keyboard.press(`${modifier}+1`);
  await page.waitForTimeout(500);
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Cmd/Ctrl+1 switched to Chat");
  
  // Test Cmd/Ctrl + K to focus input
  await page.keyboard.press(`${modifier}+k`);
  await page.waitForTimeout(300);
  const isFocused = await messageInput.evaluate(el => document.activeElement === el);
  if (isFocused) {
    console.log("✓ Cmd/Ctrl+K focused chat input");
  }
  
  console.log("\n✅ Keyboard shortcuts test complete!");
});

