import { expect, fast, medium, slow } from "./base-test";

/**
 * DND Chat E2E Tests - Uses real LLM
 */

medium("chat page loads and accepts input", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("Darkwood Adventure")).toBeVisible();

  const input = page.getByPlaceholder("Type your action or ask the DM...");
  await input.fill("Inspect the ancient door");
  await input.press("Enter");

  await expect(page.getByText("Inspect the ancient door")).toBeVisible();
});

slow("agent version bumps after chat message", async ({ page }) => {
  await page.goto("/");

  const initialVersion = await page.evaluate(async () => {
    const res = await fetch("/dnd_chat/agent/version");
    const data = await res.json();
    return data.version || 0;
  });

  const input = page.getByPlaceholder("Type your action or ask the DM...");
  await input.fill("Light a torch");
  await input.press("Enter");

  await expect(page.getByText("Light a torch")).toBeVisible();

  const versionChanged = await page.waitForFunction(
    async (start) => {
      const res = await fetch("/dnd_chat/agent/version");
      const data = await res.json();
      return (data.version || 0) > start;
    },
    initialVersion,
  );

  expect(versionChanged).toBeTruthy();
});
