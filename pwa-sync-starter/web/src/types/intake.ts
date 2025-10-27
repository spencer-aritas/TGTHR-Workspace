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
}

export function createIntakeDefaults(): NewClientIntakeForm {
  return {
    firstName: '',
    lastName: '',
    notes: '',
    location: undefined
  };
}
