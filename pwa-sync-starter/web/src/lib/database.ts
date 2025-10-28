interface DBSchema {
  forms: {
    id: string;
    formType: string;
    data: string; // JSON string
    timestamp: number;
    synced: boolean;
  };
  
  cache: {
    key: string;
    data: string; // JSON string
    expiry: number;
  };
  
  sync_queue: {
    id: string;
    endpoint: string;
    method: string;
    data: string; // JSON string
    retries: number;
    created: number;
  };
}

class OfflineDB {
  private db: IDBDatabase | null = null;
  private readonly dbName = 'OfflineFormsDB';
  private readonly version = 1;

  async init(): Promise<void> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.version);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve();
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        // Forms store
        if (!db.objectStoreNames.contains('forms')) {
          const formsStore = db.createObjectStore('forms', { keyPath: 'id' });
          formsStore.createIndex('formType', 'formType');
          formsStore.createIndex('synced', 'synced');
        }

        // Cache store
        if (!db.objectStoreNames.contains('cache')) {
          const cacheStore = db.createObjectStore('cache', { keyPath: 'key' });
          cacheStore.createIndex('expiry', 'expiry');
        }

        // Sync queue store
        if (!db.objectStoreNames.contains('sync_queue')) {
          const syncStore = db.createObjectStore('sync_queue', { keyPath: 'id' });
          syncStore.createIndex('created', 'created');
        }
      };
    });
  }

  async saveForm(id: string, formType: string, data: any): Promise<void> {
    const transaction = this.db!.transaction(['forms'], 'readwrite');
    const store = transaction.objectStore('forms');
    
    await store.put({
      id,
      formType,
      data: JSON.stringify(data),
      timestamp: Date.now(),
      synced: false
    });
  }

  async getUnsynced(): Promise<DBSchema['forms'][]> {
    const transaction = this.db!.transaction(['forms'], 'readonly');
    const store = transaction.objectStore('forms');
    const index = store.index('synced');
    
    return new Promise((resolve, reject) => {
      const request = index.getAll(false);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async markSynced(id: string): Promise<void> {
    const transaction = this.db!.transaction(['forms'], 'readwrite');
    const store = transaction.objectStore('forms');
    
    const form = await this.getForm(id);
    if (form) {
      form.synced = true;
      await store.put(form);
    }
  }

  async clearExpired(maxAge: number = 30 * 60 * 1000): Promise<void> {
    const cutoff = Date.now() - maxAge;
    const transaction = this.db!.transaction(['forms', 'cache'], 'readwrite');
    
    // Clear old forms
    const formsStore = transaction.objectStore('forms');
    const formsCursor = await formsStore.openCursor();
    
    while (formsCursor) {
      if (formsCursor.value.timestamp < cutoff) {
        await formsCursor.delete();
      }
      formsCursor.continue();
    }

    // Clear expired cache
    const cacheStore = transaction.objectStore('cache');
    const cacheIndex = cacheStore.index('expiry');
    const cacheRange = IDBKeyRange.upperBound(Date.now());
    
    const cacheCursor = await cacheIndex.openCursor(cacheRange);
    while (cacheCursor) {
      await cacheCursor.delete();
      cacheCursor.continue();
    }
  }

  private async getForm(id: string): Promise<DBSchema['forms'] | null> {
    const transaction = this.db!.transaction(['forms'], 'readonly');
    const store = transaction.objectStore('forms');
    
    return new Promise((resolve, reject) => {
      const request = store.get(id);
      request.onsuccess = () => resolve(request.result || null);
      request.onerror = () => reject(request.error);
    });
  }
}

export const offlineDB = new OfflineDB();