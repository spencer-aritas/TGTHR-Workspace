// shared/contracts/InteractionDetailContract.ts
// Rich DTO returned by GET /api/interaction-summary/{interactionId}.

export interface InteractionDetailSummary {
  id: string;
  name?: string;
  kind?: string;
  status?: string;
  interactionPurpose?: string;
}

export interface InteractionDetailChronology {
  interactionDate?: string;
  startTime?: string;
  endTime?: string;
  createdDate?: string;
  lastModifiedDate?: string;
}

export interface InteractionDetailOwnership {
  createdByName?: string;
  actionAssignedToName?: string;
  managerApproverName?: string;
}

export interface InteractionDetailContent {
  notesHtml?: string;
  notesText?: string;
}

export interface InteractionDetailLinkage {
  caseId?: string;
  accountId?: string;
  interviewId?: string;
  interviewStatus?: string;
  interviewTemplateName?: string;
}

export interface InteractionDetailSignature {
  requiresManagerApproval?: boolean;
  managerSigned?: boolean;
  managerRejected?: boolean;
  signatureState?: 'none' | 'pending' | 'signed' | 'rejected';
}

export interface InteractionDetailActions {
  canOpenInterview: boolean;
  canAddQuickNote: boolean;
  canRequestSignature: boolean;
}

export interface InteractionDetailGoal {
  id: string;
  name?: string;
  status?: string;
  description?: string;
}

export interface InteractionDetailBenefit {
  id: string;
  name?: string;
  status?: string;
  amount?: number;
}

export interface InteractionDetailDiagnosis {
  id: string;
  name?: string;
  code?: string;
  description?: string;
}

export interface InteractionDetailCPTCode {
  id: string;
  code?: string;
  description?: string;
}

export interface InteractionDetailRelatedRecords {
  goals: InteractionDetailGoal[];
  benefits: InteractionDetailBenefit[];
  diagnoses: InteractionDetailDiagnosis[];
  cptCodes: InteractionDetailCPTCode[];
}

export interface InteractionDetailInterviewAnswer {
  section: string;
  label: string;
  value: string;
  responseType?: string;
  order?: number;
}

export interface InteractionDetailResponse {
  summary: InteractionDetailSummary;
  chronology: InteractionDetailChronology;
  ownership: InteractionDetailOwnership;
  content: InteractionDetailContent;
  linkage: InteractionDetailLinkage;
  signature: InteractionDetailSignature;
  actions: InteractionDetailActions;
  relatedRecords: InteractionDetailRelatedRecords;
  interviewAnswers?: InteractionDetailInterviewAnswer[];
}
