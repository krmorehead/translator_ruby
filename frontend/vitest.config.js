import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.js'],
    globals: true,
    // Speed profiling enforcement
    testTimeout: 120000, // 120 seconds max for any test (slow threshold)
    hookTimeout: 10000,  // 10 seconds for hooks
    teardownTimeout: 10000,
    // Report slow tests
    slowTestThreshold: 100, // Warn on tests > 100ms (fast threshold)
  },
});

