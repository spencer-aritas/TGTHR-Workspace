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
  
  const response = await fetch(`${API_BASE}/new-client-intake`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json', 
      ...(token ? { Authorization: `Bearer ${token}` } : {}) 
    },
    body: JSON.stringify(payload)
  });
  
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  
  return response.json();
}
