import { defineConfig } from "vite"
import react from "@vitejs/plugin-react-swc"
import tailwindcss from "@tailwindcss/vite"
import wasm from "vite-plugin-wasm"
import topLevelAwait from "vite-plugin-top-level-await"
import { nodePolyfills } from "vite-plugin-node-polyfills"

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    nodePolyfills({
      polyfills: {
        zlib: true,
        buffer: true,
        process: true,
        util: true,
        events: true,
        stream: true,
        path: true,
        assert: true,
      },
      protocolImports: true,
    }),
    react(),
    tailwindcss(),
    wasm(),
    topLevelAwait(),
  ],
  define: {
    global: "globalThis",
  },
  optimizeDeps: {
    exclude: ["brotli-wasm"],
  },
  assetsInclude: ["**/*.wasm"],
})
