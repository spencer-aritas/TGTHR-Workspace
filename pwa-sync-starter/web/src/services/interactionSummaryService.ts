import { getCurrentUser } from '../lib/salesforceAuth';
import type { InteractionSummaryRequest } from '@shared/contracts/InteractionSummaryContract';

class InteractionSummaryService {
  async createInteractionSummary(
    data: Omit<InteractionSummaryRequest, 'CreatedBy' | 'CreatedByEmail'>
  ): Promise<string> {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      throw new Error('No authenticated user');
    }

    const resolvedUserId = currentUser.sfUserId || currentUser.id;
    if (!resolvedUserId) {
      throw new Error('Missing Salesforce user identifier');
    }

    const payload: InteractionSummaryRequest = {
      ...data,
      CreatedBy: resolvedUserId,
      CreatedByEmail: currentUser.email ?? ''
    };

    const response = await fetch('/api/interaction-summary', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error('Failed to create interaction summary');
    }

    const result = await response.json();
    return result.id;
  }
}

export const interactionSummaryService = new InteractionSummaryService();
