// web/src/api/intakeApi.ts
import { NewClientIntakeForm, NewClientIntakePayload, IntakeResponse } from '../types/intake';

export async function submitNewClientIntake(form: NewClientIntakeForm): Promise<IntakeResponse> {
  const API_BASE = import.meta.env.VITE_TGTHR_API ?? 'https://docgen.tgthr.org/api';
  const token = localStorage.getItem('sf_jwt') ?? '';
  
  const now = new Date();
  const deviceId = localStorage.getItem('deviceId') || crypto.randomUUID();
  const userEmail = localStorage.getItem('userEmail') || 'unknown@tgthr.org';
  const userName = localStorage.getItem('userName') || 'Unknown User';
  const location = form.location
    ? {
        latitude: form.location.latitude,
        longitude: form.location.longitude,
        accuracy: form.location.accuracy,
        altitude: form.location.altitude,
        heading: form.location.heading,
        speed: form.location.speed,
        timestamp: form.location.timestamp,
        address: form.location.address,
        source: form.location.source ?? 'device'
      }
    : undefined;
  
  const payload = {
    encounterUuid: crypto.randomUUID(),
    personUuid: crypto.randomUUID(),
    firstName: form.firstName,
    lastName: form.lastName,
    phone: form.phone,
    email: form.email,
    birthdate: form.birthdate,
    notes: form.notes,
    startUtc: now.toISOString(),
    endUtc: new Date(now.getTime() + 15 * 60000).toISOString(),
    pos: '27',
    isCrisis: false,
    deviceId,
    createdBy: userName,
    createdByEmail: userEmail,
    ...(location ? { location } : {})
  };
  
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
        deviceId
      }
    })
  });
  
  if (!intakeResponse.ok) {
    throw new Error(`HTTP ${intakeResponse.status}: ${intakeResponse.statusText}`);
  }
  
  const intakeResult = await intakeResponse.json();
  
  return {
    success: true,
    id: salesforceId,
    synced: true
  };
}
