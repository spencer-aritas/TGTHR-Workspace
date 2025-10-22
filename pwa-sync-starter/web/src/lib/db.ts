// src/lib/db.ts
import Dexie, { Table } from 'dexie'

export interface PersonAccount {
  id?: string;           // local uuid
  accountId?: string;    // Salesforce Id when synced
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  birthdate?: string;    // ISO date
  street?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  createdAt: string;     // ISO
  updatedAt: string;     // ISO
  _status: 'pending' | 'synced' | 'error' | 'conflict';
}

export interface ProgramIntake {
  id?: string;
  personLocalId: string;     // FK to PersonAccount.id
  programId: string;         // External program key (Salesforce Program__c Id or a code)
  startDate: string;         // ISO
  consentSigned: boolean;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  _status: 'pending' | 'synced' | 'error' | 'conflict';
}

export interface SignatureRecord {
  id?: string;
  dataURL: string;
  timestamp: string;
  recordId?: string;
  recordType?: string;
  synced: boolean;
}

export interface OutboxItem {
  id?: number;
  entity: 'PersonAccount' | 'ProgramIntake' | 'SignatureRecord';
  payload: any;
  createdAt: string;
  attempts: number;
  lastAttemptAt?: string;
  error?: string;
}

export class AppDB extends Dexie {
  persons!: Table<PersonAccount, string>;
  intakes!: Table<ProgramIntake, string>;
  signatures!: Table<SignatureRecord, string>;
  outbox!: Table<OutboxItem, number>;

  constructor() {
    super('pwa_local_db');
    this.version(1).stores({
      persons: 'id, accountId, lastName, email, _status, updatedAt',
      intakes: 'id, personLocalId, programId, _status, updatedAt',
      signatures: 'id, recordId, recordType, timestamp, synced',
      outbox: '++id, entity, createdAt'
    });
  }
}

export const db = new AppDB();
