// shared/contracts/InteractionSummaryContract.ts
// Contract between PWA and Salesforce for Interaction Summary Management
// Actual Salesforce fields (from InterviewSessionController.buildInteractionSummary):
// - RelatedRecordId (standard field, stores case ID)
// - Date_of_Interaction__c (custom field)
// - MeetingNotes (standard field)
// - Start_Time__c, End_Time__c (custom fields)
// - AccountId (person account ID)

export interface InteractionSummaryRequest {
  RelatedRecordId: string; // Case ID or other record ID
  AccountId?: string; // Person account ID for the interaction
  InteractionDate: string; // YYYY-MM-DD format
  StartTime: string; // HH:MM format
  EndTime: string; // HH:MM format
  Notes: string;
  NoteType?: 'Case Note' | 'Clinical Note' | 'Peer Note' | 'Communication Log';
  SSRSAssessmentId?: string;
  CreatedBy?: string; // User ID
  CreatedByEmail?: string;
}

export interface InteractionSummaryResponse {
  Id: string;
  Name?: string;
  RelatedRecordId?: string; // Standard field (not __c)
  AccountId?: string;
  InteractionDate?: string; // Maps to Date_of_Interaction__c
  StartTime?: string; // Maps to Start_Time__c
  EndTime?: string; // Maps to End_Time__c
  Notes?: string; // Maps to MeetingNotes
  NoteType?: string;
  SSRSAssessmentId?: string;
  CreatedByName?: string;
  CreatedDate?: string;
}

export interface InteractionSummaryService {
  createInteractionSummary(data: InteractionSummaryRequest): Promise<string>;
  getInteractionsByRecord(recordId: string, maxRows?: number): Promise<InteractionSummaryResponse[]>;
}