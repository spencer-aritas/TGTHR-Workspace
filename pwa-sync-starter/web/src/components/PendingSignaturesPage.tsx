// web/src/components/PendingSignaturesPage.tsx
import { useState, useEffect, useRef, useCallback } from 'react';
import { pendingSignatureService } from '../services/pendingSignatureService';
import type { PendingSignatureItem } from '@shared/contracts/index.ts';

interface PendingSignaturesPageProps {
  onBack: () => void;
}

const ROLE_LABELS: Record<string, string> = {
  CaseManager: 'Case Manager',
  PeerSupport: 'Peer Support',
  Manager: 'Manager',
};

const ROLE_COLORS: Record<string, string> = {
  CaseManager: '#e3f2fd',
  PeerSupport: '#f3e5f5',
  Manager: '#fff3e0',
};

export function PendingSignaturesPage({ onBack }: PendingSignaturesPageProps) {
  const [items, setItems] = useState<PendingSignatureItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [signingItem, setSigningItem] = useState<{ item: PendingSignatureItem; role: string } | null>(null);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const data = await pendingSignatureService.getPendingSignatures();
      setItems(data);
    } catch {
      setError('Failed to load pending signatures.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  if (signingItem) {
    return (
      <SigningFlow
        item={signingItem.item}
        role={signingItem.role}
        onComplete={() => { setSigningItem(null); void load(); }}
        onCancel={() => setSigningItem(null)}
      />
    );
  }

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1 className="slds-page-header__title">Pending Signatures</h1>
            <p className="slds-text-body_small slds-text-color_weak">Documents awaiting your signature</p>
          </div>
          <button className="slds-button slds-button_neutral" onClick={onBack}>Back</button>
        </div>
      </header>

      <div className="slds-p-around_medium" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {loading && (
          <div className="slds-text-align_center slds-p-vertical_large">
            <div className="slds-spinner slds-spinner_medium">
              <div className="slds-spinner__dot-a" /><div className="slds-spinner__dot-b" />
            </div>
            <p style={{ marginTop: '12px' }}>Loading…</p>
          </div>
        )}

        {error && <p className="slds-text-color_error">{error}</p>}

        {!loading && !error && items.length === 0 && (
          <div style={{ textAlign: 'center', padding: '48px 16px' }}>
            <p className="slds-text-heading_small" style={{ color: '#666' }}>No pending signatures</p>
            <p className="slds-text-body_small slds-text-color_weak" style={{ marginTop: '8px' }}>
              You're all caught up! Documents requiring your signature will appear here.
            </p>
          </div>
        )}

        {items.map((item) => (
          <div
            key={item.interviewId}
            style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              padding: '16px',
              boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
            }}
          >
            {/* Document header */}
            <div style={{ marginBottom: '8px' }}>
              <h3 className="slds-text-heading_small" style={{ margin: 0 }}>
                {item.templateName || item.interviewName || 'Document'}
              </h3>
              {item.clientName && (
                <p className="slds-text-body_small slds-text-color_weak">{item.clientName}</p>
              )}
            </div>

            {/* Metadata */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginBottom: '12px' }}>
              {item.caseNumber && (
                <span style={{ ...badgeStyle, backgroundColor: '#f0f0f0' }}>Case {item.caseNumber}</span>
              )}
              {item.status && (
                <span style={{ ...badgeStyle, backgroundColor: '#e8f5e9' }}>{item.status}</span>
              )}
              {item.startedOn && (
                <span style={{ ...badgeStyle, backgroundColor: '#f0f0f0' }}>
                  {new Date(item.startedOn).toLocaleDateString()}
                </span>
              )}
            </div>

            {/* Pending roles — one button per role */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {item.pendingRoles.map((role) => (
                <button
                  key={role}
                  className="slds-button slds-button_brand"
                  style={{ width: '100%', borderRadius: '8px' }}
                  onClick={() => setSigningItem({ item, role })}
                >
                  Sign as {ROLE_LABELS[role] || role}
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

const badgeStyle: React.CSSProperties = {
  display: 'inline-block',
  padding: '2px 10px',
  borderRadius: '12px',
  fontSize: '0.75rem',
  color: '#333',
};

/* ── Signing flow (attestation + signature pad + submit) ──────── */

function SigningFlow({
  item,
  role,
  onComplete,
  onCancel,
}: {
  item: PendingSignatureItem;
  role: string;
  onComplete: () => void;
  onCancel: () => void;
}) {
  const [attested, setAttested] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const isDrawingRef = useRef(false);

  function clearCanvas() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
  }

  function startDraw(e: React.PointerEvent) {
    isDrawingRef.current = true;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const rect = canvas.getBoundingClientRect();
    ctx.beginPath();
    ctx.moveTo(e.clientX - rect.left, e.clientY - rect.top);
  }

  function draw(e: React.PointerEvent) {
    if (!isDrawingRef.current) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const rect = canvas.getBoundingClientRect();
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.strokeStyle = '#000';
    ctx.lineTo(e.clientX - rect.left, e.clientY - rect.top);
    ctx.stroke();
  }

  function endDraw() {
    isDrawingRef.current = false;
  }

  async function handleSign() {
    setError('');
    setSubmitting(true);
    try {
      const canvas = canvasRef.current;
      const signatureDataUrl = canvas ? canvas.toDataURL('image/png') : undefined;
      await pendingSignatureService.cosign(
        item.interviewId,
        role as 'CaseManager' | 'PeerSupport' | 'Manager',
        signatureDataUrl
      );
      setSuccess(true);
      setTimeout(onComplete, 1500);
    } catch (err: any) {
      setError(err.message || 'Signing failed');
    } finally {
      setSubmitting(false);
    }
  }

  if (success) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <div style={{ textAlign: 'center', padding: '64px 24px' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }}>&#10003;</div>
          <h2 className="slds-text-heading_medium">Signed Successfully</h2>
          <p className="slds-text-body_regular slds-text-color_weak" style={{ marginTop: '8px' }}>
            Your {ROLE_LABELS[role] || role} signature has been recorded.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1 className="slds-page-header__title">
              Sign as {ROLE_LABELS[role] || role}
            </h1>
            <p className="slds-text-body_small slds-text-color_weak">
              {item.templateName || item.interviewName} — {item.clientName || item.caseNumber || ''}
            </p>
          </div>
          <button className="slds-button slds-button_neutral" onClick={onCancel}>Cancel</button>
        </div>
      </header>

      <div className="slds-p-around_medium" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Document summary */}
        <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
          <h2 className="slds-text-heading_small" style={{ marginBottom: '8px' }}>Document Details</h2>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
            <span className="slds-text-body_small" style={{ fontWeight: 600, color: '#666' }}>Document</span>
            <span className="slds-text-body_small">{item.templateName || item.interviewName || '—'}</span>
          </div>
          {item.clientName && (
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
              <span className="slds-text-body_small" style={{ fontWeight: 600, color: '#666' }}>Client</span>
              <span className="slds-text-body_small">{item.clientName}</span>
            </div>
          )}
          {item.caseNumber && (
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
              <span className="slds-text-body_small" style={{ fontWeight: 600, color: '#666' }}>Case</span>
              <span className="slds-text-body_small">{item.caseNumber}</span>
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
            <span className="slds-text-body_small" style={{ fontWeight: 600, color: '#666' }}>Your Role</span>
            <span style={{ ...badgeStyle, backgroundColor: ROLE_COLORS[role] || '#f0f0f0' }}>
              {ROLE_LABELS[role] || role}
            </span>
          </div>
        </div>

        {/* Attestation */}
        <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
          <label style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={attested}
              onChange={(e) => setAttested(e.target.checked)}
              style={{ marginTop: '3px' }}
            />
            <span className="slds-text-body_small">
              I attest that I have reviewed this documentation and confirm its accuracy.
              My electronic signature below represents my professional endorsement of this record.
            </span>
          </label>
        </div>

        {/* Signature pad */}
        {attested && (
          <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
            <p className="slds-text-body_small" style={{ fontWeight: 600, marginBottom: '8px' }}>Draw your signature</p>
            <canvas
              ref={canvasRef}
              width={320}
              height={140}
              onPointerDown={startDraw}
              onPointerMove={draw}
              onPointerUp={endDraw}
              onPointerLeave={endDraw}
              style={{
                border: '1px solid #d8dde6',
                borderRadius: '8px',
                backgroundColor: '#fafafa',
                touchAction: 'none',
                width: '100%',
                maxWidth: '100%',
              }}
            />
            <button
              className="slds-button slds-button_neutral slds-m-top_x-small"
              onClick={clearCanvas}
              style={{ fontSize: '0.75rem' }}
            >
              Clear
            </button>
          </div>
        )}

        {error && <p className="slds-text-color_error">{error}</p>}

        <button
          className="slds-button slds-button_brand"
          disabled={!attested || submitting}
          onClick={handleSign}
          style={{ width: '100%', borderRadius: '8px', padding: '12px' }}
        >
          {submitting ? 'Submitting…' : `Sign as ${ROLE_LABELS[role] || role}`}
        </button>
      </div>
    </div>
  );
}
