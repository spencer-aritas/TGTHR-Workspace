import { db } from './db';

// Offline-first API with automatic local storage
export const postSync = async (endpoint: string, payload: any): Promise<any> => {
  try {
    // Try online first
    const response = await fetch(`/api${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    if (response.ok) {
      return response.json();
    }
    throw new Error(`API call failed: ${response.status}`);
  } catch (error) {
    // Store offline and queue for sync
    console.log('Storing offline:', endpoint, payload);
    
    if (endpoint.includes('PersonAccount')) {
      return await storePersonOffline(payload);
    } else if (endpoint.includes('outreach-intake')) {
      return await storeEncounterOffline(payload);
    }
    
    // Fallback: store in outbox
    await db.outbox.add({
      entity: 'Generic' as any,
      payload: { endpoint, ...payload },
      createdAt: new Date().toISOString(),
      attempts: 0
    });
    
    return { queued: true, localId: crypto.randomUUID() };
  }
};

async function storePersonOffline(payload: any) {
  const localId = crypto.randomUUID();
  
  const person = {
    id: localId,
    firstName: payload.person?.firstName || payload.firstName,
    lastName: payload.person?.lastName || payload.lastName,
    email: payload.person?.email || payload.email,
    phone: payload.person?.phone || payload.phone,
    birthdate: payload.person?.birthdate || payload.birthdate,
    street: payload.person?.street || payload.street,
    city: payload.person?.city || payload.city,
    state: payload.person?.state || payload.state,
    postalCode: payload.person?.postalCode || payload.postalCode,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    _status: 'pending' as const
  };
  
  await db.persons.add(person);
  
  // Queue for sync
  await db.outbox.add({
    entity: 'PersonAccount',
    payload: { localId, person },
    createdAt: new Date().toISOString(),
    attempts: 0
  });
  
  return { queued: true, localId, synced: false };
}

async function storeEncounterOffline(payload: any) {
  const encounterId = crypto.randomUUID();
  
  // Queue for sync
  await db.outbox.add({
    entity: 'OutreachEncounter' as any,
    payload: { encounterId, ...payload },
    createdAt: new Date().toISOString(),
    attempts: 0
  });
  
  return { queued: true, encounterId, status: 'queued' };
}