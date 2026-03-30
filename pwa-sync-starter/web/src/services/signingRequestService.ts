import { getCurrentUser } from '../lib/salesforceAuth';
import type {
  SigningRequest,
  CreateSigningRequestPayload,
  CompleteSigningRequestPayload,
} from '@shared/contracts/index.ts';

class SigningRequestService {
  async create(payload: CreateSigningRequestPayload): Promise<SigningRequest> {
    const currentUser = getCurrentUser();
    if (!currentUser) throw new Error('No authenticated user');

    const body = {
      ...payload,
      requestedByUserId: currentUser.sfUserId || currentUser.id,
    };

    const response = await fetch('/api/signing-requests', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Failed to create signing request: ${detail}`);
    }

    return response.json();
  }

  async get(requestId: string): Promise<SigningRequest | null> {
    const response = await fetch(`/api/signing-requests/${encodeURIComponent(requestId)}`);
    if (response.status === 404) return null;
    if (!response.ok) throw new Error('Failed to fetch signing request');
    return response.json();
  }

  async open(requestId: string): Promise<SigningRequest> {
    const response = await fetch(`/api/signing-requests/${encodeURIComponent(requestId)}/open`, {
      method: 'POST',
    });
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Failed to open signing request: ${detail}`);
    }
    return response.json();
  }

  async complete(requestId: string, payload: CompleteSigningRequestPayload): Promise<SigningRequest> {
    const response = await fetch(`/api/signing-requests/${encodeURIComponent(requestId)}/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Failed to complete signing request: ${detail}`);
    }
    return response.json();
  }
}

export const signingRequestService = new SigningRequestService();
