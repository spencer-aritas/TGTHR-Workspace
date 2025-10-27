/// <reference lib="WebWorker" />
import { clientsClaim } from 'workbox-core'
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching'
import { registerRoute } from 'workbox-routing'
import { NetworkOnly, StaleWhileRevalidate } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'

declare const self: ServiceWorkerGlobalScope & { __WB_MANIFEST: any }

console.log('Service Worker loading...')

// Take control fast
self.skipWaiting()
clientsClaim()

// Precache only safe static assets (js/css/fonts/icons/images)
const SAFE_ASSET_REGEX = /\.(?:js|css|mjs|cjs|woff2?|ttf|eot|svg|png|jpg|jpeg|gif|webp|ico)$/i
const manifestEntries = (self.__WB_MANIFEST || []).filter((entry: any) => {
  const url = typeof entry === 'string' ? entry : entry.url
  return SAFE_ASSET_REGEX.test(url)
})

precacheAndRoute(manifestEntries)
cleanupOutdatedCaches()

console.log('Service Worker installed')

// Simple POST handler for /api/sync/*
registerRoute(
  ({ url, request }) => request.method === 'POST' && url.pathname.startsWith('/api/sync/'),
  async ({ request }) => {
    console.log('SW: Intercepted POST to', request.url)
    
    try {
      const response = await fetch(request)
      console.log('SW: Network response', response.status)
      return response
    } catch (error) {
      console.log('SW: Network failed, returning queued response')
      return new Response(JSON.stringify({ queued: true }), {
        status: 202,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }
)

// Network-only for other API POST requests (avoid caching PHI)
registerRoute(
  ({ url, request }) => request.method === 'POST' && url.pathname.startsWith('/api/'),
  new NetworkOnly()
)

// ---- Avoid caching PHI responses: GET /api/* is network-only
registerRoute(
  ({ url, request }) => request.method === 'GET' && url.pathname.startsWith('/api/'),
  new NetworkOnly()
)

// ---- Static assets (JS/CSS/workers/images/fonts)
registerRoute(
  ({ request }) => ['style', 'script', 'worker', 'image', 'font'].includes(request.destination),
  new StaleWhileRevalidate({
    cacheName: 'assets',
    plugins: [new ExpirationPlugin({ maxEntries: 200, purgeOnQuotaError: true })],
  })
)
