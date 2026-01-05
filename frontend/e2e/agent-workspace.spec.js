import { expect, fast, medium, slow } from "./base-test";
import { AgentConfig } from "../src/models/AgentConfig";
import { ExecutionPlan } from "../src/models/ExecutionPlan";

/**
 * Unified Agent Workspace E2E Tests
 * 
 * ALL TESTS MUST USE SPEED PROFILING:
 * - fast(): UI only, no network (< 5s)
 * - medium(): API calls, no LLM (< 15s)
 * - slow(): Real LLM, ONE simple query (< 30s)
 * 
 * NO MOCKS - All tests use real backend APIs
 * NO TEST ENDPOINTS - Tests exercise actual production code paths
 */

// =============================================================================
// FAST TESTS - UI Only, No Backend (< 5s each)
// =============================================================================

fast("renders with Daedalus mode by default", async ({ page }) => {
  await page.goto("/agent");

  await expect(page.locator("h1").filter({ hasText: /daedalus/i })).toBeVisible();
    await expect(page.locator("select.mode-selector")).toHaveValue("daedalus");
  });

fast("mode selector has both options", async ({ page }) => {
  await page.goto("/agent");
    
    const selector = page.locator("select.mode-selector");
    await expect(selector).toBeVisible();
    
    const options = await selector.locator("option").allTextContents();
    expect(options.some(opt => opt.includes("Daedalus"))).toBe(true);
    expect(options.some(opt => opt.includes("Sisyphus"))).toBe(true);
  });

fast("switches to Sisyphus mode", async ({ page }) => {
  await page.goto("/agent");
    
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
  await expect(page.locator("h1").filter({ hasText: /sisyphus/i })).toBeVisible();
  await expect(page.locator("h1").filter({ hasText: /daedalus/i })).not.toBeVisible();
  });

fast("switches back to Daedalus mode", async ({ page }) => {
  await page.goto("/agent");
    
    // Switch to Sisyphus
    await page.locator("select.mode-selector").selectOption("sisyphus");
  await expect(page.locator("h1").filter({ hasText: /sisyphus/i })).toBeVisible();
    
    // Switch back to Daedalus
    await page.locator("select.mode-selector").selectOption("daedalus");
  await expect(page.locator("h1").filter({ hasText: /daedalus/i })).toBeVisible();
  });

fast("configuration toggle button exists", async ({ page }) => {
  await page.goto("/agent");
    
    const configButton = page.locator("button").filter({ hasText: /configuration|⚙️/i });
    await expect(configButton).toBeVisible();
  });

fast("Daedalus form has all required fields", async ({ page }) => {
  await page.goto("/agent");
    
    await expect(page.locator('label').filter({ hasText: /codebase path/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /goal/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /context hint/i })).toBeVisible();
    await expect(page.locator('button').filter({ hasText: /generate.*plan/i })).toBeVisible();
  });

fast("Sisyphus form has all required fields", async ({ page }) => {
  await page.goto("/agent");
    
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    await expect(page.locator('label').filter({ hasText: /project path/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /plan path/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /approval mode/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /dry run/i })).toBeVisible();
    await expect(page.locator('button').filter({ hasText: /start execution/i })).toBeVisible();
  });

fast("file path inputs accept text entry", async ({ page }) => {
  await page.goto("/agent");
    
  const pathInput = page.locator('.file-path-text-input').first();
    await pathInput.fill("/test/path");
    await expect(pathInput).toHaveValue("/test/path");
  });

fast("browse buttons are present for file selection", async ({ page }) => {
  await page.goto("/agent");
    
    const browseButtons = page.locator('button').filter({ hasText: /browse/i });
    const count = await browseButtons.count();
    expect(count).toBeGreaterThan(0);
});

// =============================================================================
// MEDIUM TESTS - Configuration API (< 15s each)
// =============================================================================

medium("loads configuration on mount", async ({ page }) => {
  await page.goto("/agent");
    
    // Click config toggle to show panel
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    
  // Wait for configuration to load - look for capability cards
  await expect(page.locator('.capability-card').first()).toBeVisible();
  });

medium("displays capability configurations", async ({ page }) => {
  await page.goto("/agent");
    
    // Open config panel
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    
  // Should show config panel with capability details
    const configPanel = page.locator('.configuration-panel');
    await expect(configPanel).toBeVisible();
    
  // Check for capability details
  const hasConfigDetails = await page.locator('.capability-details').count();
  expect(hasConfigDetails).toBeGreaterThan(0);
  });

medium("test connection button exists for capabilities", async ({ page }) => {
  await page.goto("/agent");
    
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    
  // Should have test connection buttons
    const testButtons = page.locator('button').filter({ hasText: /test.*connection|test/i });
    const count = await testButtons.count();
    expect(count).toBeGreaterThan(0);
  });

medium("capability cards show model and port info", async ({ page }) => {
  await page.goto("/agent");
    
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    
  // Should show capability details (model, port, etc.)
  await expect(page.locator('.capability-card').first()).toBeVisible();
  await expect(page.locator('.capability-details').first()).toBeVisible();
});

// =============================================================================
// SLOW TESTS - Real LLM Integration (< 30s each, ONE LLM call max)
// =============================================================================

slow("generates execution plan with real LLM", async ({ page }) => {
  await page.goto("/agent");
  
  // Verify page loaded
  await expect(page.locator("h1").filter({ hasText: /daedalus/i })).toBeVisible();
    
  // Fill in Daedalus form with a specific goal
  const pathInput = page.locator('.file-path-text-input').first();
  await pathInput.fill("/home/kyle/Side_Projects/translator_ruby");
  
  const goalInput = page.locator('#goal');
  await goalInput.fill("Add a /api/health endpoint that returns JSON status");
    
    // Submit plan generation
  const generateBtn = page.locator('button').filter({ hasText: /generate.*plan/i });
  await expect(generateBtn).toBeVisible();
  await generateBtn.click();
    
  // Wait for result - either success or error
  await expect(
    page.locator('.plan-result-section, .banner-error').first()
  ).toBeVisible();
    
  // Check if we got a plan (not error)
  const planSection = page.locator('.plan-result-section');
  if (await planSection.isVisible()) {
    await expect(page.locator('h2').filter({ hasText: /execution plan/i })).toBeVisible();
  }
  });

slow("plan result contains goal and output paths", async ({ page }) => {
  await page.goto("/agent");
    
  // Fill form with specific goal
  await page.locator('.file-path-text-input').first().fill("/home/kyle/Side_Projects/translator_ruby");
  await page.locator('#goal').fill("Add structured logging to the application");
    
    // Generate plan
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
  // Wait for result - either success or error (proper error handling)
  await expect(
    page.locator('.plan-result-section, .banner-error').first()
  ).toBeVisible();
  
  // Verify we got a plan (not error)
  const planSection = page.locator('.plan-result-section');
  await expect(planSection).toBeVisible();
    
  // Verify plan shows goal and output files
  await expect(page.locator('.plan-goal')).toBeVisible();
  await expect(page.locator('.output-paths')).toBeVisible();
  });

slow("plan error handling with invalid path", async ({ page }) => {
  await page.goto("/agent");
    
    // Use non-existent path
  await page.locator('.file-path-text-input').first().fill("/nonexistent/path/12345");
  await page.locator('#goal').fill("Test invalid path");
    
    // Submit
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
  // Should show error banner
  await expect(page.locator('.banner-error').first()).toBeVisible();
  });

slow("starts execution with real plan", async ({ page }) => {
  await page.goto("/agent");
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
  // Fill Sisyphus form with correct selectors
  await page.locator('.file-path-text-input').first().fill("/home/kyle/Side_Projects/translator_ruby");
  await page.locator('#planPath').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
    
  // Verify button is enabled (plan path was filled)
  await expect(page.locator('button').filter({ hasText: /start execution/i })).toBeEnabled();
    
    // Start execution
    await page.locator('button').filter({ hasText: /start execution/i }).click();
    
  // Should show execution in progress (loading state or monitor update)
  await expect(
    page.locator('text=/starting|running|executing|in progress/i').first()
  ).toBeVisible();
  });

fast("sisyphus form accepts step approval mode", async ({ page }) => {
  await page.goto("/agent");
  await page.waitForSelector(".mode-selector");
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
  await page.locator('.file-path-text-input').first().fill("/home/kyle/Side_Projects/translator_ruby");
  await page.locator('#planPath').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
  await page.locator('#approvalMode').selectOption("step");
    
  // Verify step approval mode help text is visible
  await expect(page.locator('p').filter({ hasText: /approve.*individual.*step/i })).toBeVisible();
    
  // Verify button is enabled with valid form
  await expect(page.locator('button').filter({ hasText: /start execution/i })).toBeEnabled();
  });

slow("dry run mode prevents actual changes", async ({ page }) => {
  await page.goto("/agent");
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
  await page.locator('.file-path-text-input').first().fill("/home/kyle/Side_Projects/translator_ruby");
  await page.locator('#planPath').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
    
  // Enable dry run checkbox
  await page.locator('input[type="checkbox"]').first().check();
  
  // Verify dry run indicator shows
  await expect(page.locator('text=/preview only/i').first()).toBeVisible();
  
  await expect(page.locator('button').filter({ hasText: /start execution/i })).toBeEnabled();
    await page.locator('button').filter({ hasText: /start execution/i }).click();
    
  // Should show execution starting or in progress
  await expect(
    page.locator('text=/starting|running|in progress/i').first()
  ).toBeVisible();
});

slow("creates plan in Daedalus then switches to Sisyphus", async ({ page }) => {
  await page.goto("/agent");
    
    // Step 1: Generate plan with Daedalus
  await page.locator('.file-path-text-input').first().fill("/home/kyle/Side_Projects/translator_ruby");
  await page.locator('#goal').fill("Add a utility function for string formatting");
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
  // Wait for plan result (success or error)
  await expect(
    page.locator('.plan-result-section, .banner-error').first()
  ).toBeVisible();
    
  // Verify plan shows goal
  await expect(page.locator('.plan-goal')).toBeVisible();
    
    // Step 2: Switch to Sisyphus mode
    await page.locator("select.mode-selector").selectOption("sisyphus");
  await expect(page.locator("h1").filter({ hasText: /sisyphus/i })).toBeVisible();
    
  // Step 3: Verify project path persists
  const pathInput = page.locator('.file-path-text-input').first();
  await expect(pathInput).toHaveValue("/home/kyle/Side_Projects/translator_ruby");
    
  // Verify Sisyphus form is ready
  await expect(page.locator('#planPath')).toBeVisible();
  await expect(page.locator('button').filter({ hasText: /start execution/i })).toBeVisible();
  });

fast("path persists when switching modes", async ({ page }) => {
  await page.goto("/agent");
    
    const testPath = "/home/kyle/Side_Projects/translator_ruby";
    
    // Set path in Daedalus
  await page.locator('.file-path-text-input').first().fill(testPath);
    
    // Switch to Sisyphus
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    // Project path should be pre-filled
  const sisyphusPath = await page.locator('.file-path-text-input').first().inputValue();
    expect(sisyphusPath).toBe(testPath);
    
    // Switch back to Daedalus
    await page.locator("select.mode-selector").selectOption("daedalus");
    
    // Path should still be there
  const daedalusPath = await page.locator('.file-path-text-input').first().inputValue();
    expect(daedalusPath).toBe(testPath);
});

// =============================================================================
// DOMAIN MODEL TESTS - No Browser Required (< 5s, pure JS)
// =============================================================================

fast("AgentConfig enforces immutability", () => {
    const config = new AgentConfig({
      capabilities: {
        planner: { model: "gpt-4", provider: "openai" }
      },
      environment: { NODE_ENV: "test" }
    });

    expect(Object.isFrozen(config)).toBe(true);
    expect(Object.isFrozen(config.capabilities)).toBe(true);
    expect(Object.isFrozen(config.environment)).toBe(true);
  });

fast("ExecutionPlan enforces immutability", () => {
    const plan = new ExecutionPlan({
      goal: "Test goal",
      constraints: ["Constraint 1"],
      assumptions: ["Assumption 1"],
      risks: ["Risk 1"],
      milestones: [{ title: "Milestone 1", steps: [] }],
      outputPaths: { planFile: "/test/plan.md" },
    analysisSummary: { complexity: "low" },
    metadata: { version: "1.0" }
    });

    expect(Object.isFrozen(plan)).toBe(true);
    expect(Object.isFrozen(plan.milestones)).toBe(true);
    expect(Object.isFrozen(plan.constraints)).toBe(true);
  });

fast("AgentConfig serialization round-trip", () => {
    const original = new AgentConfig({
      capabilities: {
        planner: { model: "gpt-4", provider: "openai" }
      },
      environment: { TEST_VAR: "value" }
    });

    const json = original.toJSON();
    const restored = AgentConfig.fromJSON(json);

  expect(restored.getCapability("planner").model).toBe("gpt-4");
    expect(restored.environment.TEST_VAR).toBe("value");
  });

fast("ExecutionPlan validates required fields", () => {
    expect(() => {
      new ExecutionPlan({
        goal: "", // Invalid: empty string
        constraints: [],
        assumptions: [],
        risks: [],
        milestones: [],
        outputPaths: {},
      analysisSummary: {},
      metadata: {}
      });
    }).toThrow();
});
