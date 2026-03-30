// shared/contracts/SigningRequestContract.ts
// Server-owned signing request lifecycle contract.

export type SigningRequestStatus = 'Pending' | 'Opened' | 'Signed' | 'Cancelled' | 'Expired';

export interface SigningRequest {
  requestId: string;
  targetRecordId: string;
  targetRecordType: string;
  caseId?: string;
  interactionId?: string;
  interviewId?: string;
  requestedByUserId: string;
  requestedForUserId: string;
  requestedForRole?: string;
  status: SigningRequestStatus;
  requestedAt: string;
  openedAt?: string;
  signedAt?: string;
  deviceAttestationAccepted: boolean;
  signatureContentVersionId?: string;
  auditEntityId?: string;
}

export interface CreateSigningRequestPayload {
  targetRecordId: string;
  targetRecordType: string;
  caseId?: string;
  interactionId?: string;
  interviewId?: string;
  requestedForUserId: string;
  requestedForRole?: string;
}

export interface CompleteSigningRequestPayload {
  deviceAttestationAccepted: boolean;
  signatureDataURL: string;
}
