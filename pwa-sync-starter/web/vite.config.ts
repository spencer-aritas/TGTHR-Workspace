// web/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
// No path imports needed

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
      devOptions: { 
        enabled: true, 
        type: "module",
        navigateFallback: "index.html",
      },
      workbox: {
        cleanupOutdatedCaches: false,
        clientsClaim: true,
        skipWaiting: true,
        disableDevLogs: true,
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
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: ['outreachintake.aritasconsulting.com', 'localhost', '0.0.0.0'],
    fs: {
      allow: [".."]
    },
    proxy: {
      "/api": {
        target: "http://caddy",
        changeOrigin: true,
        secure: false
      }
    },
    // Disable HMR in production
    hmr: process.env.NODE_ENV === 'production' ? false : {
      protocol: 'wss',
      port: 443
    }
  },
  preview: { 
    port: 5173,
    host: '0.0.0.0'
  }
});
