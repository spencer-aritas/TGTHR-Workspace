// shared/contracts/InterviewQuestionContract.ts
// Contract for InterviewQuestion__c object from Salesforce

export type InterviewQuestionResponseType =
  | 'Text'
  | 'Textarea'
  | 'Number'
  | 'Boolean'
  | 'Picklist'
  | 'Multi-Picklist'
  | 'Date'
  | 'DateTime'
  | 'Score'
  | 'Signature'
  | 'File';

/**
 * InterviewQuestion__c - Individual question in a template version
 * Maps to Salesforce custom object
 */
export interface InterviewQuestion {
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
  InterviewTemplateVersion__c?: string | null;
  Section__c?: string | null;
  Order__c?: number | null;
  API_Name__c?: string | null;
  Label__c?: string | null;
  Help_Text__c?: string | null;
  Response_Type__c?: InterviewQuestionResponseType | string | null;
  Picklist_Values__c?: string | null; // JSON string
  Required__c?: boolean;
  Sensitive__c?: boolean;
  Score_Weight__c?: number | null;
  Maps_To__c?: string | null; // e.g., "Account.Name"
  UUID__c?: string | null;
  Status__c?: string | null;
  InterviewQuestionLibrary__c?: string | null;
  Question_Text__c?: string | null;
  Question_Key__c?: string | null;
  Version_Number__c?: number | null;
  Validation_Rule__c?: string | null;
  Visibility_Rules__c?: string | null;
  Data_Binding__c?: string | null;
  Approval_Date__c?: string | null;
  Approval_Notes__c?: string | null;
  Change_Summary__c?: string | null;
  Protected__c?: boolean;
  Approver__c?: string | null;
  Compliance_Flags__c?: string | null;

  // Relationship fields (populated when queried with __r syntax)
  InterviewTemplateVersion__r?: {
    Id: string;
    Name: string;
    Version__c?: number;
    Status__c?: string;
  };

  InterviewQuestionLibrary__r?: {
    Id: string;
    Name: string;
  };
}

/**
 * Parsed picklist value structure
 */
export interface InterviewQuestionPicklistValue {
  value: string;
  label?: string;
  isDefault?: boolean;
}
