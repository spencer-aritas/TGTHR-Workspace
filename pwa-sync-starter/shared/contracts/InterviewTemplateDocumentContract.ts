// shared/contracts/InterviewTemplateDocumentContract.ts
// Contract for InterviewTemplateDocument__c object from Salesforce

export type TemplateDocumentStatus = 'Draft' | 'Published' | 'Archived';
export type TemplateOutputFormat = 'DOCX' | 'PDF' | 'HTML';
export type TemplateFormat = 'DOCX' | 'JINJA2' | 'HTML';

/**
 * InterviewTemplateDocument__c - DOCX template file with data mapping
 * Maps to Salesforce custom object
 */
export interface InterviewTemplateDocument {
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
  LastViewedDate?: string | null;
  LastReferencedDate?: string | null;

  // Custom fields
  InterviewTemplateVersion__c?: string | null;
  Program__c?: string | null;
  Category__c?: string | null;
  Content_Link__c?: string | null;
  File_Name__c?: string | null;
  Content_Hash__c?: string | null;
  Engine_Version__c?: string | null;
  Primary_Object__c?: string | null; // e.g., "Interview__c"
  Query__c?: string | null;
  Data_Mapping__c?: string | null; // JSON string with question mappings
  Value_Sets__c?: string | null;
  Output_Format__c?: TemplateOutputFormat | string | null;
  File_Naming_Pattern__c?: string | null;
  Active__c?: boolean;
  Status__c?: TemplateDocumentStatus | string | null;
  Contains_PHI__c?: boolean;
  Retention_Policy__c?: string | null;
  User__c?: string | null;
  InterviewTemplate__c?: string | null;
  Template_Format__c?: TemplateFormat | string | null;

  // Relationship fields (populated when queried with __r syntax)
  InterviewTemplateVersion__r?: {
    Id: string;
    Name: string;
    Version__c?: number;
    Status__c?: string;
    InterviewTemplate__c?: string;
  };

  InterviewTemplate__r?: {
    Id: string;
    Name: string;
    Category__c?: string;
    Program__c?: string;
  };

  Program__r?: {
    Id: string;
    Name: string;
  };
}

/**
 * Parsed data mapping structure from Data_Mapping__c field
 */
export interface InterviewTemplateDataMapping {
  engineVersion: string;
  templateFormat: string;
  demographicFields?: string[];
  questions?: Array<{
    mapsTo?: string;
    section?: string;
    responseType?: string;
    apiName?: string;
    label?: string;
    key?: string;
  }>;
  fields?: Array<{
    objectApiName: string;
    label: string;
    apiName: string;
    id: string;
  }>;
}
