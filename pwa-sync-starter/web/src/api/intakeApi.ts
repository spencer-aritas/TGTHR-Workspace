// web/src/api/intakeApi.ts
import { NewClientIntakeForm, IntakeResponse } from '../types/intake';

export async function submitNewClientIntake(form: NewClientIntakeForm): Promise<IntakeResponse> {
  const API_BASE = import.meta.env.VITE_TGTHR_API ?? 'https://outreachintake.aritasconsulting.com/api';
  const token = localStorage.getItem('sf_jwt') ?? '';
  
  const deviceId = form.deviceId || crypto.randomUUID();
  const userEmail = form.createdByEmail || 'unknown@tgthr.org';
  const userName = form.createdBy || 'Unknown User';
  // First create the person account
  const personResponse = await fetch(`${API_BASE}/sync/PersonAccount`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json', 
      ...(token ? { Authorization: `Bearer ${token}` } : {}) 
    },
    body: JSON.stringify({
      localId: crypto.randomUUID(),
      person: {
        firstName: form.firstName,
        lastName: form.lastName,
        email: form.email,
        phone: form.phone,
        birthdate: form.birthdate,
        notes: form.notes,
        deviceId,
        createdBy: userName,
        createdByEmail: userEmail
      }
    })
  });

  if (!personResponse.ok) {
    throw new Error(`HTTP ${personResponse.status}: ${personResponse.statusText}`);
  }

  const { localId, salesforceId } = await personResponse.json();

  // Then create the program intake
  const intakeResponse = await fetch(`${API_BASE}/sync/ProgramIntake`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json', 
      ...(token ? { Authorization: `Bearer ${token}` } : {}) 
    },
    body: JSON.stringify({
      localId,
      intake: {
        personLocalId: localId,
        programId: 'Street_Outreach', // Default program
        startDate: new Date().toISOString().slice(0,10),
        consentSigned: true,
        notes: form.notes,
        deviceId,
        location: form.location
      }
    })
  });
  
  if (!intakeResponse.ok) {
    throw new Error(`HTTP ${intakeResponse.status}: ${intakeResponse.statusText}`);
  }
  
  await intakeResponse.json(); // Consume the response
  
  return {
    success: true,
    id: salesforceId,
    synced: true
  };
}
