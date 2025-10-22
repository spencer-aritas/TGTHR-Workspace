import { db } from './db';

class SyncService {
  private syncing = false;

  async syncPendingData() {
    if (this.syncing || !navigator.onLine) return;
    
    this.syncing = true;
    console.log('Starting sync of pending data...');
    
    try {
      const pendingItems = await db.outbox.orderBy('createdAt').toArray();
      console.log(`Found ${pendingItems.length} items to sync`);
      
      for (const item of pendingItems) {
        try {
          await this.syncItem(item);
          await db.outbox.delete(item.id!);
          console.log(`Synced item ${item.id}`);
        } catch (error) {
          console.error(`Failed to sync item ${item.id}:`, error);
          // Update attempt count
          await db.outbox.update(item.id!, {
            attempts: item.attempts + 1,
            lastAttemptAt: new Date().toISOString(),
            error: String(error)
          });
        }
      }
    } catch (error) {
      console.error('Sync failed:', error);
    } finally {
      this.syncing = false;
    }
  }

  private async syncItem(item: any) {
    const { entity, payload } = item;
    
    if (entity === 'PersonAccount') {
      const response = await fetch('/api/sync/PersonAccount', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      if (!response.ok) {
        throw new Error(`Sync failed: ${response.status}`);
      }
      
      const result = await response.json();
      
      // Update local record with Salesforce ID
      if (result.salesforceId && payload.localId) {
        await db.persons.update(payload.localId, {
          accountId: result.salesforceId,
          _status: 'synced'
        });
      }
      
    } else if (entity === 'OutreachEncounter') {
      const response = await fetch('/api/outreach-intake', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      if (!response.ok) {
        throw new Error(`Sync failed: ${response.status}`);
      }
    }
  }

  startAutoSync() {
    // Sync when coming online
    window.addEventListener('online', () => {
      setTimeout(() => this.syncPendingData(), 1000);
    });
    
    // Periodic sync when online
    setInterval(() => {
      if (navigator.onLine) {
        this.syncPendingData();
      }
    }, 30000); // Every 30 seconds
  }
}

export const syncService = new SyncService();