import { getCurrentUser } from '../lib/salesforceAuth';
import type {
  InteractionSummaryRequest,
  InteractionTimelineRow,
  InteractionDetailResponse
} from '@shared/contracts/index.ts';

export type InteractionSummaryData = InteractionTimelineRow;

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

  async getInteractionDetail(interactionId: string): Promise<InteractionDetailResponse | null> {
    try {
      const currentUser = getCurrentUser();
      const params = new URLSearchParams();
      if (currentUser?.sfUserId) {
        params.set('currentUserId', currentUser.sfUserId);
      }
      const qs = params.toString();
      const response = await fetch(`/api/interaction-summary/${encodeURIComponent(interactionId)}${qs ? '?' + qs : ''}`);

      if (response.status === 404) {
        return null;
      }
      if (!response.ok) {
        console.error(`Failed to fetch interaction detail (HTTP ${response.status})`);
        return null;
      }

      return await response.json();
    } catch (err) {
      console.error('Failed to fetch interaction detail', err);
      return null;
    }
  }

  async managerApprove(interactionId: string, signatureDataUrl?: string): Promise<{ success: boolean; message: string }> {
    const currentUser = getCurrentUser();
    if (!currentUser?.sfUserId) {
      throw new Error('No authenticated user');
    }

    const response = await fetch(`/api/interaction-summary/${encodeURIComponent(interactionId)}/manager-approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: currentUser.sfUserId,
        signatureDataUrl: signatureDataUrl || null,
      }),
    });

    if (!response.ok) {
      const err = await response.json().catch(() => ({ detail: 'Unknown error' }));
      throw new Error(err.detail || 'Manager approve failed');
    }

    return await response.json();
  }
}

export const interactionSummaryService = new InteractionSummaryService();
