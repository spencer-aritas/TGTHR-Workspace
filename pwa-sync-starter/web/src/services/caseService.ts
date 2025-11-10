import { getCurrentUser } from '../lib/salesforceAuth';
import type { CaseData } from '@shared/contracts/index';

export type Case = CaseData;

class CaseService {
  async getMyCases(): Promise<Case[]> {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      throw new Error('AUTH_REQUIRED');
    }

    const userId = currentUser.sfUserId || currentUser.id;
    if (!userId) {
      throw new Error('AUTH_REQUIRED');
    }

    const response = await fetch(`/api/cases/my-cases?userId=${encodeURIComponent(userId)}`);
    
    if (response.status === 401 || response.status === 403) {
      throw new Error('AUTH_REQUIRED');
    }
    
    if (!response.ok) {
      throw new Error(`Failed to fetch cases (HTTP ${response.status})`);
    }
    
    return response.json();
  }
}

export const caseService = new CaseService();
