export interface OutreachEncounter {
  id?: number;                 // Dexie local PK (number, auto)
  encounterUuid: string;       // business key for the encounter
  personUuid: string;          // business key for the Person Account
  firstName: string;
  lastName: string;
  start: string;
  end: string;
  pos: string;
  isCrisis: boolean;
  notes: string;
  synced?: boolean;
}

export type OutreachEncounterPayload = Omit<OutreachEncounter, 'id'|'synced'>;

export function newEncounterDefaults(): OutreachEncounter {
  const start = new Date();
  const end = new Date(start.getTime() + 15*60000);
  const gen = () => (globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2) + Date.now());
  return {
    encounterUuid: gen(),
    personUuid: gen(),
    firstName: '',
    lastName: '(Unknown)',
    start: start.toISOString(),
    end: end.toISOString(),
    pos: '27',
    isCrisis: false,
    notes: '',
    synced: false
  };
}
