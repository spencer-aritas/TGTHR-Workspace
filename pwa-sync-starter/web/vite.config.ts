// web/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
import { resolve } from "node:path";
// Removed missing dependencies

export default defineConfig({
  plugins: [
    react(),
    // Removed missing plugins
    VitePWA({
      injectRegister: "auto",
      registerType: "autoUpdate",
      strategies: "injectManifest",
      srcDir: "src/sw",
      filename: "sw.ts",
      devOptions: { enabled: true, type: "module", navigateFallback: "index.html" },
      manifest: {
        name: "TGTHR Offline App",
        short_name: "TGTHR",
        start_url: "/",
        display: "standalone",
        background_color: "#0b1120",
        theme_color: "#0ea5e9",
        icons: [
          { src: "/icons/icon-192.svg", sizes: "192x192", type: "image/svg+xml", purpose: "any" },
          { src: "/icons/icon-512.svg", sizes: "512x512", type: "image/svg+xml", purpose: "any" },
          { src: "/icons/icon-192.svg", sizes: "192x192", type: "image/svg+xml", purpose: "maskable" },
          { src: "/icons/icon-512.svg", sizes: "512x512", type: "image/svg+xml", purpose: "maskable" }
        ]
      }
    })
  ],
  resolve: {
    alias: {
      "@shared": resolve(__dirname, "../shared")
    }
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: ['outreachintake.aritasconsulting.com', 'localhost', '0.0.0.0'],
    fs: {
      allow: [resolve(__dirname, "..")]
    },
    proxy: {
      "/api": {
        target: "http://api:8000",
        changeOrigin: true
      }
    },
    hmr: false
  },
  preview: { port: 4173 }
});
