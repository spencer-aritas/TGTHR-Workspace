import type { OutreachEncounterPayload } from '../types/outreach';

export async function submitOutreachEncounter(enc: OutreachEncounterPayload): Promise<Response> {
  const API_BASE = import.meta.env.VITE_TGTHR_API ?? 'https://docgen.tgthr.org/api';
  const token = localStorage.getItem('sf_jwt') ?? '';
  return fetch(`${API_BASE}/outreach-intake`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(enc)
  });
}
