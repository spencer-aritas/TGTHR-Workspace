import { db } from '../store/outreachStore';
import { submitOutreachEncounter } from '../api/outreachApi';
import type { OutreachEncounter } from '../types/outreach';

export async function syncOutreachEncounters(): Promise<void> {
  const all = await db.encounters.toArray();
  const pending = all.filter(e => e.synced !== true);

  for (const e of pending) {
    const payload: OutreachEncounter = {
      ...e,
      firstName: e.firstName ?? '',
      lastName: e.lastName ?? '(Unknown)',
      pos: e.pos ?? '27',
      isCrisis: e.isCrisis ?? false,
      notes: e.notes ?? '',
      start: e.start ?? new Date().toISOString(),
      end: e.end ?? new Date(Date.now() + 15 * 60000).toISOString(),
      synced: false
    };

    try {
      const res = await submitOutreachEncounter(payload);
      if (res.ok) {
        await db.encounters.update(e.id!, { synced: true });
      } else {
        console.warn('Outreach sync failed with status', res.status);
      }
    } catch (err) {
      console.error('Outreach sync error', err);
    }
  }
}
