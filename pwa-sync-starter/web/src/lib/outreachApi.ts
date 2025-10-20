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
  const res = await fetch('/api/quick-person-account', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  
  if (!res.ok) {
    throw new Error(`Failed to create person account: ${res.statusText}`);
  }
  
  return res.json();
}

export async function submitOutreachEncounter(payload: OutreachEncounterPayload): Promise<OutreachEncounterResponse> {
  const res = await fetch('/api/outreach-intake', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  
  if (!res.ok) {
    throw new Error(`Failed to submit encounter: ${res.statusText}`);
  }
  
  return res.json();
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