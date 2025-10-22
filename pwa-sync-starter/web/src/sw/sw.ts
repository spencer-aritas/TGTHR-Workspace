/// <reference lib="WebWorker" />
import { clientsClaim } from 'workbox-core'
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching'
import { registerRoute } from 'workbox-routing'
import { NetworkOnly, NetworkFirst, StaleWhileRevalidate } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { Queue } from 'workbox-background-sync'

declare const self: ServiceWorkerGlobalScope & { __WB_MANIFEST: any }

// Take control fast
self.skipWaiting()
clientsClaim()

// Precache app shell + cleanup old revisions
precacheAndRoute(self.__WB_MANIFEST || [])
cleanupOutdatedCaches()

// ---- Queue ALL /api/sync/* POSTs; if offline, return 202 so UI treats as success
const syncQueue = new Queue('syncQueue', { 
  maxRetentionTime: 24 * 60
});

// Register background sync event
self.addEventListener('sync', (event) => {
  if (event.tag === 'syncQueue') {
    console.log('Background sync event triggered');
    event.waitUntil(syncQueue.replayRequests());
  }
});

registerRoute(
  ({ url, request }) => request.method === 'POST' && url.pathname.startsWith('/api/sync/'),
  // Workbox handler: queue on network error OR non-2xx, return 202 to page
  async ({ event }) => {
    try {
      // Try network first
      const response = await fetch(event.request.clone())
      if (response.ok) {
        return response
      }
      // Network failed or non-2xx, queue it
      await syncQueue.pushRequest({ request: event.request })
      return new Response(JSON.stringify({ queued: true }), {
        status: 202, 
        headers: { 'Content-Type': 'application/json' }
      })
    } catch (error) {
      // Network error (offline), queue it
      console.log('Queueing request due to network error:', error)
      await syncQueue.pushRequest({ request: event.request })
      return new Response(JSON.stringify({ queued: true }), {
        status: 202,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }
)

// ---- Offline navigation (SPA app shell)
registerRoute(
  ({ request }) => request.mode === 'navigate',
  new NetworkFirst({
    cacheName: 'pages',
    plugins: [new ExpirationPlugin({ maxEntries: 50, purgeOnQuotaError: true })],
  })
)

// ---- Runtime cache for GET /api/* (stale-while-revalidate)
registerRoute(
  ({ url, request }) => request.method === 'GET' && url.pathname.startsWith('/api/'),
  new StaleWhileRevalidate({
    cacheName: 'api',
    plugins: [new ExpirationPlugin({ maxEntries: 100, maxAgeSeconds: 60 * 10 })],
  })
)

// ---- Static assets (JS/CSS/workers/images/fonts)
registerRoute(
  ({ request }) => ['style', 'script', 'worker', 'image', 'font'].includes(request.destination),
  new StaleWhileRevalidate({
    cacheName: 'assets',
    plugins: [new ExpirationPlugin({ maxEntries: 200, purgeOnQuotaError: true })],
  })
)
