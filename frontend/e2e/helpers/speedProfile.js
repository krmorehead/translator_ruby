import { test } from "@playwright/test";

const SPEED_LEVELS = Object.freeze({
  FAST: 'fast',
  MEDIUM: 'medium',
  SLOW: 'slow'
});

const SPEED_LIMITS = Object.freeze({
  [SPEED_LEVELS.FAST]: 5000,      // 5 seconds
  [SPEED_LEVELS.MEDIUM]: 15000,   // 15 seconds
  [SPEED_LEVELS.SLOW]: 30000      // 30 seconds
});

const createTimeoutError = (testName, profile, limit, elapsed) => {
  return `
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ❌❌❌ E2E TEST TIMEOUT - STOP AND FIX THIS NOW ❌❌❌                       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Test: "${testName}"
Profile: ${profile}
Limit: ${limit}ms (${limit / 1000}s)
Actual: ${elapsed}ms (${(elapsed / 1000).toFixed(2)}s)

🛑 THIS TEST TIMED OUT - SOMETHING IS BROKEN

COMMON CAUSES:
1. ❌ Backend not running (start: rails server on port 4000)
2. ❌ Frontend not running (start: npm run dev)
3. ❌ LLM server not accessible (check ports 52003/52004)
4. ❌ Wrong selector (element never found)
5. ❌ Test doing too much (break it down)
6. ❌ API endpoint hanging (check network logs)

SPEED PROFILE EXPECTATIONS:
┌─────────┬──────────┬───────────────────────────────────────┐
│ Profile │ Limit    │ What Should Happen                    │
├─────────┼──────────┼───────────────────────────────────────┤
│ FAST    │ 5s       │ UI rendering, clicks, no network      │
│ MEDIUM  │ 15s      │ API calls, DB ops, NO LLM             │
│ SLOW    │ 30s      │ Real LLM, ONE simple query MAX        │
└─────────┴──────────┴───────────────────────────────────────┘

IF THIS IS A "SLOW" TEST (Real LLM):
- Should make ONLY ONE LLM call
- Simple queries only ("2+2", "is 17 prime?")
- Should complete in 15-25s typically
- If timing out at 30s, test is doing TOO MUCH

WHAT TO DO NOW:
1. Check backend/frontend/LLM servers are running
2. Check test selector is correct (use page.pause() to debug)
3. Check test isn't waiting for non-existent element
4. Break test into smaller pieces if doing multiple operations

DO NOT:
❌ Increase the timeout
❌ Move on to next test
❌ Ignore this error

DO:
✅ Fix the actual problem
✅ Verify servers are running
✅ Break down the test if it's too complex

╔═══════════════════════════════════════════════════════════════════════════════╗
║              FIX THIS TEST BEFORE MOVING ON TO ANYTHING ELSE                  ║
╚═══════════════════════════════════════════════════════════════════════════════╝
`;
};

/**
 * Creates a speed-profiled test wrapper for Playwright
 * @param {string} profile - SPEED_LEVELS.FAST, MEDIUM, or SLOW
 * @returns {Function} Test function with enforced timeout
 */
const speed_profile = (profile) => {
  if (!Object.values(SPEED_LEVELS).includes(profile)) {
    throw new Error(`Invalid speed profile: ${profile}. Must be one of: ${Object.values(SPEED_LEVELS).join(', ')}`);
  }

  const timeout = SPEED_LIMITS[profile];

  return (testName, testFn) => {
    test(testName, async ({ page, context, request, browser }) => {
      // Set the timeout FIRST
      test.setTimeout(timeout);
      
      const startTime = Date.now();

      try {
        // Run the actual test with Playwright fixtures
        await testFn({ page, context, request, browser });
        
        const elapsed = Date.now() - startTime;
        console.log(`✅ [${profile.toUpperCase()}] ${testName} completed in ${elapsed}ms (limit: ${timeout}ms)`);
        
        // Warn if getting close to limit
        if (elapsed > timeout * 0.8) {
          console.warn(`⚠️  Test took ${elapsed}ms (${(elapsed/timeout*100).toFixed(1)}% of limit). Consider breaking it down.`);
        }
      } catch (error) {
        const elapsed = Date.now() - startTime;
        
        // Check if it's ACTUALLY a timeout (test exceeded the limit)
        const actualTimeout = elapsed >= timeout - 100;
        
        // Check if the error message indicates a timeout
        const errorIsTimeout = 
          error.message?.toLowerCase().includes('timeout') ||
          error.message?.toLowerCase().includes('exceed') ||
          error.constructor?.name === 'TimeoutError';
        
        if (actualTimeout || (errorIsTimeout && elapsed > timeout * 0.9)) {
          // Throw our enhanced timeout error
          throw new Error(createTimeoutError(testName, profile, timeout, elapsed));
        }
        
        // For non-timeout errors, log and rethrow
        console.error(`❌ [${profile.toUpperCase()}] ${testName} failed after ${elapsed}ms`);
        console.error(`Error: ${error.message}`);
        throw error;
      }
    });
  };
};

// Export test builders for each speed level
export const fast = speed_profile(SPEED_LEVELS.FAST);
export const medium = speed_profile(SPEED_LEVELS.MEDIUM);
export const slow = speed_profile(SPEED_LEVELS.SLOW);

export { SPEED_LEVELS, SPEED_LIMITS };
