import { test, expect } from "@playwright/test";

test("chat page loads and accepts input", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("Darkwood Adventure")).toBeVisible();

  const input = page.getByPlaceholder("Type your action or ask the DM...");
  await input.fill("Inspect the ancient door");
  await input.press("Enter");

  await expect(page.getByText("Inspect the ancient door")).toBeVisible();
});

test("agent version bumps after chat message", async ({ page }) => {
  await page.goto("/");

  // Get initial version
  const initialVersion = await page.evaluate(async () => {
    const res = await fetch("/dnd_chat/agent/version");
    const data = await res.json();
    return data.version || 0;
  });

  // Send a message
  const input = page.getByPlaceholder("Type your action or ask the DM...");
  await input.fill("Light a torch");
  await input.press("Enter");

  // Wait for assistant reply to appear
  await expect(page.getByText("Light a torch")).toBeVisible();

  // Poll version until it changes or timeout
  const versionChanged = await page.waitForFunction(
    async (start) => {
      const res = await fetch("/dnd_chat/agent/version");
      const data = await res.json();
      return (data.version || 0) > start;
    },
    initialVersion,
    { timeout: 10_000 }
  );

  expect(versionChanged).toBeTruthy();
});

