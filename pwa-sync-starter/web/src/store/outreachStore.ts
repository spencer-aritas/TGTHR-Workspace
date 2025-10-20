import Dexie, { Table } from 'dexie';
import type { OutreachEncounter } from '../types/outreach';

export class OutreachDB extends Dexie {
  encounters!: Table<OutreachEncounter, number>;

  constructor() {
    super('OutreachDB');
    this.version(1).stores({
      // index by firstName, lastName, start; include synced for fast queries
      encounters: '++id, encounterUuid, personUuid, firstName, lastName, start, synced'
    });
   this.version(2).stores({
  // add encounterUuid/personUuid indexes for idempotent sync
  encounters: '++id, encounterUuid, personUuid, firstName, lastName, start, synced'
  }).upgrade(tx => {
      return tx.table('encounters').toCollection().modify((e: any) => {
        if (!e.synced) e.synced = false;
      });
    });
    
    // optional: on populate or upgrade normalize existing rows
    this.on('ready', async () => {
      await this.table('encounters').toCollection().modify((e: OutreachEncounter) => {
        if (typeof e.synced !== 'boolean') e.synced = false;
      });
    });
  }
}

export const db = new OutreachDB();
