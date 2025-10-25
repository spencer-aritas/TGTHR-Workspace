// shared/contracts/CaseContract.ts
// Contract between PWA and Salesforce for Case Management

export interface CaseRelationship {
  Id: string;
  Name: string;
}

export interface CaseData {
  Id: string;
  CaseNumber: string;
  AccountId?: string;
  Account?: CaseRelationship | null;
  Contact?: CaseRelationship | null;
  Status: string;
  Subject?: string;
  Priority?: string;
  Origin?: string;
  Description?: string;
  Type?: string;
  OwnerId?: string;
  CreatedDate?: string;
}

export interface CreateCaseRequest {
  subject: string;
  accountId: string;
  description?: string;
  priority?: 'Low' | 'Medium' | 'High';
  status?: 'New' | 'Working' | 'Escalated' | 'Closed';
  origin?: 'Web' | 'Phone' | 'Email';
}

export interface CaseService {
  getMyCases(userId: string): Promise<CaseData[]>;
  createCase(request: CreateCaseRequest): Promise<string>;
  getCasesByAccount(accountId: string, maxRows?: number): Promise<CaseData[]>;
}
