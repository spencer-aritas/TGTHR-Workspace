// shared/contracts/InterviewTemplateContract.ts
// Contract for InterviewTemplate__c object from Salesforce

export type InterviewTemplateCategory = 'Intake' | 'Assessment' | 'CaseManagement' | 'Clinical' | 'Compliance' | 'Custom';
export type InterviewTemplateStatus = 'Draft' | 'Active' | 'Inactive' | 'Archived';

/**
 * InterviewTemplate__c - Main template definition
 * Maps to Salesforce custom object
 */
export interface InterviewTemplate {
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
  Category__c?: InterviewTemplateCategory | string | null;
  Program__c?: string | null;
  Active__c?: boolean;
  UUID__c?: string | null;
  Status__c?: InterviewTemplateStatus | string | null;
  Available_for_Mobile__c?: boolean;
  Allow_Benefits_Disbursement__c?: boolean;
  Allow_Goal_Assignment__c?: boolean;
  Allow_Diagnoses__c?: boolean;
  Add_Staff_Signature_Block__c?: boolean;
  Diagnoses_Policy__c?: string | null;
  Goals_Policy__c?: string | null;
  Staff_Signature_Policy__c?: string | null;
  Client_Signature_Policy__c?: string | null;
  Housing_Benefit_Policy__c?: string | null;
  Clinical_Benefit_Policy__c?: string | null;
  Mobile_Status__c?: string | null;
  Mobile_Content_Hash__c?: string | null;
  Mobile_Manifest__c?: string | null;
  Locked_By__c?: string | null;
  Locked_At__c?: string | null;
  Mobile_Active_Since__c?: string | null;
  Lint_Passed__c?: boolean;
  Lint_Report__c?: string | null;
  Lint_Run_Date__c?: string | null;
  Previous_Version_Id__c?: string | null;
  Change_Summary__c?: string | null;
  Consent_Required__c?: boolean;
  Data_Retention_Days__c?: number | null;
  Approver__c?: string | null;
}

/**
 * Simplified interface for API responses and display
 */
export interface InterviewTemplateDefinition {
  templateId: string;
  templateVersionId: string;
  templateName: string;
  versionName: string;
  category?: string;
  variant?: string;
  status?: string;
  effectiveFrom?: string;
  effectiveTo?: string;
}

export interface InterviewTemplatesResponse {
  templates: InterviewTemplateDefinition[];
  success: boolean;
  error?: string;
}
