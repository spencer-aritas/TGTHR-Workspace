import { getCurrentUser } from '../lib/salesforceAuth';

export interface Case {
  Id: string;
  CaseNumber: string;
  Contact: {
    Id: string;
    Name: string;
  };
  Status: string;
  Subject?: string;
}

class CaseService {
  async getMyCases(): Promise<Case[]> {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      throw new Error('No authenticated user');
    }

    const response = await fetch(`/api/cases/my-cases?userId=${currentUser.id}`);
    
    if (!response.ok) {
      throw new Error('Failed to fetch cases');
    }
    
    return response.json();
  }
}

export const caseService = new CaseService();