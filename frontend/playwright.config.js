import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 120_000, // 120 seconds - matches slow profile threshold
  use: {
    // Use Vite dev server for E2E tests
    baseURL: process.env.BASE_URL || "http://localhost:5173",
    headless: true
  },
  reporter: [["list"], ["html"]]
});

