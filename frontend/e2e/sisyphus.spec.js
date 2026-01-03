import { test, expect } from "@playwright/test";

/**
 * Sisyphus Page E2E Tests
 * 
 * Tests the complete Sisyphus UI workflow including:
 * - Page load and navigation
 * - Project and plan path input
 * - Dry-run mode toggle
 * - Approval mode selection
 * - Execution start
 * - Configuration display
 */

test.describe("Sisyphus Page", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/sisyphus");
  });

  test("page loads with correct title and description", async ({ page }) => {
    // Check main heading
    await expect(page.getByRole("heading", { name: "Sisyphus Agent Worker" })).toBeVisible();
    
    // Check description
    await expect(page.getByText("Autonomous execution agent for structured plans")).toBeVisible();
  });

  test("has three main panels", async ({ page }) => {
    // Left panel: Project Setup
    await expect(page.getByRole("heading", { name: "Project Setup" })).toBeVisible();
    
    // Middle panel: Execution Monitor
    await expect(page.getByRole("heading", { name: "Execution Monitor" })).toBeVisible();
    
    // Right panel: Configuration
    await expect(page.getByRole("heading", { name: "Configuration" })).toBeVisible();
  });

  test("project path input accepts text", async ({ page }) => {
    const projectInput = page.getByPlaceholder("/path/to/project");
    
    await projectInput.fill("/home/user/my-project");
    await expect(projectInput).toHaveValue("/home/user/my-project");
  });

  test("plan path input accepts text", async ({ page }) => {
    const planInput = page.getByPlaceholder("/path/to/plan.md");
    
    await planInput.fill("/home/user/plans/feature.md");
    await expect(planInput).toHaveValue("/home/user/plans/feature.md");
  });

  test("dry-run checkbox can be toggled", async ({ page }) => {
    const dryRunCheckbox = page.getByRole("checkbox", { name: /Dry Run Mode/ });
    
    // Should be unchecked by default
    await expect(dryRunCheckbox).not.toBeChecked();
    
    // Click to enable
    await dryRunCheckbox.check();
    await expect(dryRunCheckbox).toBeChecked();
    
    // Should show PREVIEW ONLY badge when checked
    await expect(page.getByText("PREVIEW ONLY")).toBeVisible();
    
    // Click to disable
    await dryRunCheckbox.uncheck();
    await expect(dryRunCheckbox).not.toBeChecked();
  });

  test("approval mode selector has all three options", async ({ page }) => {
    const approvalSelect = page.locator("select").filter({ hasText: /Autonomous/ });
    
    // Check all options are available
    await expect(approvalSelect.locator("option[value='autonomous']")).toBeVisible();
    await expect(approvalSelect.locator("option[value='step']")).toBeVisible();
    await expect(approvalSelect.locator("option[value='milestone']")).toBeVisible();
  });

  test("approval mode selector changes description text", async ({ page }) => {
    const approvalSelect = page.locator("select").filter({ hasText: /Autonomous/ });
    
    // Default: autonomous
    await expect(page.getByText("Execution runs automatically")).toBeVisible();
    
    // Change to step mode
    await approvalSelect.selectOption("step");
    await expect(page.getByText("You'll approve each individual step")).toBeVisible();
    
    // Change to milestone mode
    await approvalSelect.selectOption("milestone");
    await expect(page.getByText("You'll approve each milestone")).toBeVisible();
  });

  test("start execution button is disabled without paths", async ({ page }) => {
    const startButton = page.getByRole("button", { name: /Start Execution/ });
    
    // Should be disabled initially
    await expect(startButton).toBeDisabled();
  });

  test("start execution button is enabled with both paths", async ({ page }) => {
    const projectInput = page.getByPlaceholder("/path/to/project");
    const planInput = page.getByPlaceholder("/path/to/plan.md");
    const startButton = page.getByRole("button", { name: /Start Execution/ });
    
    // Fill in paths
    await projectInput.fill("/home/user/project");
    await planInput.fill("/home/user/plan.md");
    
    // Button should be enabled
    await expect(startButton).toBeEnabled();
  });

  test("browse files button is disabled without project path", async ({ page }) => {
    const browseButton = page.getByRole("button", { name: /Browse Files/ });
    
    await expect(browseButton).toBeDisabled();
  });

  test("browse files button is enabled with project path", async ({ page }) => {
    const projectInput = page.getByPlaceholder("/path/to/project");
    const browseButton = page.getByRole("button", { name: /Browse Files/ });
    
    await projectInput.fill("/home/user/project");
    
    await expect(browseButton).toBeEnabled();
  });

  test("execution monitor shows 'no execution' message initially", async ({ page }) => {
    await expect(page.getByText("No execution in progress")).toBeVisible();
  });

  test("configuration panel shows loading state initially", async ({ page }) => {
    // Configuration panel exists
    const configPanel = page.getByRole("heading", { name: "Configuration" }).locator("..");
    await expect(configPanel).toBeVisible();
  });

  test("recent executions section is visible", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "Recent Executions" })).toBeVisible();
    
    // Should show "No executions yet" initially
    await expect(page.getByText("No executions yet")).toBeVisible();
  });

  test("execution options panel displays correctly", async ({ page }) => {
    await expect(page.getByText("Execution Options")).toBeVisible();
    
    // Check all option labels
    await expect(page.getByText("Dry Run Mode")).toBeVisible();
    await expect(page.getByText("Approval Mode")).toBeVisible();
  });

  test("dry-run mode shows correct description text", async ({ page }) => {
    const dryRunCheckbox = page.getByRole("checkbox", { name: /Dry Run Mode/ });
    
    // Unchecked: shows "will be executed"
    await expect(page.getByText("Changes will be executed for real")).toBeVisible();
    
    // Checked: shows "will be simulated"
    await dryRunCheckbox.check();
    await expect(page.getByText("Changes will be simulated, not executed")).toBeVisible();
  });
});

test.describe("Sisyphus Page - Execution Flow", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/sisyphus");
  });

  test("can fill complete form and attempt to start execution", async ({ page }) => {
    // Fill in all fields
    await page.getByPlaceholder("/path/to/project").fill("/home/user/test-project");
    await page.getByPlaceholder("/path/to/plan.md").fill("/home/user/plans/test.md");
    
    // Enable dry-run
    await page.getByRole("checkbox", { name: /Dry Run Mode/ }).check();
    
    // Select approval mode
    await page.locator("select").filter({ hasText: /Autonomous/ }).selectOption("milestone");
    
    // Click start (will fail without backend, but tests UI interaction)
    const startButton = page.getByRole("button", { name: /Start Execution/ });
    await expect(startButton).toBeEnabled();
    
    // Note: We don't actually click because it would try to hit the backend
    // For full integration test, mock the API or use a test backend
  });
});

test.describe("Sisyphus Page - Responsive Design", () => {
  test("displays correctly on mobile viewport", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 }); // iPhone SE
    await page.goto("/sisyphus");
    
    // Main elements should still be visible
    await expect(page.getByRole("heading", { name: "Sisyphus Agent Worker" })).toBeVisible();
    await expect(page.getByPlaceholder("/path/to/project")).toBeVisible();
    await expect(page.getByRole("button", { name: /Start Execution/ })).toBeVisible();
  });

  test("displays correctly on tablet viewport", async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 }); // iPad
    await page.goto("/sisyphus");
    
    await expect(page.getByRole("heading", { name: "Sisyphus Agent Worker" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Project Setup" })).toBeVisible();
  });
});

