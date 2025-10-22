import React, { useState, useEffect } from 'react';
import { getOfflineQueueCount } from '../lib/offlineStorage';

export function OfflineIndicator() {
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [queueCount, setQueueCount] = useState(0);

  useEffect(() => {
    const updateOnlineStatus = () => setIsOnline(navigator.onLine);
    const updateQueueCount = async () => {
      const count = await getOfflineQueueCount();
      setQueueCount(count);
    };

    window.addEventListener('online', updateOnlineStatus);
    window.addEventListener('offline', updateOnlineStatus);
    
    // Update queue count periodically
    updateQueueCount();
    const interval = setInterval(updateQueueCount, 5000);

    return () => {
      window.removeEventListener('online', updateOnlineStatus);
      window.removeEventListener('offline', updateOnlineStatus);
      clearInterval(interval);
    };
  }, []);

  if (isOnline && queueCount === 0) return null;

  return (
    <div className={`fixed top-0 left-0 right-0 z-50 p-2 text-center text-sm font-medium ${
      isOnline ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'
    }`}>
      {isOnline ? (
        queueCount > 0 ? `📤 ${queueCount} items queued for sync` : '🟢 Online'
      ) : (
        `🔴 Offline - Data will be saved locally`
      )}
    </div>
  );
}