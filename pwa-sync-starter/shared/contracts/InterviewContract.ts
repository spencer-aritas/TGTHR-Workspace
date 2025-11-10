// shared/contracts/InterviewContract.ts
// Contract between the PWA and Salesforce for dynamic Interviews

export type InterviewTemplateCategory =
  | 'Intake'
  | 'Assessment'
  | 'CaseManagement'
  | 'Clinical'
  | 'Compliance'
  | 'Custom';

export type InterviewTemplateStatus = 'Draft' | 'Active' | 'Inactive' | 'Archived';

export type InterviewTemplateVariant =
  | 'Standard'
  | 'Clinician'
  | 'CaseManager'
  | 'PeerSpecialist'
  | 'Supervisor'
  | 'Custom';

export interface InterviewTemplate {
  id?: string;
  uuid: string;
  name: string;
  programId?: string;
  category?: InterviewTemplateCategory | string;
  active: boolean;
  ownerId?: string;
  createdById?: string;
  lastModifiedById?: string;
}

export interface InterviewTemplateVersion {
  id?: string;
  uuid: string;
  templateId?: string;
  templateUuid: string;
  name: string;
  versionNumber: number;
  status: InterviewTemplateStatus;
  variant: InterviewTemplateVariant | string;
  effectiveFrom?: string;
  effectiveTo?: string;
  ownerId?: string;
  createdById?: string;
  lastModifiedById?: string;
  template?: InterviewTemplate;
  questions?: InterviewQuestion[];
}

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

export interface InterviewQuestionPicklistValue {
  value: string;
  label?: string;
  isDefault?: boolean;
}

export interface InterviewQuestion {
  id?: string;
  uuid: string;
  name: string;
  templateVersionId?: string;
  templateVersionUuid: string;
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
  picklistValues?: InterviewQuestionPicklistValue[];
  ownerId?: string;
  createdById?: string;
  lastModifiedById?: string;
}

export type InterviewStatus =
  | 'Draft'
  | 'InProgress'
  | 'PendingSignatures'
  | 'Completed'
  | 'Archived';

export type InterviewRiskLevel = 'Low' | 'Moderate' | 'High' | 'Critical';

export interface Interview {
  id?: string;
  uuid: string;
  name: string;
  interviewTemplateVersionId?: string;
  interviewTemplateVersionUuid: string;
  caseId?: string;
  clientId?: string;
  programEnrollmentId?: string;
  interactionSummaryId?: string;
  status: InterviewStatus;
  riskLevel?: InterviewRiskLevel;
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

export interface InterviewAnswer {
  id?: string;
  uuid: string;
  interviewId?: string;
  interviewUuid: string;
  interviewQuestionId?: string;
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
  ownerId?: string;
  createdById?: string;
  lastModifiedById?: string;
}

export interface InterviewTemplateDraft
  extends Pick<InterviewTemplate, 'name' | 'programId' | 'category' | 'active'> {
  uuid?: string;
}

export interface InterviewTemplateVersionDraft
  extends Pick<
    InterviewTemplateVersion,
    'name' | 'versionNumber' | 'status' | 'variant' | 'effectiveFrom' | 'effectiveTo'
  > {
  uuid?: string;
}

export interface InterviewQuestionDraft
  extends Pick<
    InterviewQuestion,
    | 'name'
    | 'apiName'
    | 'label'
    | 'section'
    | 'helpText'
    | 'mapsTo'
    | 'order'
    | 'responseType'
    | 'required'
    | 'sensitive'
    | 'scoreWeight'
    | 'picklistValues'
  > {
  uuid?: string;
}

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
  answers?: InterviewAnswer[];
}

export interface InterviewCreationResult {
  interviewId: string;
  interviewUuid: string;
  pdfFileId?: string;
  staffSignatureRequired?: boolean;
  clientSignatureRequired?: boolean;
}

export interface InterviewService {
  listTemplates(params?: {
    programId?: string;
    variant?: InterviewTemplateVariant | string;
    status?: InterviewTemplateStatus;
    includeInactive?: boolean;
  }): Promise<InterviewTemplateVersion[]>;
  upsertTemplate(payload: InterviewTemplateUpsertRequest): Promise<InterviewTemplateUpsertResult>;
  createInterview(request: InterviewCreationRequest): Promise<InterviewCreationResult>;
}
