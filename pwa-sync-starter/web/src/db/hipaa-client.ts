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
  const pending = await hipaaDB.syncQueue.toArray()
  if (pending.length === 0) return

  try {
    const response = await fetch('/api/sync/forms', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(pending)
    })

    if (response.ok) {
      const { processedIds } = await response.json()
      await hipaaDB.transaction('rw', hipaaDB.formData, hipaaDB.syncQueue, async () => {
        for (const id of processedIds) {
          await hipaaDB.syncQueue.delete(id)
        }
        // Mark synced forms
        await hipaaDB.formData.where('pendingSync').equals(true).modify({ pendingSync: false })
      })
    }
  } catch (error) {
    console.info('Sync queued for later (offline)')
  }
}

export async function clearAllClientData(): Promise<void> {
  await hipaaDB.transaction('rw', hipaaDB.formData, hipaaDB.syncQueue, async () => {
    await hipaaDB.formData.clear()
    await hipaaDB.syncQueue.clear()
  })
}