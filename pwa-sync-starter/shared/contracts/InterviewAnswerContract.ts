// shared/contracts/InterviewAnswerContract.ts
// Contract for InterviewAnswer__c object from Salesforce

/**
 * InterviewAnswer__c - Response to a specific interview question
 * Maps to Salesforce custom object
 */
export interface InterviewAnswer {
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
  Interview__c?: string | null;
  InterviewQuestion__c?: string | null;
  Question_API_Name__c?: string | null;
  Section__c?: string | null;
  Response_Text__c?: string | null;
  Response_Number__c?: number | null;
  Response_Date__c?: string | null;
  Response_DateTime__c?: string | null;
  Response_Boolean__c?: boolean;
  Response_Picklist__c?: string | null;
  Response_Score__c?: number | null;
  Is_Obfuscated__c?: boolean;
  UUID__c?: string | null;

  // Relationship fields (populated when queried with __r syntax)
  Interview__r?: {
    Id: string;
    Name: string;
    Status__c?: string;
    Client__c?: string;
  };

  InterviewQuestion__r?: {
    Id: string;
    Name: string;
    Label__c?: string;
    API_Name__c?: string;
    Response_Type__c?: string;
    Section__c?: string;
    Order__c?: number;
    Maps_To__c?: string;
    Picklist_Values__c?: string;
    Protected__c?: boolean;
    Question_Key__c?: string;
    Question_Text__c?: string;
    Approver__c?: string;
    Compliance_Flags__c?: string;
    Required__c?: boolean;
  };

  // Convenience properties for PWA (camelCase)
  id?: string;
  uuid?: string;
  interviewId?: string;
  interviewUuid?: string;
  interviewQuestionId?: string;
  interviewQuestionUuid?: string;
  questionApiName?: string;
  section?: string;
  responseBoolean?: boolean;
  responseDate?: string;
  responseDateTime?: string;
  responseNumber?: number;
  responsePicklist?: string | string[];
  responseScore?: string;
  responseText?: string;
  isObfuscated?: boolean;
  ownerId?: string;
  createdById?: string;
  lastModifiedById?: string;
}
