import { getCurrentUser } from '../lib/salesforceAuth';

export interface InteractionSummary {
  Id?: string;
  RelatedRecordId: string;
  InteractionDate: string;
  StartTime: string;
  EndTime: string;
  Notes: string;
  CreatedBy?: string;
  CreatedByEmail?: string;
}

class InteractionSummaryService {
  async createInteractionSummary(data: Omit<InteractionSummary, 'Id' | 'CreatedBy' | 'CreatedByEmail'>): Promise<string> {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      throw new Error('No authenticated user');
    }

    const payload = {
      ...data,
      CreatedBy: currentUser.id,
      CreatedByEmail: currentUser.email
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