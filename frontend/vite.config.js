import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/dnd_chat": {
        target: "http://localhost:4000",
        changeOrigin: true
      },
      "/daedalus": {
        target: "http://localhost:4000",
        changeOrigin: true
      }
    }
  },
  build: {
    outDir: "../public",
    emptyOutDir: true
  },
  test: {
    environment: "jsdom",
    setupFiles: "./src/test/setup.js",
    globals: true,
    include: ["src/**/*.test.{js,jsx}"],
    exclude: ["e2e/**", "node_modules/**"]
  }
});

