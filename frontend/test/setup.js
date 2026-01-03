import { beforeEach, afterEach } from 'vitest';
import { getCurrentProfile, getCurrentThreshold, SPEED_PROFILES } from '../src/utils/testProfile';

/**
 * Global test setup to enforce speed profiling
 * 
 * This file is loaded by vitest before running tests.
 * It tracks test execution time and enforces speed thresholds.
 */

let testStartTime = null;
let currentTestName = null;

beforeEach((context) => {
  testStartTime = Date.now();
  currentTestName = context?.task?.name || 'unknown';
});

afterEach(() => {
  if (testStartTime === null) return;
  
  const duration = Date.now() - testStartTime;
  const profile = getCurrentProfile();
  const threshold = getCurrentThreshold();
  
  if (profile && duration > threshold) {
    const error = new Error(
      `\n${'='.repeat(80)}\n` +
      `SPEED PROFILE VIOLATION\n` +
      `${'='.repeat(80)}\n` +
      `Test: ${currentTestName}\n` +
      `Profile: ${profile}\n` +
      `Threshold: ${threshold}ms\n` +
      `Actual: ${duration}ms\n` +
      `Exceeded by: ${duration - threshold}ms\n` +
      `\n` +
      `REQUIRED ACTIONS:\n` +
      `1. Optimize the test to reduce execution time\n` +
      `2. Split into smaller, more focused tests\n` +
      `3. If justified, reclassify to a slower profile\n` +
      `${'='.repeat(80)}\n`
    );
    error.name = 'SpeedProfileError';
    throw error;
  }
  
  testStartTime = null;
  currentTestName = null;
});

// Log profile info for debugging
if (process.env.VITEST_POOL_ID === '1' || process.env.VITEST_WORKER_ID === '1') {
  console.log('\n' + '='.repeat(80));
  console.log('Speed Profiling Active');
  console.log('='.repeat(80));
  console.log('Profiles:');
  Object.entries(SPEED_PROFILES).forEach(([key, value]) => {
    console.log(`  ${key}: ${value}`);
  });
  console.log('\nThresholds:');
  console.log('  fast: 100ms');
  console.log('  medium: 1000ms (1 second)');
  console.log('  slow: 120000ms (120 seconds / 2 minutes)');
  console.log('='.repeat(80) + '\n');
}

