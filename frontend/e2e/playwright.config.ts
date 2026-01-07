import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E Test Configuration for Sisyphus
 * 
 * Tests the Sisyphus UI including:
 * - Approval workflow
 * - Dry-run mode
 * - Execution monitoring
 * - File browser
 * - Configuration display
 */
export default defineConfig({
  testDir: '.',
  
  /* Maximum time one test can run */
  timeout: 60 * 1000,
  
  /* Test execution settings */
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  // Limit workers to prevent overwhelming LLM server (tests should handle 3-4 parallel)
  workers: process.env.TEST_SPEED_FILTER === 'slow' ? 3 : (process.env.CI ? 1 : undefined),
  
  /* Output directory for test artifacts */
  outputDir: 'test-results',
  
  /* Reporter to use */
  reporter: [
    ['html', { outputFolder: 'e2e-results' }],
    ['list']
  ],
  
  /* Shared settings for all projects */
  use: {
    /* Base URL for tests - frontend is on 5173, backend API on 4000 */
    baseURL: process.env.BASE_URL || 'http://localhost:5173',
    
    /* Collect trace on failure */
    trace: 'on-first-retry',
    
    /* Screenshot on failure */
    screenshot: 'only-on-failure',
    
    /* Video on failure */
    video: 'retain-on-failure',
    
    /* Default action and navigation timeout - will be overridden per test by speed profile */
    actionTimeout: 0, // Disable default, let speed profile handle it
    navigationTimeout: 0, // Disable default, let speed profile handle it
  },
  
  /* Global expect timeout - set based on test speed filter */
  expect: {
    timeout: process.env.E2E_TEST_SPEED_FILTER === 'fast' ? 5000 :
             process.env.E2E_TEST_SPEED_FILTER === 'medium' ? 15000 :
             process.env.E2E_TEST_SPEED_FILTER === 'slow' ? 30000 :
             30000, // Default to slow for safety
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },

    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    /* Mobile viewports for responsive testing */
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  /* Run local dev server before starting tests */
  webServer: process.env.SKIP_WEBSERVER ? undefined : {
    command: 'cd .. && npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});








