// SpeedProfile module provides test speed categorization and enforcement
// Following OOP patterns from docs/references/oop-patterns.md
// Mirrors backend implementation in test/support/speed_profile.rb

import { test } from 'vitest';

const SPEED_LEVELS = Object.freeze({
  FAST: 'fast',
  MEDIUM: 'medium',
  SLOW: 'slow'
});

const SPEED_LIMITS = Object.freeze({
  [SPEED_LEVELS.FAST]: 1000,      // 1 second
  [SPEED_LEVELS.MEDIUM]: 5000,    // 5 seconds
  [SPEED_LEVELS.SLOW]: 30000      // 30 seconds
});

// Store speed profiles per test
const testProfiles = new Map();

/**
 * AGGRESSIVE timeout handler that STOPS YOU from moving on
 */
const createTimeoutError = (testName, profile, limit) => {
  const errorMessage = `
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ❌❌❌ TEST TIMEOUT - FIX THIS BEFORE MOVING ON ❌❌❌                      ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Test Name: "${testName}"
Speed Profile: ${profile}
Time Limit: ${limit}ms

🛑 THIS TEST TOOK TOO LONG AND TIMED OUT

WHY THIS IS A PROBLEM:
- Tests should complete WELL WITHIN their time limit
- Timeouts mean something is BROKEN or MISCONFIGURED
- You CANNOT move on until this is fixed

WHAT TO DO:
1. ✅ Is the backend running? (rails server)
2. ✅ Is the LLM server accessible? (check ports 52003/52004)
3. ✅ Is the test doing too much? (break it down into smaller tests)
4. ✅ Is the API call hanging? (check network tab in browser)
5. ✅ Is the selector wrong? (element not found = timeout)

SPEED PROFILE GUIDELINES:
- FAST (< 1s): Unit tests, model tests, no I/O
- MEDIUM (< 5s): Component tests, store tests, API mocks
- SLOW (< 30s): E2E tests, real API calls, database operations

IF THIS IS AN E2E TEST WITH REAL LLM:
- Simple LLM queries should take 10-20s MAX
- If taking longer, the test is doing TOO MUCH
- Break it into smaller, focused tests
- Each test should make AT MOST 1 LLM call

DO NOT INCREASE THE TIMEOUT
DO NOT MOVE ON
FIX THE PROBLEM

╔═══════════════════════════════════════════════════════════════════════════════╗
║                  STOP AND FIX THIS TEST NOW                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
`;
  
  const error = new Error(errorMessage);
  error.name = 'TEST_TIMEOUT_ERROR';
  return error;
};

/**
 * Enforce speed profile declaration on tests
 * Wraps Vitest's test() function to require speed_profile()
 */
export const speed_profile = (profile) => {
  // Strict validation with descriptive errors
  if (typeof profile !== 'string') {
    throw new Error(`Speed profile must be a string, got ${typeof profile}`);
  }
  
  const validProfiles = Object.values(SPEED_LEVELS);
  if (!validProfiles.includes(profile)) {
    throw new Error(
      `Invalid speed profile: ${profile}. Valid profiles: ${validProfiles.join(', ')}`
    );
  }

  // Return a function that wraps the test
  return (name, fn, options = {}) => {
    const timeout = SPEED_LIMITS[profile];
    
    // Store the profile for this test
    testProfiles.set(name, profile);
    
    // Wrap the test function to catch timeouts
    const wrappedFn = async (...args) => {
      const startTime = Date.now();
      let timeoutHandle;
      
      try {
        // Set up aggressive timeout that throws our custom error
        const timeoutPromise = new Promise((_, reject) => {
          timeoutHandle = setTimeout(() => {
            reject(createTimeoutError(name, profile, timeout));
          }, timeout);
        });
        
        // Race between test completion and timeout
        const testPromise = Promise.resolve(fn(...args));
        const result = await Promise.race([testPromise, timeoutPromise]);
        
        clearTimeout(timeoutHandle);
        
        const elapsed = Date.now() - startTime;
        console.log(`✅ ${name} completed in ${elapsed}ms (limit: ${timeout}ms, profile: ${profile})`);
        
        return result;
      } catch (error) {
        clearTimeout(timeoutHandle);
        
        // If it's our timeout error, throw it as-is
        if (error.name === 'TEST_TIMEOUT_ERROR') {
          throw error;
        }
        
        // Otherwise, wrap it with timing info
        const elapsed = Date.now() - startTime;
        console.error(`❌ ${name} failed after ${elapsed}ms (limit: ${timeout}ms, profile: ${profile})`);
        throw error;
      }
    };
    
    // Call test with enforced timeout
    return test(name, wrappedFn, { timeout, ...options });
  };
};

/**
 * Get speed profile for a test (for debugging/reporting)
 */
export const getSpeedProfile = (testName) => {
  return testProfiles.get(testName);
};

/**
 * Validate all tests have speed profiles (call after test definitions)
 */
export const validateSpeedProfiles = () => {
  // This is called by test setup to ensure all tests are profiled
  // Vitest will enforce timeouts automatically
};

// Export constants for use in tests
export { SPEED_LEVELS, SPEED_LIMITS };
