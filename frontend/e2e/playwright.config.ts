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
  testDir: './tests',
  
  /* Maximum time one test can run */
  timeout: 60 * 1000,
  
  /* Test execution settings */
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  
  /* Reporter to use */
  reporter: [
    ['html', { outputFolder: 'e2e-results' }],
    ['list']
  ],
  
  /* Shared settings for all projects */
  use: {
    /* Base URL for tests */
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    
    /* Collect trace on failure */
    trace: 'on-first-retry',
    
    /* Screenshot on failure */
    screenshot: 'only-on-failure',
    
    /* Video on failure */
    video: 'retain-on-failure',
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
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});

