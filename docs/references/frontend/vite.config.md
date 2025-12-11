# frontend/vite.config.js

## Summary
- Vite configuration for the React app.
- Proxies `/dnd_chat` API calls to `http://localhost:4000` in dev.
- Builds to `../public` and empties the dir before build.

## Key Settings
- Plugins: React.
- Server proxy for `/dnd_chat`.
- Test config: jsdom environment, setup file `src/test/setup.js`.


