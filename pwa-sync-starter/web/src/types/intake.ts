// web/src/types/intake.ts
export * from '../shared/contracts/IntakeContract';

export interface IntakeResponse {
  success: boolean;
  id: string;
  synced?: boolean;
  errors?: string[];
}

export interface NewClientIntakePayload {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  birthdate?: string;
  notes: string;
  startUtc: string;
  endUtc: string;
  pos: string;
  isCrisis: boolean;
  deviceId: string;
  createdBy: string;
  createdByEmail: string;
  location?: IntakeLocation;
}

export interface IntakeLocationAddress {
  street?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
  formatted?: string;
}

export interface IntakeLocation {
  latitude: number;
  longitude: number;
  accuracy?: number | null;
  altitude?: number | null;
  heading?: number | null;
  speed?: number | null;
  timestamp: string;
  address?: IntakeLocationAddress;
  source?: 'device' | 'manual' | 'synced';
}

export interface NewClientIntakeForm {
  firstName: string;
  lastName: string;
  phone?: string;
  email?: string;
  birthdate?: string;
  notes: string;
  location?: IntakeLocation;
  encounterUuid?: string;
  personUuid?: string;
  deviceId?: string;
  createdBy?: string;
  createdByEmail?: string;
  createdBySfUserId?: string;
  startUtc: string;
  endUtc: string;
}

export function createIntakeDefaults(): NewClientIntakeForm {
  return {
    firstName: '',
    lastName: '',
    notes: '',
    location: undefined,
    startUtc: new Date().toISOString(),
    endUtc: new Date(Date.now() + 60 * 60 * 1000).toISOString()
  };
}
