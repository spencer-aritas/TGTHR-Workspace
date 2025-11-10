import { getCurrentUser } from '../lib/salesforceAuth';
import type { InteractionSummaryRequest } from '@shared/contracts';

export interface InteractionSummaryData {
  Id: string;
  RelatedRecordId: string;
  InteractionDate: string;
  StartTime?: string;
  EndTime?: string;
  Notes: string;
  CreatedByName?: string;
  CreatedDate: string;
}

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

  async getInteractionsByCase(caseId: string, maxRows: number = 50): Promise<InteractionSummaryData[]> {
    try {
      const response = await fetch(`/api/interaction-summary/by-case/${encodeURIComponent(caseId)}?maxRows=${maxRows}`);
      
      if (!response.ok) {
        console.error(`Failed to fetch interactions (HTTP ${response.status})`);
        return [];
      }
      
      const result = await response.json();
      return result.interactions || [];
    } catch (err) {
      console.error('Failed to fetch interactions for case', err);
      return [];
    }
  }
}

export const interactionSummaryService = new InteractionSummaryService();
