// web/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    // Removed missing plugins
    VitePWA({
      injectRegister: null, // We'll handle registration ourselves
      strategies: "injectManifest",
      srcDir: "src/sw",
      filename: "sw.js",
      devOptions: { 
        enabled: true,
        type: "module",
      },
      workbox: {
        cleanupOutdatedCaches: true,
        clientsClaim: false,
        skipWaiting: false,
        disableDevLogs: false,
      },
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
      "@shared": "../shared"
    }
  },
  optimizeDeps: {
    include: ['../shared/contracts']
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: ['outreachintake.aritasconsulting.com', 'localhost', '0.0.0.0'],
    fs: {
      allow: [".."]
    }
  },
  preview: { 
    port: 5173,
    host: '0.0.0.0',
    // In preview mode (production), proxy API requests to Caddy
    proxy: {
      "/api": {
        target: "http://caddy",
        changeOrigin: true,
        secure: false
      }
    }
  }
});
