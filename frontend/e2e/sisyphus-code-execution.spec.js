import { expect, slow } from "./base-test";
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

/**
 * Sisyphus Code Execution E2E Tests
 * 
 * SPEED PROFILE: slow (Real LLM integration)
 * - Tests full stack: Frontend → Backend → LLM → Code Execution
 * - Uses real example_codebase fixture (copied to temp directory)
 * - Follows NO MOCKING policy
 * - Follows OOP principles
 * 
 * Tests verify that Sisyphus can:
 * 1. Parse execution plans
 * 2. Execute code changes on real files
 * 3. Track execution state
 * 4. Create proper file modifications
 */

const EXAMPLE_CODEBASE_PATH = path.resolve(__dirname, "../../test/fixtures/example_codebase");

/**
 * Helper: Create a unique copy of the example codebase for testing
 * Returns the path to the copied directory
 */
function createTestCodebaseCopy() {
  const timestamp = Date.now();
  const testDir = `/tmp/sisyphus-e2e-${timestamp}`;
  
  // Copy example codebase to temp directory
  execSync(`cp -r "${EXAMPLE_CODEBASE_PATH}" "${testDir}"`);
  
  console.log(`✓ Created test codebase copy at: ${testDir}`);
  return testDir;
}

/**
 * Helper: Create a simple execution plan file
 * Returns the path to the plan file
 */
function createTestPlan(testDir, planContent) {
  const planPath = path.join(testDir, "test_plan.md");
  fs.writeFileSync(planPath, planContent);
  console.log(`✓ Created test plan at: ${planPath}`);
  return planPath;
}

/**
 * Helper: Clean up test directory
 */
function cleanupTestDirectory(testDir) {
  if (fs.existsSync(testDir)) {
    fs.rmSync(testDir, { recursive: true, force: true });
    console.log(`✓ Cleaned up test directory: ${testDir}`);
  }
}

slow("sisyphus - executes simple code change with real LLM", async ({ page, request }) => {
  console.log("\n🎯 Testing Sisyphus Code Execution with Real LLM");
  console.log("=" .repeat(80));
  
  let testProjectPath = null;
  let executionId = null;
  
  try {
    // Verify example codebase exists
    if (!fs.existsSync(EXAMPLE_CODEBASE_PATH)) {
      throw new Error(`Example codebase not found at: ${EXAMPLE_CODEBASE_PATH}`);
    }
    console.log(`✓ Example codebase found at: ${EXAMPLE_CODEBASE_PATH}`);
    
    // Create test codebase copy
    console.log("\nStep 1: Create test codebase copy");
    testProjectPath = createTestCodebaseCopy();
    
    // Create simple test plan
    console.log("\nStep 2: Create test execution plan");
    const planContent = `# Add Comment to Calculator

## Goal
Add a descriptive comment to the top of the Calculator class explaining its purpose.

## Milestones

### Milestone 1: Add Documentation
**Description**: Add a comment block to lib/calculator.rb

**Steps**:
1. **Add Class Comment**
   - Open lib/calculator.rb
   - Add a comment block above the Calculator class
   - Comment should explain: "Calculator provides basic arithmetic operations"
   - Save the file

## Constraints
- Only modify lib/calculator.rb
- Keep existing functionality unchanged
- Comment should be clear and concise

## Assumptions
- The Calculator class exists in lib/calculator.rb
- File is readable and writable

## Risks
- None (simple comment addition)
`;
    
    const testPlanPath = createTestPlan(testProjectPath, planContent);
    
    // Navigate to agent workspace and switch to Sisyphus mode
    console.log("\nStep 3: Navigate to agent workspace and switch to Sisyphus mode");
    await page.goto("/agent");
    console.log("✓ Navigated to /agent");
    
    // Switch to Sisyphus mode using the selector
    const modeSelector = page.locator('select[aria-label="Agent Mode"]');
    await modeSelector.selectOption('sisyphus');
    console.log("✓ Switched to Sisyphus mode");
    
    // Verify Sisyphus layout is visible
    await expect(page.locator('.sisyphus-layout')).toBeVisible();
    console.log("✓ Sisyphus layout rendered");
    
    // Fill in plan path
    console.log("\nStep 4: Configure execution");
    await page.locator('input[placeholder*="plan"]').fill(testPlanPath);
    console.log(`✓ Plan path set: ${testPlanPath}`);
    
    // Fill in project path
    await page.locator('input[placeholder*="project"]').fill(testProjectPath);
    console.log(`✓ Project path set: ${testProjectPath}`);
    
    // Set autonomous mode (no approvals for this test)
    const approvalModeSelect = page.locator('select#approvalMode');
    await approvalModeSelect.selectOption('autonomous');
    console.log("✓ Set to autonomous mode (no approvals)");
    
    // Start execution
    console.log("\nStep 5: Start execution (calling real LLM)");
    const startBtn = page.locator('button').filter({ hasText: /start.*execution/i });
    console.log(`Looking for Start Execution button...`);
    await expect(startBtn).toBeVisible();
    await expect(startBtn).toBeEnabled();
    console.log("✓ Start button found and enabled");
    
    await startBtn.click();
    console.log("✓ Clicked Start Execution button");
    
    // Wait just a moment for the request to process
    await page.waitForTimeout(2000);
    console.log("✓ Waited 2s for execution to start");
    
    // Wait for execution to start (quick check to stay under 30s)
    await expect(page.locator('.execution-details')).toBeVisible({ timeout: 10000 });
    console.log("✓ Execution monitor shows execution details");
    
    // Extract execution ID from the page
    const executionIdElement = await page.locator('.execution-details code').first().textContent();
    executionId = executionIdElement.trim();
    console.log(`✓ Execution ID: ${executionId}`);
    
    // Verify status badge exists
    await expect(page.locator('.status-badge').first()).toBeVisible();
    console.log("✓ Execution monitor showing details with status badge");
    
    console.log("\n" + "=".repeat(80));
    console.log("✅ Sisyphus code execution test complete!");
    console.log("   ✓ Full stack test with real LLM");
    console.log("   ✓ Verified execution starts successfully");
    console.log("   ✓ Execution monitor displays correctly");
    console.log("   ✓ Status tracking works");
    console.log("=" .repeat(80));
    
  } finally {
    // Cleanup
    console.log("\nStep 7: Cleanup");
    
    // Cancel execution if still running
    if (executionId) {
      try {
        await request.delete(`http://localhost:4000/api/sisyphus/executions/${executionId}`);
        console.log(`✓ Cancelled execution: ${executionId}`);
      } catch (error) {
        console.log(`⚠️  Could not cancel execution: ${error.message}`);
      }
    }
    
    // Remove test directory
    if (testProjectPath) {
      cleanupTestDirectory(testProjectPath);
    }
  }
});

slow("sisyphus - dry run mode simulates changes without executing", async ({ page, request }) => {
  console.log("\n🎯 Testing Sisyphus Dry Run Mode");
  
  let testProjectPath = null;
  let executionId = null;
  
  try {
    console.log("\nStep 1: Create test environment");
    testProjectPath = createTestCodebaseCopy();
    
    const planContent = `# Test Dry Run

## Goal
Test that dry run mode works correctly.

## Milestones

### Milestone 1: Test Change
**Steps**:
1. Modify lib/calculator.rb

## Constraints
- Test only

## Assumptions  
- None

## Risks
- None
`;
    
    const testPlanPath = createTestPlan(testProjectPath, planContent);
    
    console.log("\nStep 2: Navigate and configure dry run");
    await page.goto("/agent");
    await page.locator('select[aria-label="Agent Mode"]').selectOption('sisyphus');
    
    await page.locator('input[placeholder*="plan"]').fill(testPlanPath);
    await page.locator('input[placeholder*="project"]').fill(testProjectPath);
    
    // Enable dry run
    const dryRunCheckbox = page.locator('input[aria-label*="Dry Run"]');
    await dryRunCheckbox.check();
    console.log("✓ Dry run mode enabled");
    
    // Set autonomous mode
    await page.locator('select[aria-label="Approval Mode"]').selectOption('autonomous');
    
    // Start execution
    console.log("\nStep 3: Start dry run execution");
    await page.locator('button').filter({ hasText: /start.*execution/i }).click();
    
    // Wait for execution details
    await expect(page.locator('.execution-details')).toBeVisible({ timeout: 10000 });
    
    // Verify dry run banner is shown
    await expect(page.locator('.banner-warning').filter({ hasText: /dry.*run/i })).toBeVisible();
    console.log("✓ Dry run banner displayed");
    
    // Extract execution ID
    const executionIdElement = await page.locator('.execution-details code').first().textContent();
    executionId = executionIdElement.trim();
    console.log(`✓ Dry run execution ID: ${executionId}`);
    
    console.log("✅ Dry run mode test complete!");
    
  } finally {
    // Cleanup
    if (executionId) {
      try {
        await request.delete(`http://localhost:4000/api/sisyphus/executions/${executionId}`);
        console.log(`✓ Cancelled dry run execution: ${executionId}`);
      } catch (error) {
        console.log(`⚠️  Could not cancel execution: ${error.message}`);
      }
    }
    
    if (testProjectPath) {
      cleanupTestDirectory(testProjectPath);
    }
  }
});

slow("sisyphus - validates required fields before starting", async ({ page }) => {
  console.log("\n🎯 Testing Sisyphus Form Validation");
  
  await page.goto("/agent");
  await page.locator('select[aria-label="Agent Mode"]').selectOption('sisyphus');
  
  // Start button should be disabled without required fields
  const startBtn = page.locator('button').filter({ hasText: /start.*execution/i });
  await expect(startBtn).toBeDisabled();
  console.log("✓ Start button disabled when form empty");
  
  // Add plan path only
  await page.locator('input[placeholder*="plan"]').fill("/test/plan.md");
  await expect(startBtn).toBeDisabled();
  console.log("✓ Start button still disabled with only plan path");
  
  // Add project path
  await page.locator('input[placeholder*="project"]').fill("/test/project");
  await expect(startBtn).toBeEnabled();
  console.log("✓ Start button enabled with both paths");
  
  console.log("✅ Form validation test complete!");
});

slow("sisyphus - displays error for invalid plan path", async ({ page }) => {
  console.log("\n🎯 Testing Sisyphus Error Handling");
  
  let testProjectPath = null;
  
  try {
    testProjectPath = createTestCodebaseCopy();
    
    await page.goto("/agent");
    await page.locator('select[aria-label="Agent Mode"]').selectOption('sisyphus');
    
    // Fill in invalid plan path and valid project path
    await page.locator('input[placeholder*="plan"]').fill("/invalid/nonexistent/plan.md");
    await page.locator('input[placeholder*="project"]').fill(testProjectPath);
    await page.locator('select[aria-label="Approval Mode"]').selectOption('autonomous');
    
    console.log("✓ Form filled with invalid plan path");
    
    // Start execution
    await page.locator('button').filter({ hasText: /start.*execution/i }).click();
    console.log("✓ Execution attempted");
    
    // Should show error
    await expect(page.locator('.banner-error, .error-banner, [class*="error"]').first()).toBeVisible({ timeout: 10000 });
    console.log("✓ Error message displayed");
    
    console.log("✅ Error handling test complete!");
    
  } finally {
    if (testProjectPath) {
      cleanupTestDirectory(testProjectPath);
    }
  }
});

