// web/src/components/SyncStatus.tsx
import { useState, useEffect } from 'react';

export function SyncStatus() {
  const [status, setStatus] = useState({ unsyncedPeople: 0, unsyncedEncounters: 0 });
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  useEffect(() => {
    const updateStatus = async () => {
      try {
        // Check local database for unsynced items
        const { db } = await import('../lib/db');
        const pendingPersons = await db.persons.where('_status').equals('pending').count();
        const pendingOutbox = await db.outbox.count();
        
        setStatus({ 
          unsyncedPeople: pendingPersons, 
          unsyncedEncounters: pendingOutbox 
        });
      } catch (error) {
        console.error('Failed to get sync status:', error);
        setStatus({ unsyncedPeople: 0, unsyncedEncounters: 0 });
      }
    };

    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    updateStatus();
    const interval = setInterval(updateStatus, 5000); // Check every 5 seconds

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      clearInterval(interval);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const totalUnsynced = status.unsyncedPeople + status.unsyncedEncounters;
  const hasUnsyncedData = totalUnsynced > 0;

  return (
    <div className="slds-m-bottom_small">
      <span className={`slds-badge slds-m-right_xx-small ${isOnline ? 'slds-theme_success' : 'slds-theme_warning'}`}>
        {isOnline ? '🌐 Online' : '📱 Offline'}
      </span>
      {hasUnsyncedData ? (
        <span className="slds-badge slds-theme_warning">
          ⏳ {totalUnsynced} pending sync
        </span>
      ) : (
        <span className="slds-badge slds-theme_success">
          ✅ All synced
        </span>
      )}
    </div>
  );
}