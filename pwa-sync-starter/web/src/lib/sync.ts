// src/lib/sync.ts
import { db } from './db'

// Optional: configure backend base URL (FastAPI proxy that pushes to Salesforce)
const BASE_URL = (window as any).__SYNC_BASE_URL__ || '/api';

async function sendQueue() {
  const pending = await db.outbox.toArray();
  for (const item of pending) {
    try {
      const res = await fetch(`${BASE_URL}/sync/${item.entity}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(item.payload),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      // Apply server ack (e.g., map local id to Salesforce Id)
      if (item.entity === 'PersonAccount') {
        const responseLocalId = data && typeof data === 'object' ? data.localId : undefined;
        const localId = responseLocalId ?? item.payload?.localId;
        if (localId) {
          await db.persons.delete(localId);
        }
      }
      if (item.entity === 'ProgramIntake') {
        const responseLocalId = data && typeof data === 'object' ? data.localId : undefined;
        const localId = responseLocalId ?? item.payload?.localId;
        if (localId) {
          await db.intakes.delete(localId);
        }
      }
      if (item.entity === 'SignatureRecord') {
        const { signatureService } = await import('../services/signatureService');
        await signatureService.uploadToSalesforce(item.payload);
        if (item.payload?.id) {
          await db.signatures.delete(item.payload.id);
        }
      }
      await db.outbox.delete(item.id!);
    } catch (e: any) {
      await db.outbox.update(item.id!, { attempts: item.attempts + 1, lastAttemptAt: new Date().toISOString(), error: String(e) });
    }
  }
}

export async function enqueue(entity: 'PersonAccount' | 'ProgramIntake', payload: any) {
  await db.outbox.add({ entity, payload, createdAt: new Date().toISOString(), attempts: 0 });
}

export async function backgroundSync() {
  if (!navigator.onLine) return;
  await sendQueue();
}

export function startPolling(intervalMs = 60_000) {
  backgroundSync();
  return setInterval(backgroundSync, intervalMs);
}

// Register a simple service worker sync trigger (Progressive enhancement)
export function registerSyncEvents() {
  window.addEventListener('online', backgroundSync);
}
