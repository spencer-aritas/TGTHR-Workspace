import { useState, useEffect, useCallback } from 'react';
import { signingRequestService } from '../services/signingRequestService';
import { SignaturePadComponent } from './SignaturePad';
import type { SigningRequest } from '@shared/contracts/index.ts';

interface SigningRequestPageProps {
  requestId: string;
  onComplete: () => void;
  onCancel: () => void;
}

export function SigningRequestPage({ requestId, onComplete, onCancel }: SigningRequestPageProps) {
  const [request, setRequest] = useState<SigningRequest | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [attested, setAttested] = useState(false);
  const [signing, setSigning] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const data = await signingRequestService.get(requestId);
      if (!data) {
        setError('Signing request not found.');
        return;
      }
      setRequest(data);
      // Mark as opened if still pending
      if (data.status === 'Pending') {
        const opened = await signingRequestService.open(requestId);
        setRequest(opened);
      }
    } catch {
      setError('Failed to load signing request.');
    } finally {
      setLoading(false);
    }
  }, [requestId]);

  useEffect(() => { void load(); }, [load]);

  const handleSignature = async (signatureData: { dataURL: string }) => {
    if (!attested) {
      setError('You must accept the attestation before signing.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      await signingRequestService.complete(requestId, {
        deviceAttestationAccepted: true,
        signatureDataURL: signatureData.dataURL,
      });
      onComplete();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Signing failed.');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <div className="slds-text-align_center slds-p-vertical_large">
          <div className="slds-spinner slds-spinner_medium"><div className="slds-spinner__dot-a" /><div className="slds-spinner__dot-b" /></div>
          <p>Loading signing request…</p>
        </div>
      </div>
    );
  }

  if (error && !request) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
          <button className="slds-button slds-button_neutral" onClick={onCancel}>Back</button>
        </header>
        <div className="slds-p-around_medium"><p className="slds-text-color_error">{error}</p></div>
      </div>
    );
  }

  if (!request) return null;

  const isAlreadySigned = request.status === 'Signed';

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: '16px', alignItems: 'start' }}>
          <div>
            <h1 className="slds-page-header__title">Signing Request</h1>
            <p className="slds-page-header__info" style={{ marginTop: 0 }}>
              {request.targetRecordType} — {request.status}
            </p>
          </div>
          <button className="slds-button slds-button_neutral" onClick={onCancel}>Cancel</button>
        </div>
      </header>

      <div className="slds-p-around_medium" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Request context */}
        <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
          <h2 className="slds-text-heading_small" style={{ marginBottom: '12px' }}>Request Details</h2>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
            <span style={{ fontWeight: 600, color: '#666', fontSize: '0.875rem' }}>Record</span>
            <span style={{ fontSize: '0.875rem' }}>{request.targetRecordId}</span>
          </div>
          {request.requestedForRole && (
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
              <span style={{ fontWeight: 600, color: '#666', fontSize: '0.875rem' }}>Role</span>
              <span style={{ fontSize: '0.875rem' }}>{request.requestedForRole}</span>
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
            <span style={{ fontWeight: 600, color: '#666', fontSize: '0.875rem' }}>Requested</span>
            <span style={{ fontSize: '0.875rem' }}>{new Date(request.requestedAt).toLocaleString()}</span>
          </div>
        </div>

        {isAlreadySigned ? (
          <div style={{ backgroundColor: '#e8f5e9', borderRadius: '12px', padding: '16px', textAlign: 'center' }}>
            <p style={{ fontWeight: 600, color: '#2e7d32' }}>This request has been signed.</p>
            {request.signedAt && <p style={{ fontSize: '0.875rem', color: '#666' }}>Signed at {new Date(request.signedAt).toLocaleString()}</p>}
          </div>
        ) : (
          <>
            {/* Attestation */}
            <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
              <h2 className="slds-text-heading_small" style={{ marginBottom: '12px' }}>Attestation</h2>
              <label style={{ display: 'flex', gap: '10px', alignItems: 'flex-start', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={attested}
                  onChange={(e) => setAttested(e.target.checked)}
                  style={{ marginTop: '4px' }}
                />
                <span style={{ fontSize: '0.875rem', lineHeight: 1.5 }}>
                  I am the assigned authenticated user and I currently have control of the device being used to sign.
                  I have reviewed the associated record context and am ready to apply my signature.
                </span>
              </label>
            </div>

            {/* Signature pad */}
            {attested && !signing && (
              <div style={{ textAlign: 'center' }}>
                <button className="slds-button slds-button_brand" onClick={() => setSigning(true)}>
                  Begin Signing
                </button>
              </div>
            )}

            {signing && (
              <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
                <SignaturePadComponent
                  onSave={handleSignature}
                  recordId={request.targetRecordId}
                  recordType={request.targetRecordType}
                  title="Sign below"
                />
                {submitting && <p className="slds-text-align_center slds-m-top_small">Submitting…</p>}
              </div>
            )}
          </>
        )}

        {error && <p className="slds-text-color_error">{error}</p>}
      </div>
    </div>
  );
}
