// shared/contracts/InterviewContract.ts
// Contract for Interview__c object from Salesforce

import type { InterviewTemplate } from './InterviewTemplateContract';
import type { InterviewQuestion } from './InterviewQuestionContract';

export type InterviewStatus =
  | 'Draft'
  | 'InProgress'
  | 'PendingSignatures'
  | 'Submitted'
  | 'Completed'
  | 'Archived';

export type InterviewRiskLevel = 'Low' | 'Moderate' | 'High' | 'Critical';

/**
 * Interview__c - Completed interview instance with answers
 * Maps to Salesforce custom object
 */
export interface Interview {
  // Standard Salesforce fields
  Id?: string;
  OwnerId?: string;
  IsDeleted?: boolean;
  Name?: string;
  CreatedDate?: string;
  CreatedById?: string;
  LastModifiedDate?: string;
  LastModifiedById?: string;
  SystemModstamp?: string;
  LastActivityDate?: string | null;
  LastViewedDate?: string | null;
  LastReferencedDate?: string | null;

  // Custom fields
  Client__c?: string | null;
  Case__c?: string | null;
  Program_Enrollment__c?: string | null;
  Interaction_Summary__c?: string | null;
  InterviewTemplateVersion__c?: string | null;
  Status__c?: InterviewStatus | string | null;
  Started_On__c?: string | null;
  Completed_On__c?: string | null;
  Client_Signed__c?: boolean;
  Staff_Signed__c?: boolean;
  Date_Client_Signed__c?: string | null;
  Date_Staff_Signed__c?: string | null;
  Client_Signature_File_Id__c?: string | null;
  Staff_Signature_File_Id__c?: string | null;
  PDF_File_Id__c?: string | null;
  Risk_Level__c?: InterviewRiskLevel | string | null;
  UUID__c?: string | null;

  // Relationship fields (populated when queried with __r syntax)
  Client__r?: {
    Id: string;
    Name: string;
    FirstName?: string;
    LastName?: string;
    PersonPronouns?: string;
    PersonBirthdate?: string;
    MEDICAID_Number__pc?: string;
  };

  Case__r?: {
    Id: string;
    CaseNumber: string;
    Status: string;
    Owner?: {
      Name: string;
    };
  };

  Interaction_Summary__r?: {
    Id: string;
    Name: string;
    Date_of_Interaction__c?: string;
    AccountId?: string;
  };

  InterviewTemplateVersion__r?: {
    Id: string;
    Name: string;
    Version__c?: number;
    Status__c?: string;
    InterviewTemplate__c?: string;
    InterviewTemplate__r?: {
      Id: string;
      Name: string;
      Category__c?: string;
    };
  };

  Program_Enrollment__r?: {
    Id: string;
    Name: string;
    Status?: string;
    ProgramId?: string;
    AccountId?: string;
  };

  // Convenience properties for PWA (camelCase)
  id?: string;
  uuid?: string;
  name?: string;
  interviewTemplateVersionId?: string;
  interviewTemplateVersionUuid?: string;
  caseId?: string;
  clientId?: string;
  programEnrollmentId?: string;
  interactionSummaryId?: string;
  status?: string;
  riskLevel?: string;
  startedOn?: string;
  completedOn?: string;
  startedById?: string;
  ownerId?: string;
  staffSigned?: boolean;
  staffSignatureFileId?: string;
  dateStaffSigned?: string;
  clientSigned?: boolean;
  clientSignatureFileId?: string;
  dateClientSigned?: string;
  pdfFileId?: string;
  uuidExternalId?: string;
}

// ============================================================================
// SERVICE LAYER TYPES (for PWA API interactions)
// ============================================================================

export type InterviewResponseType =
  | 'text'
  | 'textarea'
  | 'number'
  | 'boolean'
  | 'picklist'
  | 'multi_picklist'
  | 'date'
  | 'datetime'
  | 'score'
  | 'signature'
  | 'file';

/**
 * Draft types for creating new templates (camelCase for PWA compatibility)
 */
export interface InterviewTemplateDraft {
  uuid?: string;
  name: string;
  programId?: string;
  category?: string;
  active: boolean;
}

export interface InterviewTemplateVersionDraft {
  uuid?: string;
  name: string;
  versionNumber: number;
  status: string;
  variant: string;
  effectiveFrom?: string;
  effectiveTo?: string;
}

export interface InterviewQuestionDraft {
  uuid?: string;
  name: string;
  apiName: string;
  label: string;
  section?: string;
  helpText?: string;
  mapsTo?: string;
  order: number;
  responseType: InterviewResponseType;
  required: boolean;
  sensitive?: boolean;
  scoreWeight?: number;
  picklistValues?: Array<{
    value: string;
    label?: string;
    isDefault?: boolean;
  }>;
}

/**
 * Request/Response types for service layer
 */
export interface InterviewTemplateUpsertRequest {
  template: InterviewTemplateDraft;
  version: InterviewTemplateVersionDraft;
  questions: InterviewQuestionDraft[];
}

export interface InterviewTemplateUpsertResult {
  templateId: string;
  templateUuid: string;
  templateVersionId: string;
  templateVersionUuid: string;
  questionIds: string[];
}

export interface InterviewCreationRequest {
  interviewTemplateVersionId?: string;
  interviewTemplateVersionUuid: string;
  caseId?: string;
  clientId?: string;
  programEnrollmentId?: string;
  interactionSummaryId?: string;
  startedOn?: string;
  ownerId?: string;
  createdById?: string;
  answers?: Array<{
    uuid?: string;
    interviewQuestionUuid: string;
    questionApiName: string;
    section?: string;
    responseBoolean?: boolean;
    responseDate?: string;
    responseDateTime?: string;
    responseNumber?: number;
    responsePicklist?: string | string[];
    responseScore?: string;
    responseText?: string;
    isObfuscated?: boolean;
  }>;
}

export interface InterviewCreationResult {
  interviewId: string;
  interviewUuid: string;
  pdfFileId?: string;
  staffSignatureRequired?: boolean;
  clientSignatureRequired?: boolean;
}

/**
 * Service interface for PWA consumption
 */
export interface InterviewService {
  listTemplates(params?: {
    programId?: string;
    variant?: string;
    status?: string;
    includeInactive?: boolean;
  }): Promise<Array<{
    templateId: string;
    templateVersionId: string;
    templateName: string;
    versionName: string;
    category?: string;
    variant?: string;
    status?: string;
    effectiveFrom?: string;
    effectiveTo?: string;
    template?: InterviewTemplate;
    questions?: InterviewQuestion[];
    uuid?: string;
  }>>;
  upsertTemplate(payload: InterviewTemplateUpsertRequest): Promise<InterviewTemplateUpsertResult>;
  createInterview(request: InterviewCreationRequest): Promise<InterviewCreationResult>;
}
