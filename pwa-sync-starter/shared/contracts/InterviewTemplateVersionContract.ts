// shared/contracts/InterviewTemplateVersionContract.ts
// Contract for InterviewTemplateVersion__c object from Salesforce

export type TemplateVersionStatus = 'Draft' | 'Active' | 'Inactive' | 'Archived';
export type TemplateVariant = 'Standard' | 'Clinician' | 'CaseManager' | 'PeerSpecialist' | 'Supervisor' | 'Custom';

/**
 * InterviewTemplateVersion__c - Versioned instance of a template
 * Maps to Salesforce custom object
 */
export interface InterviewTemplateVersion {
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
  InterviewTemplate__c?: string | null;
  Version__c?: number | null;
  Status__c?: TemplateVersionStatus | string | null;
  Effective_From__c?: string | null;
  Effective_To__c?: string | null;
  Variant__c?: TemplateVariant | string | null;
  UUID__c?: string | null;

  // Relationship fields (populated when queried with __r syntax)
  InterviewTemplate__r?: {
    Id: string;
    Name: string;
    Category__c?: string;
    Program__c?: string;
    Active__c?: boolean;
  };

  // Convenience properties for PWA (camelCase)
  id?: string;
  uuid?: string;
  templateId?: string;
  templateUuid?: string;
  name?: string;
  versionNumber?: number;
  status?: string;
  variant?: string;
  effectiveFrom?: string;
  effectiveTo?: string;
  ownerId?: string;
  createdById?: string;
  lastModifiedById?: string;
  template?: any; // InterviewTemplate
  questions?: any[]; // InterviewQuestion[]
}
