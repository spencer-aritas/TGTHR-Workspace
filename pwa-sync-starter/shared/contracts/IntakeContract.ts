// shared/contracts/IntakeContract.ts
// Contract between PWA and Salesforce for New Client Intake

export interface PersonAccountData {
  uuid: string;
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  birthdate?: string;
  street?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  genderIdentity?: string;
  pronouns?: string;
  hmisId?: string;
  notes?: string;
  createdBy: string;
  createdByEmail: string;
  deviceId: string;
}

export interface ProgramEnrollmentData {
  uuid: string;
  personUuid: string;
  programName: string; // "Street Outreach"
  status: 'Enrolled' | 'Active';
  startDate: string;
  endDate?: string;
}

export interface BenefitAssignmentData {
  uuid: string;
  personUuid: string;
  programEnrollmentUuid: string;
  benefitId: string;
  benefitName: string;
  status: 'Active';
  frequency?: string;
  amount?: number;
  balance?: number;
}

export interface InteractionSummaryData {
  uuid: string;
  personUuid: string;
  programUuid: string;
  programEnrollmentUuid: string;
  summary: string;
  interactionType: 'Street Outreach Encounter';
  interactionDate: string;
  isPrivate: boolean;
}

export interface TaskData {
  uuid: string;
  personUuid: string;
  subject: string;
  description: string;
  priority: 'Normal' | 'High';
  status: 'Not Started' | 'In Progress' | 'Completed';
  dueDate?: string;
  assignedToEmail: string;
}

export interface NewClientIntakePayload {
  encounter: {
    encounterUuid: string;
    personUuid: string;
    firstName: string;
    lastName: string;
    start: string;
    end: string;
    pos: string;
    isCrisis: boolean;
    notes: string;
    location?: string;
    services?: string;
    deviceId: string;
  };
  personAccount: PersonAccountData;
  programEnrollment: ProgramEnrollmentData;
  benefitAssignments: BenefitAssignmentData[];
  interactionSummary: InteractionSummaryData;
  followUpTask: TaskData;
  createdBy: {
    email: string;
    name: string;
    deviceId: string;
  };
}

export interface IntakeResponse {
  success: boolean;
  encounterId: string;
  personAccountId?: string;
  programEnrollmentId?: string;
  benefitAssignmentIds?: string[];
  interactionSummaryId?: string;
  taskId?: string;
  errors?: string[];
  synced: boolean;
}

// Salesforce Service Interface
export interface SalesforceIntakeService {
  createPersonAccount(data: PersonAccountData): Promise<string>;
  createProgramEnrollment(data: ProgramEnrollmentData): Promise<string>;
  createBenefitAssignments(data: BenefitAssignmentData[]): Promise<string[]>;
  createInteractionSummary(data: InteractionSummaryData): Promise<string>;
  createTask(data: TaskData): Promise<string>;
  processFullIntake(payload: NewClientIntakePayload): Promise<IntakeResponse>;
}