
import Dexie, { Table } from 'dexie'
// Using crypto.randomUUID instead of uuid package
const uuid = () => crypto.randomUUID()

export interface Note {
  id: string
  enrolleeId?: string
  body: string
  createdAt: string  // ISO
  updatedAt: string
  deviceId: string
  version?: number
  pendingSync?: boolean
}

export interface Mutation {
  id: string
  table: 'notes'
  op: 'insert'|'update'|'delete'
  payload: any
  clientTs: string
  deviceId: string
}

export interface Meta {
  key: string
  value: string
}

export class LocalDB extends Dexie {
  notes!: Table<Note, string>
  mutations!: Table<Mutation, string>
  meta!: Table<Meta, string>
  constructor() {
    super('LocalDB')
    this.version(2).stores({
      notes: 'id, updatedAt, pendingSync',
      mutations: 'id, table, clientTs',
      meta: 'key'
    })
  }
}

export const db = new LocalDB()

export async function deviceId(): Promise<string> {
  const record = await db.table('meta').get('deviceId')
  if (record?.value) return record.value as string
  (async () => {
    const existing = await db.meta.get('deviceId')
    if (!existing) await db.meta.put({ key: 'deviceId', value: uuid() })
  })()
  return 'dev' // placeholder until first call sets it; we always read from db when needed
}

export async function getDeviceId(): Promise<string> {
  const rec = await db.meta.get('deviceId')
  if (rec?.value) return rec.value
  const id = uuid()
  await db.meta.put({ key: 'deviceId', value: id })
  return id
}

export async function getNotes(): Promise<Note[]> {
  return db.notes.orderBy('updatedAt').reverse().toArray()
}

export async function addNote(input: { body: string }) {
  const now = new Date().toISOString()
  const did = await getDeviceId()
  const note: Note = {
    id: uuid(),
    body: input.body,
    createdAt: now,
    updatedAt: now,
    deviceId: did,
    pendingSync: true
  }
  await db.transaction('rw', db.notes, db.mutations, async () => {
    await db.notes.put(note)
    const mut: Mutation = {
      id: uuid(),
      table: 'notes',
      op: 'insert',
      payload: note,
      clientTs: now,
      deviceId: did
    }
    await db.mutations.put(mut)
  })
}

// --- Sync helpers ---
export async function pushPendingMutations(): Promise<void> {
  const muts = await db.mutations.toArray()
  if (muts.length === 0) return
  try {
    const res = await fetch('/api/sync/upload', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(muts)
    })
    if (!res.ok) throw new Error('upload failed')
    const data = await res.json()
    const accepted: string[] = data.acceptedIds || []
    const serverVersion: number = data.serverVersion || 0

    await db.transaction('rw', db.notes, db.mutations, db.meta, async () => {
      for (const id of accepted) await db.mutations.delete(id)
      // mark notes as synced
      for (const m of muts) {
        if (accepted.includes(m.id) && m.table === 'notes' && m.op !== 'delete') {
          const n = await db.notes.get(m.payload.id)
          if (n) await db.notes.update(n.id, { pendingSync: false, version: serverVersion })
        }
      }
      await db.meta.put({ key: 'lastServerVersion', value: String(serverVersion) })
    })
  } catch (err) {
    // The Workbox Background Sync plugin in the SW will queue this POST and replay later.
    // No-op here; the failed request is handled by SW.
    console.info('pushPendingMutations: queued by Service Worker (offline?)')
  }

  // Pull deltas after push
  const last = await db.meta.get('lastServerVersion')
  const since = Number(last?.value || '0')
  try {
    const res = await fetch(`/api/sync/pull?since=${since}`)
    if (res.ok) {
      const payload = await res.json()
      const { notes = [], serverVersion = since } = payload
      await db.transaction('rw', db.notes, db.meta, async () => {
        for (const n of notes) await db.notes.put(n)
        await db.meta.put({ key: 'lastServerVersion', value: String(serverVersion) })
      })
    }
  } catch {}
}
