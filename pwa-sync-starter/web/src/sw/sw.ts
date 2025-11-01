/// <reference lib="WebWorker" />
import { precacheAndRoute } from 'workbox-precaching'
import { registerRoute } from 'workbox-routing'
import { NetworkOnly, StaleWhileRevalidate } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'

declare const self: ServiceWorkerGlobalScope & { __WB_MANIFEST: any }

console.log('Service Worker loading...')

// Listen for skip waiting message
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// No auto-claim or skip-waiting - let updates be controlled
// This matches our Vite PWA config
const SAFE_ASSET_REGEX = /\.(?:js|css|mjs|cjs|woff2?|ttf|eot|svg|png|jpg|jpeg|gif|webp|ico)$/i
const manifestEntries = (self.__WB_MANIFEST || []).filter((entry: any) => {
  const url = typeof entry === 'string' ? entry : entry.url
  return SAFE_ASSET_REGEX.test(url)
})

// Only precache in production
if (import.meta.env.PROD) {
  precacheAndRoute(manifestEntries)
} else {
  console.log('Development mode: skipping precache')
}

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

// ---- Handle auth endpoints and callbacks with NetworkOnly strategy
registerRoute(
  ({ url }) => url.pathname.startsWith('/api/auth/') || 
               url.pathname === '/auth/callback' || 
               (url.pathname === '/' && url.search.includes('code=')),
  new NetworkOnly(),
  'GET'
)

// ---- Avoid caching PHI responses: GET /api/* is network-only for other endpoints
registerRoute(
  ({ url, request }) => request.method === 'GET' && url.pathname.startsWith('/api/') && !url.pathname.startsWith('/api/auth/'),
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
