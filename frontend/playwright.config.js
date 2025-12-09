import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  webServer: [
    {
      command:
        "/bin/bash -lc 'cd /home/kyle/Side_Projects/translator_ruby && PORT=4000 RAILS_ENV=test bundle exec rails server'",
      port: 4000,
      reuseExistingServer: true,
      timeout: 120_000
    },
    {
      command:
        "/bin/bash -lc 'cd /home/kyle/Side_Projects/translator_ruby/frontend && npm run dev -- --host --port 5173'",
      port: 5173,
      reuseExistingServer: true,
      timeout: 90_000
    }
  ],
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:5173",
    headless: true
  },
  reporter: [["list"]]
});

