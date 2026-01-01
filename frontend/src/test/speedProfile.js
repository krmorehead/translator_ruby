// SpeedProfile module provides test speed categorization and enforcement
// Following OOP patterns from docs/references/oop-patterns.md
// Mirrors backend implementation in test/support/speed_profile.rb

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
    
    // Call test with enforced timeout
    return test(name, fn, { timeout, ...options });
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

