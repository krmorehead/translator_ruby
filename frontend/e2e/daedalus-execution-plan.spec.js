import { expect, slow } from "./base-test";
import fs from "fs";
import path from "path";

/**
 * Daedalus Execution Plan E2E Tests
 * 
 * SPEED PROFILE: slow (Real LLM integration)
 * - Tests full stack: Frontend → Backend → LLM → Response
 * - Uses real example_codebase fixture
 * - Follows NO MOCKING policy
 * - Follows OOP principles
 * 
 * Tests verify that Daedalus can:
 * 1. Analyze a real codebase
 * 2. Generate a proper execution plan
 * 3. Create structured output with milestones and steps
 * 4. Provide analysis summary and output paths
 */

const EXAMPLE_CODEBASE_PATH = path.resolve(__dirname, "../../test/fixtures/example_codebase");

slow("daedalus - generates execution plan for adding logging feature", async ({ page }) => {
  console.log("\n🎯 Testing Daedalus Execution Plan Generation with Real LLM");
  console.log("=" .repeat(80));
  
  // Verify example codebase exists
  if (!fs.existsSync(EXAMPLE_CODEBASE_PATH)) {
    throw new Error(`Example codebase not found at: ${EXAMPLE_CODEBASE_PATH}`);
  }
  console.log(`✓ Example codebase found at: ${EXAMPLE_CODEBASE_PATH}`);
  
  // Navigate to agent workspace in Daedalus mode
  console.log("\nStep 1: Navigate to Daedalus mode");
  await page.goto("/agent?mode=daedalus");
  console.log("✓ Navigated to /agent?mode=daedalus");
  
  // Verify Daedalus form is visible
  await expect(page.locator('form.plan-form')).toBeVisible();
  console.log("✓ Daedalus form rendered");
  
  // Fill in goal
  console.log("\nStep 2: Fill in goal and codebase path");
  const goalText = "Add logging functionality to the Calculator class to track all arithmetic operations";
  await page.locator('textarea#goal').fill(goalText);
  console.log(`✓ Goal set: "${goalText}"`);
  
  // Fill in codebase path
  await page.locator('input[placeholder*="/path/to/your/codebase"]').fill(EXAMPLE_CODEBASE_PATH);
  console.log(`✓ Codebase path set: ${EXAMPLE_CODEBASE_PATH}`);
  
  // Optional: Add context hint
  const contextHint = "Focus on lib/calculator.rb and consider creating a new Logger class";
  await page.locator('input#contextHint').fill(contextHint);
  console.log(`✓ Context hint set: "${contextHint}"`);
  
  // Submit form
  console.log("\nStep 3: Generate execution plan (calling real LLM)");
  const generateBtn = page.locator('button.btn-primary').filter({ hasText: /generate.*execution.*plan/i });
  await expect(generateBtn).toBeEnabled();
  await generateBtn.click();
  console.log("✓ Form submitted, waiting for LLM response...");
  
  // Wait for loading state
  await expect(page.locator('button').filter({ hasText: /generating.*plan/i })).toBeVisible();
  console.log("✓ Loading state active");
  
  // Wait for results (LLM processing can take time)
  console.log("⏳ Waiting for LLM to analyze codebase and generate plan...");
  await expect(page.locator('.execution-plan')).toBeVisible({ timeout: 25000 });
  console.log("✓ Execution plan received!");
  
  // Verify plan structure
  console.log("\nStep 4: Verify execution plan structure");
  
  // Should have goal section
  await expect(page.locator('.plan-header')).toBeVisible();
  console.log("✓ Plan header present");
  
  // Should have constraints
  await expect(page.locator('.section-title').filter({ hasText: /constraints/i })).toBeVisible();
  console.log("✓ Constraints section present");
  
  // Should have assumptions
  await expect(page.locator('.section-title').filter({ hasText: /assumptions/i })).toBeVisible();
  console.log("✓ Assumptions section present");
  
  // Should have risks
  await expect(page.locator('.section-title').filter({ hasText: /risks/i })).toBeVisible();
  console.log("✓ Risks section present");
  
  // Should have milestones
  await expect(page.locator('.section-title').filter({ hasText: /milestones/i })).toBeVisible();
  console.log("✓ Milestones section present");
  
  // Verify milestones have steps
  const milestoneCount = await page.locator('.milestone-item').count();
  console.log(`✓ Found ${milestoneCount} milestone(s)`);
  expect(milestoneCount).toBeGreaterThanOrEqual(1);
  
  // Check that at least one milestone has steps
  const firstMilestone = page.locator('.milestone-item').first();
  await expect(firstMilestone.locator('.milestone-title')).toBeVisible();
  
  const stepCount = await firstMilestone.locator('.step-item').count();
  console.log(`✓ First milestone has ${stepCount} step(s)`);
  expect(stepCount).toBeGreaterThanOrEqual(1);
  
  // Verify output paths section
  await expect(page.locator('.section-title').filter({ hasText: /output.*paths/i })).toBeVisible();
  console.log("✓ Output paths section present");
  
  // Verify analysis summary
  await expect(page.locator('.section-title').filter({ hasText: /analysis.*summary/i })).toBeVisible();
  console.log("✓ Analysis summary present");
  
  // Verify metadata is shown
  await expect(page.locator('.metadata-section')).toBeVisible();
  console.log("✓ Metadata section present");
  
  console.log("\n" + "=".repeat(80));
  console.log("✅ Daedalus execution plan generation test complete!");
  console.log("   ✓ Full stack test with real LLM");
  console.log("   ✓ Analyzed real example codebase");
  console.log("   ✓ Generated structured execution plan");
  console.log("   ✓ All required sections present");
  console.log("=" .repeat(80));
});

slow("daedalus - reset clears form and results", async ({ page }) => {
  console.log("\n🎯 Testing Daedalus Reset Functionality");
  
  await page.goto("/agent?mode=daedalus");
  
  // Fill in some data
  await page.locator('textarea#goal').fill("Test goal");
  await page.locator('input[placeholder*="/path/to/your/codebase"]').fill("/test/path");
  
  // Verify data is present
  await expect(page.locator('textarea#goal')).toHaveValue("Test goal");
  console.log("✓ Form filled with test data");
  
  // Click reset
  const resetBtn = page.locator('button.btn-secondary').filter({ hasText: /reset/i });
  await resetBtn.click();
  console.log("✓ Reset button clicked");
  
  // Verify form is cleared
  await expect(page.locator('textarea#goal')).toHaveValue("");
  console.log("✓ Form cleared successfully");
  
  console.log("✅ Reset functionality test complete!");
});

slow("daedalus - validates required fields", async ({ page }) => {
  console.log("\n🎯 Testing Daedalus Form Validation");
  
  await page.goto("/agent?mode=daedalus");
  
  // Generate button should be disabled without goal and path
  const generateBtn = page.locator('button.btn-primary').filter({ hasText: /generate.*execution.*plan/i });
  await expect(generateBtn).toBeDisabled();
  console.log("✓ Generate button disabled when form empty");
  
  // Add goal only
  await page.locator('textarea#goal').fill("Add logging");
  await expect(generateBtn).toBeDisabled();
  console.log("✓ Generate button still disabled with only goal");
  
  // Add path
  await page.locator('input[placeholder*="/path/to/your/codebase"]').fill(EXAMPLE_CODEBASE_PATH);
  await expect(generateBtn).toBeEnabled();
  console.log("✓ Generate button enabled with both goal and path");
  
  console.log("✅ Form validation test complete!");
});

slow("daedalus - displays error for invalid codebase path", async ({ page }) => {
  console.log("\n🎯 Testing Daedalus Error Handling");
  
  await page.goto("/agent?mode=daedalus");
  
  // Fill in goal and invalid path
  await page.locator('textarea#goal').fill("Test goal");
  await page.locator('input[placeholder*="/path/to/your/codebase"]').fill("/invalid/nonexistent/path");
  console.log("✓ Form filled with invalid path");
  
  // Submit form
  const generateBtn = page.locator('button.btn-primary').filter({ hasText: /generate.*execution.*plan/i });
  await generateBtn.click();
  console.log("✓ Form submitted");
  
  // Should show error
  await expect(page.locator('.banner-error')).toBeVisible({ timeout: 10000 });
  console.log("✓ Error banner displayed");
  
  // Error should mention the invalid path
  const errorText = await page.locator('.banner-error').textContent();
  console.log(`✓ Error message: "${errorText}"`);
  expect(errorText.toLowerCase()).toContain("error");
  
  console.log("✅ Error handling test complete!");
});

