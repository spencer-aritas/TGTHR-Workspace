// shared/contracts/PendingSignatureContract.ts
// DTOs for the mobile co-signing flow (CM / PS / Manager on Interview__c).

export interface PendingSignatureItem {
  interviewId: string;
  interviewName?: string;
  templateName?: string;
  status?: string;
  startedOn?: string;
  caseId?: string;
  caseNumber?: string;
  clientName?: string;
  /** Roles the current user can sign for on this document */
  pendingRoles: ('CaseManager' | 'PeerSupport' | 'Manager')[];
  caseManagerName?: string;
  peerSupportName?: string;
  managerName?: string;
}

export interface CosignPayload {
  userId: string;
  role: 'CaseManager' | 'PeerSupport' | 'Manager';
  signatureDataUrl?: string;
}
