import { defineConfig } from 'vite';

// Capacitor apps are just static web apps under the hood. Vite's only job
// here is to bundle src/auth-main.js (which imports the Firebase SDK and the
// @capacitor-firebase/authentication plugin from node_modules) into a single
// browser-ready file. The rest of the app (index.html's big inline <script>)
// is untouched — it's already plain browser JS with no npm dependencies.
export default defineConfig({
  root: '.',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 8100,
  },
});
