// shared/contracts/InteractionSummaryContract.ts
// Contract between PWA and Salesforce for Interaction Summary Management

export interface InteractionSummaryRequest {
  RelatedRecordId: string; // Case ID or other record ID
  InteractionDate: string; // YYYY-MM-DD format
  StartTime: string; // HH:MM format
  EndTime: string; // HH:MM format
  Notes: string;
  CreatedBy?: string; // User ID
  CreatedByEmail?: string;
}

export interface InteractionSummaryResponse {
  Id: string;
  Name?: string;
  RelatedRecordId__c?: string;
  InteractionDate__c?: string;
  StartTime__c?: string;
  EndTime__c?: string;
  Notes__c?: string;
  CreatedBy__c?: string;
  CreatedByEmail__c?: string;
  CreatedDate?: string;
}

export interface InteractionSummaryService {
  createInteractionSummary(data: InteractionSummaryRequest): Promise<string>;
  getInteractionsByRecord(recordId: string, maxRows?: number): Promise<InteractionSummaryResponse[]>;
}