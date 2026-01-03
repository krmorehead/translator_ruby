import "@testing-library/jest-dom";
import { expect } from 'vitest';
import * as matchers from '@testing-library/jest-dom/matchers';

// Extend Vitest's expect with jest-dom matchers
expect.extend(matchers);

// Speed profiling is imported in each test file to enforce per-test declaration
// See: frontend/src/test/speedProfile.js for implementation
// Pattern matches: test/support/speed_profile.rb


