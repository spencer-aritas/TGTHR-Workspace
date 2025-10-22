export interface NewClientIntakePayload {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
}

export interface IntakeResponse {
  success: boolean;
  id: string;
}