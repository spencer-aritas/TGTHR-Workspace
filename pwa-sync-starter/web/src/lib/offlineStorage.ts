import { db } from './db';

// Simple offline detection
export function isOnline(): boolean {
  return navigator.onLine;
}

// Store form data locally without network calls
export async function storeFormOffline(formType: string, data: any): Promise<{ localId: string; queued: boolean; synced: boolean }> {
  const localId = crypto.randomUUID();
  
  try {
    if (formType === 'person') {
      // Store person data
      const person = {
        id: localId,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
        phone: data.phone,
        birthdate: data.birthdate,
        street: data.street,
        city: data.city,
        state: data.state,
        postalCode: data.postalCode,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        _status: 'pending' as const
      };
      
      await db.persons.add(person);
      
      // Queue for sync
      await db.outbox.add({
        entity: 'PersonAccount',
        payload: { localId, person: data },
        createdAt: new Date().toISOString(),
        attempts: 0
      });
      
    } else if (formType === 'encounter') {
      // Queue encounter for sync
      await db.outbox.add({
        entity: 'OutreachEncounter' as any,
        payload: { encounterId: localId, ...data },
        createdAt: new Date().toISOString(),
        attempts: 0
      });
    }
    
    console.log(`Stored ${formType} offline:`, localId);
    return { localId, queued: true, synced: false };
    
  } catch (error) {
    console.error('Failed to store offline:', error);
    throw error;
  }
}

// Get offline queue count
export async function getOfflineQueueCount(): Promise<number> {
  try {
    return await db.outbox.count();
  } catch {
    return 0;
  }
}