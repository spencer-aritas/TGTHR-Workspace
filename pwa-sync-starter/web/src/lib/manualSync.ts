import { backgroundSync } from './sync'

// Manual sync trigger for when automatic background sync doesn't work
export async function triggerBackgroundSync() {
  try {
    await backgroundSync()
    console.log('Manual background sync triggered')
  } catch (error) {
    console.error('Failed to trigger manual background sync:', error)
  }
}

// Auto-trigger sync when coming back online
if (typeof window !== 'undefined') {
  window.addEventListener('online', () => {
    console.log('Back online - triggering background sync')
    triggerBackgroundSync()
  })
}
