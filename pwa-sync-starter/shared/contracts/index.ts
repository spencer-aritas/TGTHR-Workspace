// shared/contracts/index.ts
// Central export for all Salesforce-PWA contracts

export * from './IntakeContract';
export * from './CaseContract';
export * from './InteractionSummaryContract';
export * from './AssessmentContract';
export * from './AuditLogContract';

// Common types used across contracts
export interface BaseResponse {
  success: boolean;
  id?: string;
  errors?: string[];
}

export interface PaginatedRequest {
  maxRows?: number;
  offset?: number;
}

export interface PaginatedResponse<T> {
  records: T[];
  totalSize: number;
  done: boolean;
  nextRecordsUrl?: string;
}