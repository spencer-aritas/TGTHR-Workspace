// shared/contracts/AssessmentContract.ts
// Contract between PWA and Salesforce for Assessment Management

export interface AssessmentRequest {
  accountId: string; // Participant__c (required)
  programId?: string; // Program__c (optional)
  caseId?: string; // Case__c (optional)
  status?: string; // Status picklist
  assessmentDate?: string; // Assessment_Date__c (YYYY-MM-DD)
  assessmentType?: string; // Assessment_Type__c
  assessedById?: string; // Assessed_By__c (User Id)
  values?: Record<string, any>; // Dynamic field values
}

export interface AssessmentResponse {
  Id: string;
  Participant__c?: string;
  Program__c?: string;
  Case__c?: string;
  Status?: string;
  Assessment_Date__c?: string;
  Assessment_Type__c?: string;
  Assessed_By__c?: string;
  CreatedDate?: string;
}

export interface AssessmentService {
  createAssessment(request: AssessmentRequest): Promise<string>;
  getAssessmentsByParticipant(accountId: string, maxRows?: number): Promise<AssessmentResponse[]>;
}