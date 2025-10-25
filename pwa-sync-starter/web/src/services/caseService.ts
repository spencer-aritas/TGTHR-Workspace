import { getCurrentUser } from '../lib/salesforceAuth';
import type { CaseData } from '@shared/contracts/CaseContract';

export type Case = CaseData;

class CaseService {
  async getMyCases(): Promise<Case[]> {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      throw new Error('No authenticated user');
    }

    const userId = currentUser.sfUserId || currentUser.id;
    if (!userId) {
      throw new Error('Missing Salesforce user identifier');
    }

    const response = await fetch(`/api/cases/my-cases?userId=${encodeURIComponent(userId)}`);
    
    if (!response.ok) {
      throw new Error('Failed to fetch cases');
    }
    
    return response.json();
  }
}

export const caseService = new CaseService();
