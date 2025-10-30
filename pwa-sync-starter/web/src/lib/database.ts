import Dexie, { Table } from "dexie";

// ---------- Types ----------
export interface Form {
  id: string;
  formType: string;
  data: string;       // JSON string
  timestamp: number;  // ms since epoch
  synced: 0 | 1;      // use number instead of boolean for indexing
}

export interface Cache {
  key: string;
  data: string;       // JSON string
  expiry: number;     // ms since epoch (hard expiration)
  timestamp: number;  // ms since epoch (staleness)
}

export interface SyncQueue {
  id: string;
  endpoint: string;
  method: string;
  data: string;       // JSON string
  retries: number;
  created: number;    // ms since epoch
}

// ---------- Dexie DB ----------
export class LocalDB extends Dexie {
  forms!: Table<Form, string>;
  cache!: Table<Cache, string>;
  sync_queue!: Table<SyncQueue, string>;

  constructor() {
    super("LocalDB");

    // v1: initial schema (if you never had Dexie before, you can start at 1)
    this.version(1).stores({
      // Primary key is first token; the rest are indexes.
      // We can safely index numbers (but not booleans), so `synced` is 0|1.
      forms: "id, formType, timestamp, synced",
      cache: "key, expiry, timestamp",
      sync_queue: "id, endpoint, created",
    });

    // v2: migrate any existing boolean `synced` -> number (0|1) and ensure numeric timestamps
    this.version(2).stores({
      forms: "id, formType, timestamp, synced",
      cache: "key, expiry, timestamp",
      sync_queue: "id, endpoint, created",
    }).upgrade(async tx => {
      await tx.table<Form>("forms").toCollection().modify(f => {
        if (typeof (f as any).synced === "boolean") {
          f.synced = (f as any).synced ? 1 : 0;
        }
        if (f && typeof f.timestamp !== "number") {
          // Attempt to coerce if it was mistakenly stored as Date/string
          const t = (f as any).timestamp;
          const n = typeof t === "string" ? Date.parse(t) : (t instanceof Date ? t.getTime() : NaN);
          if (!Number.isNaN(n)) f.timestamp = n;
        }
      });

      await tx.table<Cache>("cache").toCollection().modify(c => {
        if (c && typeof c.timestamp !== "number") {
          const t = (c as any).timestamp;
          const n = typeof t === "string" ? Date.parse(t) : (t instanceof Date ? t.getTime() : NaN);
          if (!Number.isNaN(n)) c.timestamp = n;
        }
        if (c && typeof c.expiry !== "number") {
          const e = (c as any).expiry;
          const n = typeof e === "string" ? Date.parse(e) : (e instanceof Date ? e.getTime() : NaN);
          if (!Number.isNaN(n)) c.expiry = n;
        }
      });
    });
  }

  // ---------- API ----------
  async saveForm(id: string, formType: string, data: any): Promise<void> {
    await this.forms.put({
      id,
      formType,
      data: JSON.stringify(data),
      timestamp: Date.now(),
      synced: 0,
    });
  }

  async getUnsynced(): Promise<Form[]> {
    // thanks to numeric index, this is fast
    return this.forms.where("synced").equals(0).toArray();
  }

  async markSynced(id: string): Promise<void> {
    await this.forms.update(id, { synced: 1 });
  }

  async clearExpired(maxAge: number = 30 * 60 * 1000): Promise<void> {
    const now = Date.now();
    const cutoff = now - maxAge;

    await this.transaction("rw", [this.forms, this.cache], async () => {
      // remove stale forms by timestamp
      await this.forms.where("timestamp").below(cutoff).delete();

      // remove cache by hard expiry (<= now) …
      await this.cache.where("expiry").below(now).delete();
      // … and also by stale timestamp
      await this.cache.where("timestamp").below(cutoff).delete();
    });
  }
}

// Single shared instance
export const db = new LocalDB();
