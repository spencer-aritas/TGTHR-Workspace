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
  /** Clinical Note: Reason for Visit (MeetingNotes) */
  reasonForVisit?: string;
  /** Clinical Note: Description of Services Provided */
  descriptionOfServices?: string;
  /** Clinical Note: Response and Progress */
  responseAndProgress?: string;
  /** Clinical Note: Plan */
  plan?: string;
  /** Place of Service */
  placeOfService?: string;
  /** Interpreter Used (Yes/No) */
  interpreterUsed?: string;
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
  managerApproverId?: string;
}

export interface InteractionDetailActions {
  canOpenInterview: boolean;
  canAddQuickNote: boolean;
  canApproveAsManager: boolean;
}

export interface InteractionDetailGoal {
  id: string;
  name?: string;
  status?: string;
  description?: string;
  priority?: string;
  narrative?: string;
  progressBefore?: number;
  progressAfter?: number;
  timeSpentMinutes?: number;
}

export interface InteractionDetailService {
  id: string;
  name?: string;
  status?: string;
  amount?: number;
  date?: string;
}

export interface InteractionDetailDiagnosis {
  id: string;
  name?: string;
  code?: string;
  description?: string;
  status?: string;
  primary?: boolean;
  category?: string;
  onsetDate?: string;
}

export interface InteractionDetailAssessment {
  id: string;
  name?: string;
  type?: string;
  date?: string;
  status?: string;
  riskLevel?: string;
  totalScore?: number;
  assessedBy?: string;
}

export interface InteractionDetailServiceLine {
  id: string;
  name?: string;
  serviceCode?: string;
  modifier1?: string;
  modifier2?: string;
  durationMinutes?: number;
  units?: number;
  billingStatus?: string;
}

export interface InteractionDetailRelatedRecords {
  goals: InteractionDetailGoal[];
  services: InteractionDetailService[];
  diagnoses: InteractionDetailDiagnosis[];
  assessments: InteractionDetailAssessment[];
  serviceLines: InteractionDetailServiceLine[];
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
