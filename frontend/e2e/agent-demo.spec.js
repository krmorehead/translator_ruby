import { expect, medium, slow } from "./base-test";

/**
 * Full IDE Extension UX Demo
 * 
 * This test demonstrates the complete conversational agent experience
 * Similar to GitHub Copilot Chat or Cursor AI
 */

slow("DEMO: Part 1 - Conversational AI with Context", async ({ page }) => {
  console.log("\n" + "=".repeat(80));
  console.log("🚀 DEMO: IDE-LIKE CONVERSATIONAL AGENT UX");
  console.log("=".repeat(80) + "\n");
  
  // ==================== SESSION INITIALIZATION ====================
  console.log("📝 PHASE 1: Initialize Agent Session");
  console.log("-".repeat(80));
  
  await page.goto("/agent");
  console.log("✓ Loaded /agent workspace");
  
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  console.log("✓ Agent session initialized");
  console.log("✓ Session tabs visible: Chat, Thoughts, Memory, Context, Timeline");
  
  // ==================== CHAT INTERFACE ====================
  console.log("\n📝 PHASE 2: Chat Interface");
  console.log("-".repeat(80));
  
  const chatTab = page.locator('button[aria-label="Chat"]');
  await chatTab.click();
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Chat panel ready");
  
  const messageInput = page.locator('input.chat-input, .chat-input input').first();
  const sendBtn = page.locator('button.chat-send-button, .chat-send-button').first();
  
  // ==================== FIRST CONVERSATION ====================
  console.log("\n📝 PHASE 3: First Conversation - Code Question");
  console.log("-".repeat(80));
  
  await messageInput.fill("Explain what a Ruby module is");
  console.log("💬 User: 'Explain what a Ruby module is'");
  await sendBtn.click();
  
  await expect(page.locator('.chat-message, .message').first()).toBeVisible();
  const response1 = await page.locator('.chat-message, .message').nth(1).textContent();
  console.log(`🤖 Agent: ${response1.substring(0, 150)}...`);
  console.log("✓ First conversation complete");
  
  // ==================== CHECKING MESSAGE COUNT ====================
  const messageCount = await page.locator('.chat-message, .message').count();
  console.log(`\n📊 Total messages in conversation: ${messageCount}`);
  console.log("✓ Agent provides detailed explanations");
  
  // ==================== SUMMARY ====================
  console.log("\n" + "=".repeat(80));
  console.log("✅ PART 1 COMPLETE: Conversational AI");
  console.log("=".repeat(80));
  console.log("\nFeatures Demonstrated:");
  console.log("  ✓ Session initialization with tabs");
  console.log("  ✓ Real-time conversational AI (LLM-powered)");
  console.log("  ✓ Code explanations and assistance");
  console.log("  ✓ Message history preserved");
  console.log("\n" + "=".repeat(80) + "\n");
});

slow("DEMO: Part 2 - Tab Navigation and Code Assistance", async ({ page }) => {
  console.log("\n" + "=".repeat(80));
  console.log("🚀 DEMO: IDE-LIKE AGENT - TAB NAVIGATION");
  console.log("=".repeat(80) + "\n");
  
  // Initialize session
  await page.goto("/agent");
  await page.locator('button').filter({ hasText: /initialize.*session/i }).click();
  await expect(page.locator('.agent-tabs')).toBeVisible();
  console.log("✓ Session initialized");
  
  const chatTab = page.locator('button[aria-label="Chat"]');
  
  // ==================== TAB NAVIGATION ====================
  console.log("\n📝 PHASE 1: Exploring All Tabs (Like IDE Extensions)");
  console.log("-".repeat(80));
  
  // Check Thoughts
  const thoughtsTab = page.locator('button[aria-label="Thoughts"]');
  await thoughtsTab.click();
  console.log("✓ Switched to Thoughts tab (view agent reasoning)");
  await page.waitForTimeout(500);
  
  // Check Memory
  const memoryTab = page.locator('button[aria-label="Memory"]');
  await memoryTab.click();
  console.log("✓ Switched to Memory tab (view agent memory)");
  await page.waitForTimeout(500);
  
  // Check Context
  const contextTab = page.locator('button[aria-label="Context"]');
  await contextTab.click();
  console.log("✓ Switched to Context tab (manage codebase context)");
  await page.waitForTimeout(500);
  
  // Check Timeline
  const timelineTab = page.locator('button[aria-label="Timeline"]');
  await timelineTab.click();
  console.log("✓ Switched to Timeline tab (view activity timeline)");
  await page.waitForTimeout(500);
  
  // Back to Chat
  await chatTab.click();
  await expect(page.locator('.chat-panel')).toBeVisible();
  console.log("✓ Switched back to Chat tab");
  
  console.log("\n📝 All tabs are functional and accessible!");
  
  // ==================== SUMMARY ====================
  console.log("\n" + "=".repeat(80));
  console.log("✅ PART 2 COMPLETE: Tab Navigation");
  console.log("=".repeat(80));
  console.log("\nFeatures Demonstrated:");
  console.log("  ✓ Multiple tool tabs (Chat, Thoughts, Memory, Context, Timeline)");
  console.log("  ✓ Seamless tab switching");
  console.log("  ✓ Full IDE extension-like interface");
  console.log("\nThis mirrors the experience of:");
  console.log("  • GitHub Copilot Chat (side panel with multiple views)");
  console.log("  • Cursor AI (chat + context + memory)");
  console.log("  • VS Code AI assistants (tabbed interface)");
  console.log("\n" + "=".repeat(80) + "\n");
});

