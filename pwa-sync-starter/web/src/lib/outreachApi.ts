// web/src/lib/outreachApi.ts
export interface PersonAccountPayload {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  birthdate?: string;
  street?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  genderIdentity?: string;
  pronouns?: string;
  hmisId?: string;
}

export interface OutreachEncounterPayload {
  personLocalId: string;
  encounterDate: string;
  location: string;
  notes: string;
  services?: string;
  followUpNeeded: boolean;
  deviceId: string;
}

export interface PersonAccountResponse {
  localId: string;
  salesforceId?: string;
  synced: boolean;
}

export interface OutreachEncounterResponse {
  encounterId: string;
  status: string;
}

export interface SyncStatus {
  unsyncedPeople: number;
  unsyncedEncounters: number;
}

export async function createPersonAccount(payload: PersonAccountPayload): Promise<PersonAccountResponse> {
  try {
    const res = await fetch('/api/quick-person-account', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    if (res.ok) {
      return res.json();
    }
    throw new Error(`Failed to create person account: ${res.statusText}`);
  } catch (error) {
    // Store offline
    const { db } = await import('./db');
    const localId = crypto.randomUUID();
    
    const person = {
      id: localId,
      firstName: payload.firstName,
      lastName: payload.lastName,
      email: payload.email,
      phone: payload.phone,
      birthdate: payload.birthdate,
      street: payload.street,
      city: payload.city,
      state: payload.state,
      postalCode: payload.postalCode,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      _status: 'pending' as const
    };
    
    await db.persons.add(person);
    
    // Queue for sync
    await db.outbox.add({
      entity: 'PersonAccount',
      payload: { localId, person: payload },
      createdAt: new Date().toISOString(),
      attempts: 0
    });
    
    return { localId, synced: false };
  }
}

export async function submitOutreachEncounter(payload: OutreachEncounterPayload): Promise<OutreachEncounterResponse> {
  try {
    const res = await fetch('/api/outreach-intake', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    if (res.ok) {
      return res.json();
    }
    throw new Error(`Failed to submit encounter: ${res.statusText}`);
  } catch (error) {
    // Store offline
    const { db } = await import('./db');
    const encounterId = crypto.randomUUID();
    
    // Queue for sync
    await db.outbox.add({
      entity: 'OutreachEncounter' as any,
      payload: { encounterId, ...payload },
      createdAt: new Date().toISOString(),
      attempts: 0
    });
    
    return { encounterId, status: 'queued' };
  }
}

export async function getSyncStatus(): Promise<SyncStatus> {
  const res = await fetch('/api/outreach/sync-status');
  
  if (!res.ok) {
    throw new Error(`Failed to get sync status: ${res.statusText}`);
  }
  
  return res.json();
}

export async function syncOutreachData(): Promise<{ success: boolean; result: any }> {
  const res = await fetch('/api/outreach/sync', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  
  if (!res.ok) {
    throw new Error(`Sync failed: ${res.statusText}`);
  }
  
  return res.json();
}

// Generate device ID for tracking
export function getDeviceId(): string {
  let deviceId = localStorage.getItem('deviceId');
  if (!deviceId) {
    deviceId = crypto.randomUUID();
    localStorage.setItem('deviceId', deviceId);
  }
  return deviceId;
}