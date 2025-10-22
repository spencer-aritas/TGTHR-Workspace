/// <reference lib="WebWorker" />
import { clientsClaim } from 'workbox-core'
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching'
import { registerRoute } from 'workbox-routing'
import { NetworkFirst, StaleWhileRevalidate } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { Queue } from 'workbox-background-sync'

declare const self: ServiceWorkerGlobalScope & { __WB_MANIFEST: any }

console.log('Service Worker loading...')

// Take control fast
self.skipWaiting()
clientsClaim()

// Precache app shell
precacheAndRoute(self.__WB_MANIFEST || [])
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
