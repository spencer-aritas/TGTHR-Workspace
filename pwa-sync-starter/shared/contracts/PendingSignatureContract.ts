// shared/contracts/PendingSignatureContract.ts
// DTOs for the mobile co-signing flow (Interview__c + InteractionSummary).

export interface PendingSignatureItem {
  /** The Salesforce record Id (Interview__c or InteractionSummary) */
  recordId: string;
  /** Which object this pending item belongs to */
  recordType: 'Interview' | 'Interaction';
  /** @deprecated Use recordId — kept for backward compat */
  interviewId: string | null;
  interviewName?: string;
  templateName?: string;
  status?: string;
  startedOn?: string;
  caseId?: string;
  caseNumber?: string;
  clientName?: string;
  /** InteractionSummary ID for loading full document detail */
  interactionSummaryId?: string;
  /** Roles the current user can sign for on this document */
  pendingRoles: ('CaseManager' | 'PeerSupport' | 'Manager')[];
  caseManagerName?: string;
  peerSupportName?: string;
  managerName?: string;
  /** Staff who authored the note (InteractionSummary only) */
  createdByName?: string;
}

export interface CosignPayload {
  userId: string;
  role: 'CaseManager' | 'PeerSupport' | 'Manager';
  recordType: 'Interview' | 'Interaction';
  signatureDataUrl?: string;
}
