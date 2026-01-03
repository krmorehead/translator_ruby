import { expect, slow } from "./base-test";
import * as path from "path";

/**
 * Daedalus Plan Generation E2E Tests
 * 
 * Tests REAL LLM plan generation (no mocks)
 * Each test: ONE simple plan generation (< 30s)
 * 
 * CRITICAL: Timeout = FAILURE (not expected)
 */

const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const EXAMPLE_CODEBASE_PATH = path.join(PROJECT_ROOT, "test/fixtures/example_codebase");

slow("daedalus-api - should generate simple plan with real LLM", async ({ request }) => {
  const response = await request.post("http://localhost:4000/daedalus/create", {
    data: {
      goal: "Add a simple hello method to MathService",
      path: EXAMPLE_CODEBASE_PATH,
      context: {
        hint: "Just add one simple method"
      }
    },
  });

  expect(response.ok()).toBeTruthy();
  
  const result = await response.json();
  
  expect(result.success).toBe(true);
  expect(result.execution_plan).toBeDefined();
  expect(result.execution_plan.goal).toContain("hello");
  
  console.log(`Plan generated with ${result.metadata?.milestone_count} milestones`);
});

slow("daedalus-api - should verify plan structure from real LLM", async ({ request }) => {
  const response = await request.post("http://localhost:4000/daedalus/create", {
    data: {
      goal: "Add input validation to one method",
      path: EXAMPLE_CODEBASE_PATH,
      context: { hint: "Keep it simple" }
    },
  });

  const result = await response.json();
  
  expect(result.success).toBe(true);
  expect(result.execution_plan.milestones).toBeDefined();
  expect(Array.isArray(result.execution_plan.milestones)).toBe(true);
  
  expect(result.output_paths).toBeDefined();
  expect(result.output_paths.plan_path).toBeDefined();
  
  console.log(`Plan saved to: ${result.output_paths.plan_path}`);
});
