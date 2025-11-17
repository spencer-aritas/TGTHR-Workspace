// shared/contracts/InterviewContract.ts
// Contract for Interview__c object from Salesforce

export type InterviewStatus =
  | 'Draft'
  | 'InProgress'
  | 'PendingSignatures'
  | 'Submitted'
  | 'Completed'
  | 'Archived';

export type InterviewRiskLevel = 'Low' | 'Moderate' | 'High' | 'Critical';

/**
 * Interview__c - Completed interview instance with answers
 * Maps to Salesforce custom object
 */
export interface Interview {
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

  // Custom fields
  Client__c?: string | null;
  Case__c?: string | null;
  Program_Enrollment__c?: string | null;
  Interaction_Summary__c?: string | null;
  InterviewTemplateVersion__c?: string | null;
  Status__c?: InterviewStatus | string | null;
  Started_On__c?: string | null;
  Completed_On__c?: string | null;
  Client_Signed__c?: boolean;
  Staff_Signed__c?: boolean;
  Date_Client_Signed__c?: string | null;
  Date_Staff_Signed__c?: string | null;
  Client_Signature_File_Id__c?: string | null;
  Staff_Signature_File_Id__c?: string | null;
  PDF_File_Id__c?: string | null;
  Risk_Level__c?: InterviewRiskLevel | string | null;
  UUID__c?: string | null;

  // Relationship fields (populated when queried with __r syntax)
  Client__r?: {
    Id: string;
    Name: string;
    FirstName?: string;
    LastName?: string;
    PersonPronouns?: string;
    PersonBirthdate?: string;
    MEDICAID_Number__pc?: string;
  };

  Case__r?: {
    Id: string;
    CaseNumber: string;
    Status: string;
    Owner?: {
      Name: string;
    };
  };

  Interaction_Summary__r?: {
    Id: string;
    Name: string;
    Date_of_Interaction__c?: string;
    AccountId?: string;
  };

  InterviewTemplateVersion__r?: {
    Id: string;
    Name: string;
    Version__c?: number;
    Status__c?: string;
    InterviewTemplate__c?: string;
    InterviewTemplate__r?: {
      Id: string;
      Name: string;
      Category__c?: string;
    };
  };

  Program_Enrollment__r?: {
    Id: string;
    Name: string;
    Status?: string;
    ProgramId?: string;
    AccountId?: string;
  };
}
