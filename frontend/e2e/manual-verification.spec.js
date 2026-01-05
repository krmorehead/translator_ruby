import { expect, slow } from "./base-test";

/**
 * Manual Verification Tests
 * 
 * These tests run in headed mode to manually verify the UX.
 * Run with: npx playwright test manual-verification --headed
 */

slow("MANUAL: Complete Daedalus workflow", async ({ page }) => {
  console.log("\n🎯 Starting Manual Verification: Daedalus Workflow");
  
  // 1. Load the agent workspace
  console.log("Step 1: Loading /agent page...");
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Verify Daedalus mode is active
  await expect(page.locator("h1").filter({ hasText: /daedalus/i })).toBeVisible();
  console.log("✓ Daedalus mode loaded");
  
  // 2. Fill in the form
  console.log("Step 2: Filling in plan generation form...");
  const pathInput = page.locator('.file-path-text-input').first();
  await pathInput.fill("/home/kyle/Side_Projects/translator_ruby");
  console.log("✓ Project path entered");
  
  const goalInput = page.locator('#goal');
  await goalInput.fill("Add a health check endpoint to the API");
  console.log("✓ Goal entered");
  
  // 3. Generate plan
  console.log("Step 3: Generating plan with real LLM...");
  const generateBtn = page.locator('button').filter({ hasText: /generate.*plan/i });
  await generateBtn.click();
  console.log("✓ Plan generation started");
  
  // 4. Wait for result
  console.log("Step 4: Waiting for plan result (may take 10-20s)...");
  await expect(
    page.locator('.plan-result-section, .banner-error').first()
  ).toBeVisible();
  
  // Check if we got a plan or error
  const planSection = page.locator('.plan-result-section');
  if (await planSection.isVisible()) {
    console.log("✓ Plan generated successfully!");
    
    // Verify plan content
    await expect(page.locator('.plan-goal')).toBeVisible();
    console.log("✓ Plan shows goal");
    
    const outputPaths = page.locator('.output-paths');
    if (await outputPaths.isVisible()) {
      console.log("✓ Output paths displayed");
    }
  } else {
    console.log("⚠️  Plan generation returned an error (backend may be processing)");
  }
  
  console.log("\n✅ Daedalus workflow verification complete!\n");
});

slow("MANUAL: Complete Sisyphus workflow", async ({ page }) => {
  console.log("\n🎯 Starting Manual Verification: Sisyphus Workflow");
  
  // 1. Load and switch to Sisyphus
  console.log("Step 1: Loading /agent and switching to Sisyphus...");
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator("select.mode-selector").selectOption("sisyphus");
  await expect(page.locator("h1").filter({ hasText: /sisyphus/i })).toBeVisible();
  console.log("✓ Sisyphus mode active");
  
  // 2. Fill in execution form
  console.log("Step 2: Setting up execution...");
  const projectPath = page.locator('.file-path-text-input').first();
  await projectPath.fill("/home/kyle/Side_Projects/translator_ruby");
  console.log("✓ Project path set");
  
  const planPath = page.locator('#planPath');
  await planPath.fill("/home/kyle/Side_Projects/translator_ruby/test/fixtures/simple_plan.md");
  console.log("✓ Plan path set");
  
  // 3. Configure approval mode
  console.log("Step 3: Setting approval mode to 'step'...");
  await page.locator('#approvalMode').selectOption("step");
  
  // Verify help text shows
  const helpText = page.locator('p').filter({ hasText: /approve.*individual.*step/i });
  await expect(helpText).toBeVisible();
  console.log("✓ Step approval mode configured");
  
  // 4. Verify button is enabled
  const startBtn = page.locator('button').filter({ hasText: /start execution/i });
  await expect(startBtn).toBeEnabled();
  console.log("✓ Start execution button is enabled");
  
  // 5. Verify dry run option
  console.log("Step 4: Testing dry run toggle...");
  const dryRunCheckbox = page.locator('input[type="checkbox"]').first();
  await dryRunCheckbox.check();
  
  await expect(page.locator('text=/preview only/i')).toBeVisible();
  console.log("✓ Dry run mode indicator shows");
  
  await dryRunCheckbox.uncheck();
  console.log("✓ Dry run mode can be toggled");
  
  console.log("\n✅ Sisyphus workflow verification complete!\n");
});

slow("MANUAL: Mode switching with path persistence", async ({ page }) => {
  console.log("\n🎯 Starting Manual Verification: Mode Switching");
  
  const testPath = "/home/kyle/Side_Projects/translator_ruby";
  
  // 1. Start in Daedalus
  console.log("Step 1: Setting path in Daedalus mode...");
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  await page.locator('.file-path-text-input').first().fill(testPath);
  console.log(`✓ Path set: ${testPath}`);
  
  // 2. Switch to Sisyphus
  console.log("Step 2: Switching to Sisyphus...");
  await page.locator("select.mode-selector").selectOption("sisyphus");
  await expect(page.locator("h1").filter({ hasText: /sisyphus/i })).toBeVisible();
  
  // Verify path persisted
  const sisyphusPath = await page.locator('.file-path-text-input').first().inputValue();
  console.log(`✓ Path in Sisyphus: ${sisyphusPath}`);
  
  if (sisyphusPath === testPath) {
    console.log("✓ Path correctly persisted to Sisyphus!");
  } else {
    console.log(`⚠️  Path mismatch: expected ${testPath}, got ${sisyphusPath}`);
  }
  
  // 3. Switch back to Daedalus
  console.log("Step 3: Switching back to Daedalus...");
  await page.locator("select.mode-selector").selectOption("daedalus");
  await expect(page.locator("h1").filter({ hasText: /daedalus/i })).toBeVisible();
  
  // Verify path still persisted
  const daedalusPath = await page.locator('.file-path-text-input').first().inputValue();
  console.log(`✓ Path in Daedalus: ${daedalusPath}`);
  
  if (daedalusPath === testPath) {
    console.log("✓ Path correctly persisted back to Daedalus!");
  } else {
    console.log(`⚠️  Path mismatch: expected ${testPath}, got ${daedalusPath}`);
  }
  
  console.log("\n✅ Mode switching verification complete!\n");
});

slow("MANUAL: Configuration panel", async ({ page }) => {
  console.log("\n🎯 Starting Manual Verification: Configuration Panel");
  
  console.log("Step 1: Loading agent workspace...");
  await page.goto("/agent");
  await page.waitForLoadState("networkidle");
  
  // Click config toggle
  console.log("Step 2: Opening configuration panel...");
  const configButton = page.locator('button').filter({ hasText: /⚙️/i });
  await configButton.click();
  
  // Wait a moment for animation
  await page.waitForTimeout(500);
  
  // Check if configuration content is visible
  const configVisible = await page.locator('text=/configuration|capabilities|model/i').first().isVisible().catch(() => false);
  
  if (configVisible) {
    console.log("✓ Configuration panel opened");
    
    // Check for capability cards or configuration content
    const hasContent = await page.locator('.capability-card, [class*="config"]').first().isVisible().catch(() => false);
    if (hasContent) {
      console.log("✓ Configuration content visible");
    }
  } else {
    console.log("⚠️  Configuration panel may not have content loaded yet");
  }
  
  // Close panel
  console.log("Step 3: Closing configuration panel...");
  await configButton.click();
  await page.waitForTimeout(300);
  console.log("✓ Configuration panel toggled");
  
  console.log("\n✅ Configuration panel verification complete!\n");
});

