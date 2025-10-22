// web/src/types/intake.ts
export * from '../shared/contracts/IntakeContract';

export interface IntakeResponse {
  success: boolean;
  id: string;
}

export interface NewClientIntakePayload {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
}

export interface NewClientIntakeForm {
  firstName: string;
  lastName: string;
  phone?: string;
  email?: string;
  birthdate?: string;
  notes: string;
}

export function createIntakeDefaults(): NewClientIntakeForm {
  return {
    firstName: '',
    lastName: '',
    notes: ''
  };
}