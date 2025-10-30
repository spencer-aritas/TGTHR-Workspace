import Dexie, { Table } from 'dexie'

export interface FormData {
  id: string
  formType: string
  clientUuid: string
  data: Record<string, any>
  createdAt: string
  expiresAt: string
  pendingSync: boolean
  deviceId: string
}

export interface SyncQueue {
  id: string
  table: string
  operation: 'create' | 'update' | 'delete'
  payload: any
  timestamp: string
  deviceId: string
}

class HIPAACompliantDB extends Dexie {
  formData!: Table<FormData, string>
  syncQueue!: Table<SyncQueue, string>
  meta!: Table<{ key: string, value: string }, string>

  constructor() {
    super('tgthr-hipaa')
    this.version(1).stores({
      formData: 'id, clientUuid, expiresAt, pendingSync',
      syncQueue: 'id, timestamp',
      meta: 'key'
    })
  }
}

export const hipaaDB = new HIPAACompliantDB()

// Auto-clear expired data every 5 minutes
setInterval(async () => {
  const now = new Date().toISOString()
  await hipaaDB.formData.where('expiresAt').below(now).delete()
}, 5 * 60 * 1000)

export async function getDeviceId(): Promise<string> {
  const rec = await hipaaDB.meta.get('deviceId')
  if (rec?.value) return rec.value
  const id = crypto.randomUUID()
  await hipaaDB.meta.put({ key: 'deviceId', value: id })
  return id
}

export async function saveFormData(formType: string, clientUuid: string, data: Record<string, any>) {
  const now = new Date()
  const expires = new Date(now.getTime() + 24 * 60 * 60 * 1000) // 24 hours
  const deviceId = await getDeviceId()
  
  const formData: FormData = {
    id: crypto.randomUUID(),
    formType,
    clientUuid,
    data,
    createdAt: now.toISOString(),
    expiresAt: expires.toISOString(),
    pendingSync: true,
    deviceId
  }

  await hipaaDB.transaction('rw', hipaaDB.formData, hipaaDB.syncQueue, async () => {
    await hipaaDB.formData.put(formData)
    await hipaaDB.syncQueue.put({
      id: crypto.randomUUID(),
      table: 'formData',
      operation: 'create',
      payload: formData,
      timestamp: now.toISOString(),
      deviceId
    })
  })
}

export async function syncPendingData(): Promise<void> {
  // Grab the current queue snapshot we'll send
  const pending = await hipaaDB.syncQueue.toArray();
  if (pending.length === 0) return;

  try {
    const response = await fetch('/api/sync/forms', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(pending)
    });

    if (!response.ok) {
      console.info('Sync deferred: non-200 from server');
      return;
    }

    // Assume server returns the IDs of queue items it successfully processed
    // e.g. { processedIds: string[] }
    const { processedIds } = (await response.json()) as { processedIds?: string[] };

    if (!processedIds || processedIds.length === 0) {
      // Nothing confirmed—keep everything pending
      return;
    }

    // Map processed queue IDs -> corresponding form IDs to mark as synced
    const processedSet = new Set(processedIds);
    const formIdsToMark = pending
      .filter(q =>
        processedSet.has(q.id) &&
        q.table === 'formData' &&
        (q.operation === 'create' || q.operation === 'update') &&
        q?.payload?.id
      )
      .map(q => q.payload.id as string);

    await hipaaDB.transaction('rw', hipaaDB.formData, hipaaDB.syncQueue, async () => {
      // 1) Delete processed queue items
      await hipaaDB.syncQueue.bulkDelete(processedIds);

      // 2) Mark only the corresponding forms as synced
      if (formIdsToMark.length > 0) {
        await hipaaDB.formData
          .where('id')
          .anyOf(formIdsToMark)
          .modify({ pendingSync: false });
      }
    });
  } catch (error) {
    console.info('Sync queued for later (offline)');
  }
}


export async function clearAllClientData(): Promise<void> {
  await hipaaDB.transaction('rw', hipaaDB.formData, hipaaDB.syncQueue, async () => {
    await hipaaDB.formData.clear()
    await hipaaDB.syncQueue.clear()
  })
}