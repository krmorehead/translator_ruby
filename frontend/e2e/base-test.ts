/**
 * Base Test Configuration - ALL E2E TESTS MUST USE THIS
 * 
 * Exports speed-profiled test functions that enforce timeout limits.
 * DO NOT import { test } from '@playwright/test' directly.
 * ALWAYS import { fast, medium, slow } from './base-test'.
 * 
 * Speed Profiles:
 * - fast: < 5s - UI only, no network
 * - medium: < 15s - API calls, no LLM
 * - slow: < 30s - Real LLM, ONE simple query MAX
 */

import { test as playwrightTest, expect } from '@playwright/test';

export { expect };

const SPEED_LIMITS = {
  fast: 5000,
  medium: 15000,
  slow: 30000
} as const;

type SpeedProfile = keyof typeof SPEED_LIMITS;

const createTimeoutError = (testName: string, profile: SpeedProfile, limit: number, elapsed: number): string => {
  return `
❌ E2E TEST TIMEOUT - FIX IMMEDIATELY

Test: "${testName}"
Profile: ${profile.toUpperCase()} | Limit: ${limit}ms | Actual: ${elapsed}ms

Common causes:
- Backend not running (rails server -p 4000)
- Frontend not running (npm run dev)
- LLM server not accessible (ports 52003/52004)
- Wrong selector (element never found)
- Test doing too much (break it down)

Speed limits: FAST=5s (UI only) | MEDIUM=15s (API, no LLM) | SLOW=30s (real LLM)

DO NOT increase timeout. FIX the actual problem.
`;
};

type TestFunction = Parameters<typeof playwrightTest>[1];

const createProfiledTest = (profile: SpeedProfile) => {
  const timeout = SPEED_LIMITS[profile];

  return (testName: string, testFn: TestFunction) => {
    playwrightTest(testName, async ({ page, context, request, browser }) => {
      playwrightTest.setTimeout(timeout);
      
      // Capture browser console logs and errors
      page.on('console', msg => {
        const type = msg.type();
        if (type === 'error' || type === 'warning') {
          console.log(`[Browser ${type.toUpperCase()}]`, msg.text());
        }
      });
      
      page.on('pageerror', error => {
        console.error('[Browser Page Error]', error.message);
      });
      
      page.on('requestfailed', request => {
        console.error('[Browser Request Failed]', request.url(), request.failure()?.errorText);
      });
      
      const startTime = Date.now();

      try {
        await testFn({ page, context, request, browser } as any);
        
        const elapsed = Date.now() - startTime;
        console.log(`✅ [${profile.toUpperCase()}] ${testName} completed in ${elapsed}ms (limit: ${timeout}ms)`);
        
        if (elapsed > timeout * 0.8) {
          console.warn(`⚠️  Test took ${elapsed}ms (${(elapsed/timeout*100).toFixed(1)}% of limit). Consider breaking it down.`);
        }
      } catch (error: any) {
        const elapsed = Date.now() - startTime;
        
        const actualTimeout = elapsed >= timeout - 100;
        const errorIsTimeout = 
          error.message?.toLowerCase().includes('timeout') ||
          error.message?.toLowerCase().includes('exceed') ||
          error.constructor?.name === 'TimeoutError';
        
        if (actualTimeout || (errorIsTimeout && elapsed > timeout * 0.9)) {
          throw new Error(createTimeoutError(testName, profile, timeout, elapsed));
        }
        
        console.error(`❌ [${profile.toUpperCase()}] ${testName} failed after ${elapsed}ms`);
        throw error;
      }
    });
  };
};

export const fast = createProfiledTest('fast');
export const medium = createProfiledTest('medium');
export const slow = createProfiledTest('slow');

/**
 * BLOCKED: Raw test() is not allowed - use fast(), medium(), or slow()
 */
export const test = (): never => {
  throw new Error(`
❌ RAW test() NOT ALLOWED - USE SPEED PROFILING

Instead of:  import { test } from '@playwright/test';
Use:         import { fast, medium, slow } from './base-test';

Then: fast("name", ...) | medium("name", ...) | slow("name", ...)
Limits: FAST=5s (UI only) | MEDIUM=15s (API) | SLOW=30s (LLM)
`);
};

(test as any).describe = (): never => {
  throw new Error(`❌ test.describe() NOT ALLOWED - Profile each test individually with fast(), medium(), or slow()`);
};
