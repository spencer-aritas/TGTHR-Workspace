// web/src/store/intakeStore.ts
import Dexie, { Table } from 'dexie';
import type { NewClientIntakeForm } from '../types/intake';

export interface StoredIntake extends NewClientIntakeForm {
  id?: number;
  encounterUuid: string;
  personUuid: string;
  createdAt: string;
  synced: boolean;
  syncedAt?: string;
  error?: string;
}

export class IntakeDB extends Dexie {
  intakes!: Table<StoredIntake, number>;

  constructor() {
    super('IntakeDB');
    this.version(1).stores({
      intakes: '++id, encounterUuid, personUuid, firstName, lastName, synced, createdAt'
    });
  }
}

export const intakeDb = new IntakeDB();