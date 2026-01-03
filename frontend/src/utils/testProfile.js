/**
 * Test Speed Profiling Utilities
 * 
 * Provides speed profiling metadata for tests to match backend pattern:
 * - fast: < 100ms (unit tests, no I/O)
 * - medium: 100ms - 1s (integration, minimal I/O)
 * - slow: > 1s (E2E, API calls, browser automation)
 * 
 * Usage:
 *   import { speedProfile } from '../utils/testProfile';
 *   
 *   describe('MyComponent', () => {
 *     speedProfile('fast');
 *     it('renders correctly', () => { ... });
 *   });
 */

export const SPEED_PROFILES = {
  FAST: 'fast',      // < 100ms - Pure unit tests, no I/O
  MEDIUM: 'medium',  // 100ms - 1s - Integration tests, minimal I/O
  SLOW: 'slow'       // > 1s - E2E tests, API calls, browser automation
};

export const SPEED_THRESHOLDS = {
  [SPEED_PROFILES.FAST]: 100,      // 100ms
  [SPEED_PROFILES.MEDIUM]: 1000,   // 1 second
  [SPEED_PROFILES.SLOW]: 120000    // 120 seconds (2 minutes) - matches backend
};

let currentProfile = null;

/**
 * Set speed profile for test suite
 * @param {string} profile - One of SPEED_PROFILES
 */
export function speedProfile(profile) {
  if (!Object.values(SPEED_PROFILES).includes(profile)) {
    throw new Error(`Invalid speed profile: ${profile}. Must be one of: ${Object.values(SPEED_PROFILES).join(', ')}`);
  }
  currentProfile = profile;
  return profile;
}

/**
 * Get current speed profile
 * @returns {string|null}
 */
export function getCurrentProfile() {
  return currentProfile;
}

/**
 * Get threshold for current profile in milliseconds
 * @returns {number}
 */
export function getCurrentThreshold() {
  return currentProfile ? SPEED_THRESHOLDS[currentProfile] : Infinity;
}

/**
 * Validate test execution time against profile
 * @param {number} duration - Test duration in milliseconds
 * @param {string} testName - Name of the test
 * @throws {Error} If test exceeds profile threshold
 */
export function validateTestSpeed(duration, testName) {
  const threshold = getCurrentThreshold();
  if (duration > threshold) {
    throw new Error(
      `Test "${testName}" exceeded ${currentProfile} profile threshold.\n` +
      `Expected: < ${threshold}ms, Actual: ${duration}ms\n` +
      `Consider: 1) Optimizing the test, 2) Splitting into smaller tests, 3) Using a slower profile`
    );
  }
}

/**
 * Time a test function and validate against profile
 * @param {Function} fn - Test function to time
 * @param {string} testName - Name of the test
 * @returns {Promise<any>} Result of test function
 */
export async function timedTest(fn, testName) {
  const start = Date.now();
  try {
    const result = await fn();
    const duration = Date.now() - start;
    
    if (currentProfile) {
      validateTestSpeed(duration, testName);
    }
    
    return result;
  } catch (error) {
    const duration = Date.now() - start;
    
    if (currentProfile) {
      // Still validate speed even on failure
      try {
        validateTestSpeed(duration, testName);
      } catch (speedError) {
        // Attach speed error to original error
        error.speedValidationError = speedError;
      }
    }
    
    throw error;
  }
}

/**
 * Reset profile (for test isolation)
 */
export function resetProfile() {
  currentProfile = null;
}

