// shared/contracts/InterviewQuestionLibraryContract.ts
// Contract for InterviewQuestionLibrary__c object from Salesforce

/**
 * InterviewQuestionLibrary__c - Reusable question library
 * Maps to Salesforce custom object
 * NOTE: Currently no records exist in the org, but schema is defined for future use
 */
export interface InterviewQuestionLibrary {
  // Standard Salesforce fields
  Id?: string;
  OwnerId?: string;
  IsDeleted?: boolean;
  Name?: string;
  CreatedDate?: string;
  CreatedById?: string;
  LastModifiedDate?: string;
  LastModifiedById?: string;
  SystemModstamp?: string;
  LastActivityDate?: string | null;
  LastViewedDate?: string | null;
  LastReferencedDate?: string | null;

  // Custom fields (to be determined from actual schema when records exist)
  // Placeholder for future fields based on typical library pattern:
  Category__c?: string | null;
  Question_Text__c?: string | null;
  Response_Type__c?: string | null;
  Tags__c?: string | null;
  Status__c?: string | null;
  Version__c?: number | null;
}
