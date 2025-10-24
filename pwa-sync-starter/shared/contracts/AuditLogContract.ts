// shared/contracts/AuditLogContract.ts
// Contract between PWA and Salesforce for Audit Log Management

export interface AuditLogRequest {
  actionType: string; // Action__c
  entityId: string; // UUID__c or Record_Id__c
  details: string; // Description__c
  userId?: string; // User__c (defaults to current user)
  timestamp?: string; // Timestamp__c (defaults to now)
  application?: string; // Application__c
  auditJSON?: string; // Audit_JSON__c
  complianceReference?: string; // Compliance_Reference__c
  createdByIntegration?: boolean; // Created_by_Integration__c
  eventType?: string; // Event_Type__c
  sourceIP?: string; // Source_IP__c
  status?: string; // Status
}

export interface AuditLogResponse {
  Id: string;
  Action__c?: string;
  UUID__c?: string;
  Description__c?: string;
  User__c?: string;
  Timestamp__c?: string;
  Application__c?: string;
  Record_Id__c?: string;
  CreatedDate?: string;
}

export interface AuditLogService {
  logAction(actionType: string, entityId: string, details: string): Promise<void>;
  getAuditLogsByEntity(entityId: string, maxRows?: number): Promise<AuditLogResponse[]>;
}