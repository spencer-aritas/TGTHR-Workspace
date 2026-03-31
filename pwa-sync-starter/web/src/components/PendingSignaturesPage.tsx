// web/src/components/PendingSignaturesPage.tsx
import { useState, useEffect, useRef, useCallback } from 'react';
import { pendingSignatureService } from '../services/pendingSignatureService';
import { interactionSummaryService } from '../services/interactionSummaryService';
import type { PendingSignatureItem } from '@shared/contracts/index.ts';
import type { InteractionDetailResponse, InteractionDetailInterviewAnswer } from '@shared/contracts/index.ts';

interface PendingSignaturesPageProps {
  onBack: () => void;
}

const ROLE_LABELS: Record<string, string> = {
  CaseManager: 'Case Manager',
  PeerSupport: 'Peer Support',
  Manager: 'Manager',
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
      <header style={{
        backgroundColor: 'white', borderBottom: '2px solid #e5e5e5',
        padding: '12px 16px', position: 'sticky', top: 0, zIndex: 10,
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: '#16325c' }}>Pending Signatures</h1>
            <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>Documents awaiting your signature</p>
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
            key={item.recordId}
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
              {item.createdByName && (
                <p className="slds-text-body_small slds-text-color_weak">By: {item.createdByName}</p>
              )}
            </div>

            {/* Metadata */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginBottom: '12px' }}>
              {item.recordType === 'Interaction' && (
                <span style={{
                  display: 'inline-block', padding: '2px 10px', borderRadius: '12px',
                  fontSize: '0.75rem', backgroundColor: '#e3f2fd', color: '#333',
                }}>Note</span>
              )}
              {item.caseNumber && (
                <span style={{
                  display: 'inline-block', padding: '2px 10px', borderRadius: '12px',
                  fontSize: '0.75rem', backgroundColor: '#f0f0f0', color: '#333',
                }}>Case {item.caseNumber}</span>
              )}
              {item.status && (
                <span style={{
                  display: 'inline-block', padding: '2px 10px', borderRadius: '12px',
                  fontSize: '0.75rem', backgroundColor: '#e8f5e9', color: '#333',
                }}>{item.status}</span>
              )}
              {item.startedOn && (
                <span style={{
                  display: 'inline-block', padding: '2px 10px', borderRadius: '12px',
                  fontSize: '0.75rem', backgroundColor: '#f0f0f0', color: '#333',
                }}>
                  {formatDateTime(item.startedOn)}
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

/* ── Signing flow (document detail + attestation + signature pad + submit) ──────── */

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
  const [detail, setDetail] = useState<InteractionDetailResponse | null>(null);
  const [detailLoading, setDetailLoading] = useState(!!item.interactionSummaryId);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const isDrawingRef = useRef(false);

  // Fetch full document detail for review
  useEffect(() => {
    if (!item.interactionSummaryId) return;
    let cancelled = false;
    (async () => {
      try {
        const data = await interactionSummaryService.getInteractionDetail(item.interactionSummaryId!);
        if (!cancelled) setDetail(data);
      } catch {
        // Non-blocking — signing can still proceed without detail
      } finally {
        if (!cancelled) setDetailLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [item.interactionSummaryId]);

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
        item.recordId,
        role as 'CaseManager' | 'PeerSupport' | 'Manager',
        item.recordType || 'Interview',
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
      <header style={{
        backgroundColor: 'white', borderBottom: '2px solid #e5e5e5',
        padding: '12px 16px', position: 'sticky', top: 0, zIndex: 10,
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, color: '#16325c' }}>
              Sign as {ROLE_LABELS[role] || role}
            </h1>
            <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
              {item.templateName || item.interviewName} — {item.clientName || item.caseNumber || ''}
            </p>
          </div>
          <button className="slds-button slds-button_neutral" onClick={onCancel}>Cancel</button>
        </div>
      </header>

      <div className="slds-p-around_medium" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Document metadata */}
        <DetailCard title="Document">
          <DField label="Document" value={item.templateName || item.interviewName || '—'} />
          {item.clientName && <DField label="Client" value={item.clientName} />}
          {item.caseNumber && <DField label="Case" value={item.caseNumber} />}
          <DField label="Your Role" value={ROLE_LABELS[role] || role} />
        </DetailCard>

        {/* Full document content from InteractionSummary */}
        {detailLoading && (
          <DetailCard title="Loading Document Content…">
            <div className="slds-text-align_center slds-p-vertical_small">
              <div className="slds-spinner slds-spinner_small slds-spinner_inline">
                <div className="slds-spinner__dot-a" /><div className="slds-spinner__dot-b" />
              </div>
            </div>
          </DetailCard>
        )}

        {detail && (
          <DocumentContentSections detail={detail} />
        )}

        {!item.interactionSummaryId && !detailLoading && (
          <DetailCard title="Document Content">
            <p className="slds-text-body_small slds-text-color_weak">
              Detailed content is not available for this document. Please review the document in Salesforce before signing.
            </p>
          </DetailCard>
        )}

        {/* Attestation */}
        <DetailCard title="Attestation">
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
        </DetailCard>

        {/* Signature pad */}
        {attested && (
          <DetailCard title="Draw your signature">
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
          </DetailCard>
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

/* ── Document content sections (reuses InteractionDetail data) ─── */

function DocumentContentSections({ detail }: { detail: InteractionDetailResponse }) {
  const { content, relatedRecords, interviewAnswers } = detail;

  // Helper: build labeled note fields from content
  const noteFields: { label: string; value?: string }[] = [
    { label: 'Reason for Visit', value: content.reasonForVisit },
    { label: 'Description of Services', value: content.descriptionOfServices },
    { label: 'Response and Progress', value: content.responseAndProgress },
    { label: 'Plan', value: content.plan },
    { label: 'Place of Service', value: content.placeOfService },
    { label: 'Interpreter Used', value: content.interpreterUsed },
  ].filter(f => f.value);

  // Fallback to raw notesHtml if no labeled fields available
  const hasLabeledNotes = noteFields.length > 0;

  return (
    <>
      {/* 1. Interview Form Data (Treatment Plans — form answers first) */}
      {interviewAnswers && interviewAnswers.length > 0 && (
        <InterviewFormSections answers={interviewAnswers} />
      )}

      {/* 2. Goals */}
      {relatedRecords.goals.length > 0 && (
        <DetailCard title={`Goals (${relatedRecords.goals.length})`}>
          {relatedRecords.goals.map((g) => (
            <div key={g.id} style={{ padding: '8px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <span style={{ fontWeight: 600, fontSize: '0.875rem' }}>{g.name || g.id}</span>
                {g.status && <SmallBadge color="#e8f5e9" text={g.status} />}
              </div>
              {g.narrative && <p className="slds-text-body_small" style={{ margin: '4px 0 0', whiteSpace: 'pre-wrap' }}>{g.narrative}</p>}
              {(g.progressBefore != null || g.progressAfter != null) && (
                <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                  Progress: {g.progressBefore ?? '—'} → {g.progressAfter ?? '—'}
                  {g.timeSpentMinutes != null && ` · ${g.timeSpentMinutes} min`}
                </p>
              )}
            </div>
          ))}
        </DetailCard>
      )}

      {/* 3. Notes (labeled fields or raw HTML) */}
      {hasLabeledNotes ? (
        <DetailCard title="Notes">
          {noteFields.map((f, i) => (
            <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div className="slds-text-body_small" style={{ fontWeight: 600, color: '#666', marginBottom: '2px' }}>
                {f.label}
              </div>
              <div
                style={{ fontSize: '0.875rem', lineHeight: '1.6', whiteSpace: 'pre-wrap', wordWrap: 'break-word' }}
                dangerouslySetInnerHTML={{ __html: f.value! }}
              />
            </div>
          ))}
        </DetailCard>
      ) : content.notesHtml ? (
        <DetailCard title="Notes">
          <div
            style={{ lineHeight: '1.6', whiteSpace: 'pre-wrap', wordWrap: 'break-word', fontSize: '0.875rem' }}
            dangerouslySetInnerHTML={{ __html: content.notesHtml }}
          />
        </DetailCard>
      ) : null}

      {/* 4. Risk Assessments */}
      {relatedRecords.assessments.length > 0 && (
        <DetailCard title={`Risk Assessments (${relatedRecords.assessments.length})`}>
          {relatedRecords.assessments.map((a) => (
            <div key={a.id} style={{ padding: '8px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <span style={{ fontWeight: 600, fontSize: '0.875rem' }}>{a.type || a.name || 'Assessment'}</span>
                {a.riskLevel && (
                  <SmallBadge
                    color={a.riskLevel === 'High' || a.riskLevel === 'Imminent' ? '#fce4ec' : a.riskLevel === 'Moderate' ? '#fff3e0' : '#e8f5e9'}
                    text={`Risk: ${a.riskLevel}`}
                  />
                )}
              </div>
              <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                {[
                  a.totalScore != null ? `Score: ${a.totalScore}` : null,
                  a.assessedBy ? `By: ${a.assessedBy}` : null,
                  a.date ? formatDateTime(a.date) : null,
                  a.status,
                ].filter(Boolean).join(' · ')}
              </p>
            </div>
          ))}
        </DetailCard>
      )}

      {/* 5. Services Provided */}
      {relatedRecords.services.length > 0 && (
        <DetailCard title={`Services Provided (${relatedRecords.services.length})`}>
          {relatedRecords.services.map((s) => (
            <div key={s.id} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 500, fontSize: '0.875rem' }}>{s.name || s.id}</span>
                {s.status && <span className="slds-text-body_small slds-text-color_weak">{s.status}</span>}
              </div>
              {(s.amount != null || s.date) && (
                <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                  {[s.amount != null ? `$${s.amount}` : null, s.date ? formatDateTime(s.date) : null].filter(Boolean).join(' · ')}
                </p>
              )}
            </div>
          ))}
        </DetailCard>
      )}

      {/* 6. Diagnoses */}
      {relatedRecords.diagnoses.length > 0 && (
        <DetailCard title={`Diagnoses (${relatedRecords.diagnoses.length})`}>
          {relatedRecords.diagnoses.map((d) => (
            <div key={d.id} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <span style={{ fontWeight: 500, fontSize: '0.875rem' }}>
                  {d.code ? `${d.code} — ${d.name || ''}` : d.name || d.id}
                </span>
                <div style={{ display: 'flex', gap: '4px' }}>
                  {d.primary && <SmallBadge color="#e3f2fd" text="Primary" />}
                  {d.status && <SmallBadge color="#e8f5e9" text={d.status} />}
                </div>
              </div>
              {d.description && <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>{d.description}</p>}
              {(d.category || d.onsetDate) && (
                <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                  {[d.category, d.onsetDate ? `Onset: ${formatDateTime(d.onsetDate)}` : null].filter(Boolean).join(' · ')}
                </p>
              )}
            </div>
          ))}
        </DetailCard>
      )}

      {/* 7. CPT / Service Lines */}
      {relatedRecords.serviceLines && relatedRecords.serviceLines.length > 0 && (
        <DetailCard title={`Service Lines / CPT Codes (${relatedRecords.serviceLines.length})`}>
          {relatedRecords.serviceLines.map((sl) => (
            <div key={sl.id} style={{ padding: '8px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <span style={{ fontWeight: 600, fontSize: '0.875rem' }}>
                  {sl.serviceCode || sl.name || sl.id}
                  {(sl.modifier1 || sl.modifier2) && (
                    <span style={{ fontWeight: 400, color: '#666' }}>
                      {' '}({[sl.modifier1, sl.modifier2].filter(Boolean).join(', ')})
                    </span>
                  )}
                </span>
                {sl.billingStatus && <SmallBadge color={sl.billingStatus === 'Billed' ? '#e8f5e9' : '#fff3e0'} text={sl.billingStatus} />}
              </div>
              <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                {[
                  sl.durationMinutes != null ? `${sl.durationMinutes} min` : null,
                  sl.units != null ? `${sl.units} unit${sl.units !== 1 ? 's' : ''}` : null,
                ].filter(Boolean).join(' · ')}
              </p>
            </div>
          ))}
        </DetailCard>
      )}
    </>
  );
}

/* ── Interview answer sections (grouped by section header) ─────── */

function InterviewFormSections({ answers }: { answers: InteractionDetailInterviewAnswer[] }) {
  const sections: { name: string; items: InteractionDetailInterviewAnswer[] }[] = [];
  const seen = new Map<string, InteractionDetailInterviewAnswer[]>();
  for (const a of answers) {
    const key = a.section || 'General';
    if (!seen.has(key)) {
      const items: InteractionDetailInterviewAnswer[] = [];
      seen.set(key, items);
      sections.push({ name: key, items });
    }
    seen.get(key)!.push(a);
  }

  return (
    <>
      {sections.map((sec) => (
        <DetailCard key={sec.name} title={sec.name}>
          {sec.items.map((item, i) => (
            <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div className="slds-text-body_small" style={{ fontWeight: 600, color: '#666', marginBottom: '2px' }}>
                {item.label}
              </div>
              <div style={{ fontSize: '0.875rem', whiteSpace: 'pre-wrap', wordWrap: 'break-word' }}>
                {item.value || <span className="slds-text-color_weak">—</span>}
              </div>
            </div>
          ))}
        </DetailCard>
      ))}
    </>
  );
}

/* ── Tiny shared helpers ─────────────────────────────────────────── */

/** Format an ISO/UTC date string to local date or date-time. */
function formatDateTime(isoStr: string): string {
  try {
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return isoStr;
    // Date-only values (YYYY-MM-DD) → just date; otherwise date + time
    if (/^\d{4}-\d{2}-\d{2}$/.test(isoStr)) {
      return d.toLocaleDateString();
    }
    return d.toLocaleString(undefined, {
      month: 'short', day: 'numeric', year: 'numeric',
      hour: 'numeric', minute: '2-digit',
    });
  } catch {
    return isoStr;
  }
}

function DetailCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
      <h2 style={{ fontSize: '0.9rem', fontWeight: 700, marginBottom: '10px', color: '#16325c' }}>{title}</h2>
      {children}
    </div>
  );
}

function DField({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
      <span className="slds-text-body_small" style={{ fontWeight: 600, color: '#666' }}>{label}</span>
      <span className="slds-text-body_small">{value}</span>
    </div>
  );
}

function SmallBadge({ color, text }: { color: string; text: string }) {
  return (
    <span style={{
      display: 'inline-block', padding: '2px 10px', borderRadius: '12px',
      fontSize: '0.75rem', backgroundColor: color, color: '#333',
    }}>
      {text}
    </span>
  );
}
