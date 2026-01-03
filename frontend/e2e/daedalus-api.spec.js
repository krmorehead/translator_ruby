import { expect } from "@playwright/test";
import { slow } from "./helpers/speedProfile.js";
import * as path from 'path';

/**
 * Daedalus Plan Generation E2E Tests
 * 
 * Tests REAL LLM plan generation (no mocks)
 * Each test: ONE simple plan generation (< 30s)
 * 
 * CRITICAL: Timeout = FAILURE (not expected)
 */

const PROJECT_ROOT = path.resolve(process.cwd(), '..');
const EXAMPLE_CODEBASE_PATH = path.join(PROJECT_ROOT, 'test/fixtures/example_codebase');

slow("should generate simple plan with real LLM", async ({ request }) => {
  const response = await request.post("http://localhost:4000/daedalus/create", {
    data: {
      goal: "Add a simple hello method to MathService",
      path: EXAMPLE_CODEBASE_PATH,
      context: {
        hint: "Just add one simple method"
      }
    },
    timeout: 25000
  });

  expect(response.ok()).toBeTruthy();
  
  const result = await response.json();
  
  expect(result.success).toBe(true);
  expect(result.execution_plan).toBeDefined();
  expect(result.execution_plan.goal).toContain("hello");
  
  console.log(`Plan generated with ${result.metadata?.milestone_count || 0} milestones`);
});

slow("should verify plan structure from real LLM", async ({ request }) => {
  const response = await request.post("http://localhost:4000/daedalus/create", {
    data: {
      goal: "Add input validation to one method",
      path: EXAMPLE_CODEBASE_PATH,
      context: { hint: "Keep it simple" }
    },
    timeout: 25000
  });

  const result = await response.json();
  
  expect(result.success).toBe(true);
  expect(result.execution_plan.milestones).toBeDefined();
  expect(Array.isArray(result.execution_plan.milestones)).toBe(true);
  
  // Should have output paths
  expect(result.output_paths).toBeDefined();
  expect(result.output_paths.plan_path).toBeDefined();
  
  console.log(`Plan saved to: ${result.output_paths.plan_path}`);
});
