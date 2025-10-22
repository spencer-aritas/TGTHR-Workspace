// Manual sync trigger for when automatic background sync doesn't work
export async function triggerBackgroundSync() {
  if ('serviceWorker' in navigator && 'sync' in window.ServiceWorkerRegistration.prototype) {
    try {
      const registration = await navigator.serviceWorker.ready;
      await registration.sync.register('syncQueue');
      console.log('Background sync triggered manually');
    } catch (error) {
      console.error('Failed to trigger background sync:', error);
    }
  }
}

// Auto-trigger sync when coming back online
if (typeof window !== 'undefined') {
  window.addEventListener('online', () => {
    console.log('Back online - triggering background sync');
    triggerBackgroundSync();
  });
}