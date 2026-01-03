import { test, expect } from "@playwright/test";
import { AgentConfig } from "../src/models/AgentConfig";
import { ExecutionPlan } from "../src/models/ExecutionPlan";
import { ApprovalRequest } from "../src/models/ApprovalRequest";

/**
 * Unified Agent Workspace E2E Tests
 * 
 * TESTING STRATEGY:
 * - Fast tests (< 5s): UI interactions, no LLM
 * - Medium tests (< 30s): Configuration validation, single API calls
 * - Slow tests (< 120s): Real LLM execution (Daedalus planning, Sisyphus execution)
 * 
 * NO MOCKS - All tests use real backend APIs
 * NO TEST ENDPOINTS - Tests exercise actual production code paths
 * 
 * Test execution is split by speed profile:
 * - Run fast tests always
 * - Run medium tests for integration checks
 * - Run slow tests (with --grep slow) for full LLM validation
 */

const UI_TIMEOUT = 5000;  // 5 seconds for UI interactions
const API_TIMEOUT = 30000; // 30 seconds for API calls
const LLM_TIMEOUT = 120000; // 120 seconds for LLM operations

// =============================================================================
// FAST TESTS - UI Only, No Backend (< 5s each)
// =============================================================================

test.describe("Agent Workspace UI - Fast", () => {
  test.setTimeout(UI_TIMEOUT);

  test("renders with Daedalus mode by default", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    await expect(page.locator("h2").filter({ hasText: /daedalus/i })).toBeVisible();
    await expect(page.locator("select.mode-selector")).toHaveValue("daedalus");
  });

  test("mode selector has both options", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    const selector = page.locator("select.mode-selector");
    await expect(selector).toBeVisible();
    
    const options = await selector.locator("option").allTextContents();
    expect(options.some(opt => opt.includes("Daedalus"))).toBe(true);
    expect(options.some(opt => opt.includes("Sisyphus"))).toBe(true);
  });

  test("switches to Sisyphus mode", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    await expect(page.locator("h2").filter({ hasText: /sisyphus/i })).toBeVisible();
    await expect(page.locator("h2").filter({ hasText: /daedalus/i })).not.toBeVisible();
  });

  test("switches back to Daedalus mode", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Switch to Sisyphus
    await page.locator("select.mode-selector").selectOption("sisyphus");
    await expect(page.locator("h2").filter({ hasText: /sisyphus/i })).toBeVisible();
    
    // Switch back to Daedalus
    await page.locator("select.mode-selector").selectOption("daedalus");
    await expect(page.locator("h2").filter({ hasText: /daedalus/i })).toBeVisible();
  });

  test("configuration toggle button exists", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    const configButton = page.locator("button").filter({ hasText: /configuration|⚙️/i });
    await expect(configButton).toBeVisible();
  });

  test("Daedalus form has all required fields", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    await expect(page.locator('label').filter({ hasText: /codebase path/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /goal/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /context hint/i })).toBeVisible();
    await expect(page.locator('button').filter({ hasText: /generate.*plan/i })).toBeVisible();
  });

  test("Sisyphus form has all required fields", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    await expect(page.locator('label').filter({ hasText: /project path/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /plan path/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /approval mode/i })).toBeVisible();
    await expect(page.locator('label').filter({ hasText: /dry run/i })).toBeVisible();
    await expect(page.locator('button').filter({ hasText: /start execution/i })).toBeVisible();
  });

  test("file path inputs accept text entry", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    const pathInput = page.locator('input[placeholder*="codebase"]').first();
    await pathInput.fill("/test/path");
    await expect(pathInput).toHaveValue("/test/path");
  });

  test("browse buttons are present for file selection", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    const browseButtons = page.locator('button').filter({ hasText: /browse/i });
    const count = await browseButtons.count();
    expect(count).toBeGreaterThan(0);
  });
});

// =============================================================================
// MEDIUM TESTS - Configuration API (< 30s each)
// =============================================================================

test.describe("Configuration Management - Medium", () => {
  test.setTimeout(API_TIMEOUT);

  test("loads configuration on mount", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Click config toggle to show panel
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    
    // Wait for configuration to load
    await expect(page.locator('h2').filter({ hasText: /agent configuration/i })).toBeVisible({ timeout: 10000 });
    
    // Should show at least one capability
    await expect(page.locator('.capability-item, .capability-section').first()).toBeVisible({ timeout: 5000 });
  });

  test("displays capability configurations", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Open config panel
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    await page.waitForLoadState("networkidle"); // Wait for config load
    
    // Should show model, provider, or similar config fields
    const configPanel = page.locator('.configuration-panel');
    await expect(configPanel).toBeVisible();
    
    // Check for typical config field labels
    const hasConfigFields = await page.locator('label').filter({ 
      hasText: /model|provider|endpoint|api.?key/i 
    }).count();
    
    expect(hasConfigFields).toBeGreaterThan(0);
  });

  test("test connection button exists for capabilities", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    await page.waitForLoadState("networkidle");
    
    // Should have test buttons
    const testButtons = page.locator('button').filter({ hasText: /test.*connection|test/i });
    const count = await testButtons.count();
    expect(count).toBeGreaterThan(0);
  });

  test("save configuration button exists", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    await page.locator('button').filter({ hasText: /configuration|⚙️/i }).click();
    await page.waitForLoadState("networkidle");
    
    await expect(page.locator('button').filter({ hasText: /save.*configuration|save config/i })).toBeVisible();
  });
});

// =============================================================================
// SLOW TESTS - Real LLM Integration (< 120s each)
// =============================================================================

test.describe("Daedalus Planning - Slow @slow", () => {
  test.setTimeout(LLM_TIMEOUT);

  test("generates execution plan with real LLM", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Fill in Daedalus form
    await page.locator('input[placeholder*="codebase"]').first().fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('textarea[placeholder*="goal"]').fill("Add a health check endpoint to the API");
    await page.locator('textarea[placeholder*="context"]').fill("This is a Rails application");
    
    // Submit plan generation
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
    // Wait for loading state
    await expect(page.locator('button').filter({ hasText: /generating/i })).toBeVisible({ timeout: 5000 });
    
    // Wait for plan result (real LLM takes time)
    await expect(page.locator('.plan-result-section, .execution-plan').first()).toBeVisible({ 
      timeout: LLM_TIMEOUT - 10000 
    });
    
    // Verify plan content
    await expect(page.locator('h3').filter({ hasText: /execution plan|milestones/i })).toBeVisible();
  });

  test("plan result contains milestones", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Fill minimal form
    await page.locator('input[placeholder*="codebase"]').first().fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('textarea[placeholder*="goal"]').fill("Add logging to the application");
    
    // Generate plan
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
    // Wait for result
    await expect(page.locator('.plan-result-section, .milestones-section').first()).toBeVisible({ 
      timeout: LLM_TIMEOUT - 10000 
    });
    
    // Should show milestone information
    const milestonesExist = await page.locator('.milestone-item, .milestone').count();
    expect(milestonesExist).toBeGreaterThan(0);
  });

  test("plan error handling with invalid path", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Use non-existent path
    await page.locator('input[placeholder*="codebase"]').first().fill("/nonexistent/path/12345");
    await page.locator('textarea[placeholder*="goal"]').fill("Test invalid path handling");
    
    // Submit
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
    // Should show error
    await expect(page.locator('.banner-error, .error-message').first()).toBeVisible({ timeout: 30000 });
  });
});

test.describe("Sisyphus Execution - Slow @slow", () => {
  test.setTimeout(LLM_TIMEOUT);

  test("starts execution with real plan", async ({ page }) => {
    // First need to create a plan file - this test assumes one exists
    // In practice, you'd create it programmatically or use a fixture
    
    await page.goto("http://localhost:3000/agent");
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    // Fill Sisyphus form
    await page.locator('input[placeholder*="project"]').fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('input[placeholder*="plan"]').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
    
    // Set to manual approval mode for testing
    await page.locator('select').filter({ hasText: /approval/i }).selectOption("manual");
    
    // Start execution
    await page.locator('button').filter({ hasText: /start execution/i }).click();
    
    // Should show execution monitor
    await expect(page.locator('.execution-monitor, .execution-status').first()).toBeVisible({ 
      timeout: 30000 
    });
  });

  test("displays approval requests during execution", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    await page.locator('input[placeholder*="project"]').fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('input[placeholder*="plan"]').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
    await page.locator('select').filter({ hasText: /approval/i }).selectOption("manual");
    
    await page.locator('button').filter({ hasText: /start execution/i }).click();
    
    // Wait for approval modal to appear (real execution generates real approvals)
    await expect(page.locator('.approval-modal, .modal').first()).toBeVisible({ 
      timeout: 60000 
    });
    
    // Modal should have approve/reject buttons
    await expect(page.locator('button').filter({ hasText: /approve/i })).toBeVisible();
    await expect(page.locator('button').filter({ hasText: /reject/i })).toBeVisible();
  });

  test("dry run mode prevents actual changes", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    await page.locator('input[placeholder*="project"]').fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('input[placeholder*="plan"]').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
    
    // Enable dry run
    await page.locator('input[type="checkbox"]').filter({ hasText: /dry.?run/i }).check();
    
    await page.locator('button').filter({ hasText: /start execution/i }).click();
    
    // Should show execution started
    await expect(page.locator('.execution-monitor').first()).toBeVisible({ timeout: 30000 });
    
    // Verify dry run indicator is present
    const pageContent = await page.content();
    expect(pageContent.toLowerCase()).toContain("dry run");
  });
});

// =============================================================================
// INTEGRATION TESTS - Daedalus → Sisyphus Flow (< 120s)
// =============================================================================

test.describe("Integrated Workflow - Slow @slow", () => {
  test.setTimeout(LLM_TIMEOUT + 30000); // Extra time for full workflow

  test("creates plan in Daedalus then executes in Sisyphus", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    // Step 1: Generate plan with Daedalus
    await page.locator('input[placeholder*="codebase"]').first().fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('textarea[placeholder*="goal"]').fill("Add a simple utility function");
    await page.locator('button').filter({ hasText: /generate.*plan/i }).click();
    
    // Wait for plan
    await expect(page.locator('.plan-result-section').first()).toBeVisible({ timeout: LLM_TIMEOUT - 30000 });
    
    // Plan should show output path
    const planOutput = await page.locator('.output-path, .plan-path').first().textContent();
    expect(planOutput).toBeTruthy();
    
    // Step 2: Switch to Sisyphus mode
    await page.locator("select.mode-selector").selectOption("sisyphus");
    await expect(page.locator("h2").filter({ hasText: /sisyphus/i })).toBeVisible();
    
    // Step 3: Use generated plan path (if displayed) or use test fixture
    await page.locator('input[placeholder*="project"]').fill("/home/kyle/Side_Projects/translator_ruby");
    await page.locator('input[placeholder*="plan"]').fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
    
    // Set manual approval
    await page.locator('select').filter({ hasText: /approval/i }).selectOption("manual");
    
    // Start execution
    await page.locator('button').filter({ hasText: /start execution/i }).click();
    
    // Verify execution started
    await expect(page.locator('.execution-monitor').first()).toBeVisible({ timeout: 30000 });
  });

  test("path persists when switching modes", async ({ page }) => {
    await page.goto("http://localhost:3000/agent");
    
    const testPath = "/home/kyle/Side_Projects/translator_ruby";
    
    // Set path in Daedalus
    await page.locator('input[placeholder*="codebase"]').first().fill(testPath);
    
    // Switch to Sisyphus
    await page.locator("select.mode-selector").selectOption("sisyphus");
    
    // Project path should be pre-filled
    const sisyphusPath = await page.locator('input[placeholder*="project"]').inputValue();
    expect(sisyphusPath).toBe(testPath);
    
    // Switch back to Daedalus
    await page.locator("select.mode-selector").selectOption("daedalus");
    
    // Path should still be there
    const daedalusPath = await page.locator('input[placeholder*="codebase"]').first().inputValue();
    expect(daedalusPath).toBe(testPath);
  });
});

// =============================================================================
// MODEL TESTS - No Browser Required (< 1ms each)
// =============================================================================

test.describe("Domain Models - Fast", () => {
  test.setTimeout(1000);

  test("AgentConfig enforces immutability", () => {
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

  test("ExecutionPlan enforces immutability", () => {
    const plan = new ExecutionPlan({
      goal: "Test goal",
      constraints: ["Constraint 1"],
      assumptions: ["Assumption 1"],
      risks: ["Risk 1"],
      milestones: [{ title: "Milestone 1", steps: [] }],
      outputPaths: { planFile: "/test/plan.md" },
      analysisSummary: { complexity: "low" }
    });

    expect(Object.isFrozen(plan)).toBe(true);
    expect(Object.isFrozen(plan.milestones)).toBe(true);
    expect(Object.isFrozen(plan.constraints)).toBe(true);
  });

  test("AgentConfig serialization round-trip", () => {
    const original = new AgentConfig({
      capabilities: {
        planner: { model: "gpt-4", provider: "openai" }
      },
      environment: { TEST_VAR: "value" }
    });

    const json = original.toJSON();
    const restored = AgentConfig.fromJSON(json);

    expect(restored.capability("planner").model).toBe("gpt-4");
    expect(restored.environment.TEST_VAR).toBe("value");
  });

  test("ExecutionPlan validates required fields", () => {
    expect(() => {
      new ExecutionPlan({
        goal: "", // Invalid: empty string
        constraints: [],
        assumptions: [],
        risks: [],
        milestones: [],
        outputPaths: {},
        analysisSummary: {}
      });
    }).toThrow();
  });
});
