// web/src/services/pendingSignatureService.ts
import { getCurrentUser } from '../lib/salesforceAuth';
import type { PendingSignatureItem } from '@shared/contracts/index.ts';

class PendingSignatureService {
  async getPendingSignatures(): Promise<PendingSignatureItem[]> {
    const user = getCurrentUser();
    if (!user?.sfUserId) throw new Error('No authenticated user');

    const response = await fetch(
      `/api/pending-signatures?userId=${encodeURIComponent(user.sfUserId)}`
    );
    if (!response.ok) {
      console.error(`Failed to fetch pending signatures (HTTP ${response.status})`);
      return [];
    }
    const data = await response.json();
    return data.items || [];
  }

  async cosign(
    recordId: string,
    role: 'CaseManager' | 'PeerSupport' | 'Manager',
    recordType: 'Interview' | 'Interaction',
    signatureDataUrl?: string
  ): Promise<{ success: boolean; message: string }> {
    const user = getCurrentUser();
    if (!user?.sfUserId) throw new Error('No authenticated user');

    const response = await fetch(
      `/api/pending-signatures/${encodeURIComponent(recordId)}/sign`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user.sfUserId,
          role,
          recordType,
          signatureDataUrl: signatureDataUrl || null,
        }),
      }
    );
    if (!response.ok) {
      const err = await response.json().catch(() => ({ detail: 'Unknown error' }));
      throw new Error(err.detail || 'Co-sign failed');
    }
    return await response.json();
  }
}

export const pendingSignatureService = new PendingSignatureService();
