// shared/contracts/InterviewTemplateContract.ts
// Contract for Interview Template data from Salesforce
// (different from Interview__c - these are reusable question templates)

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
