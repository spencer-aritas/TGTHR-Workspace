import { useState, useEffect, useRef } from 'react';
import { interactionSummaryService } from '../services/interactionSummaryService';
import type { InteractionDetailResponse, InteractionDetailInterviewAnswer } from '@shared/contracts/index.ts';

interface InteractionDetailPanelProps {
  interactionId: string;
  onBack: () => void;
  onQuickNote: (interactionId: string) => void;
}

export function InteractionDetailPanel({ interactionId, onBack, onQuickNote }: InteractionDetailPanelProps) {
  const [detail, setDetail] = useState<InteractionDetailResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        setLoading(true);
        setError('');
        const data = await interactionSummaryService.getInteractionDetail(interactionId);
        if (!cancelled) {
          if (!data) {
            setError('Interaction not found.');
          }
          setDetail(data);
        }
      } catch {
        if (!cancelled) setError('Failed to load interaction detail.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void load();
    return () => { cancelled = true; };
  }, [interactionId]);

  if (loading) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <div className="slds-text-align_center slds-p-vertical_large">
          <div className="slds-spinner slds-spinner_medium"><div className="slds-spinner__dot-a" /><div className="slds-spinner__dot-b" /></div>
          <p>Loading detail…</p>
        </div>
      </div>
    );
  }

  if (error || !detail) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
          <button className="slds-button slds-button_neutral" onClick={onBack}>Back to Timeline</button>
        </header>
        <div className="slds-p-around_medium">
          <p className="slds-text-color_error">{error || 'Unable to load detail.'}</p>
        </div>
      </div>
    );
  }

  const { summary, chronology, ownership, content, linkage, signature, actions, relatedRecords } = detail;

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      {/* Header */}
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: '16px', alignItems: 'start' }}>
          <div>
            <h1 className="slds-page-header__title" style={{ marginBottom: '4px' }}>
              {summary.name || 'Interaction Detail'}
            </h1>
            {summary.interactionPurpose && (
              <p className="slds-page-header__info" style={{ marginTop: 0 }}>{summary.interactionPurpose}</p>
            )}
          </div>
          <button className="slds-button slds-button_neutral" onClick={onBack} style={{ whiteSpace: 'nowrap' }}>
            Back to Timeline
          </button>
        </div>
      </header>

      <div className="slds-p-around_medium" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>

        {/* Status & Signature badges */}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
          {summary.status && <Badge color="#e8f5e9" text={summary.status} />}
          {signature.requiresManagerApproval && (
            <Badge
              color={signature.signatureState === 'signed' ? '#e8f5e9' : signature.signatureState === 'rejected' ? '#fce4ec' : '#fff3e0'}
              text={`Manager: ${signature.signatureState}`}
            />
          )}
          {linkage.interviewId && <Badge color="#f3e5f5" text={`Interview: ${linkage.interviewTemplateName || 'Linked'}`} />}
        </div>

        {/* Chronology */}
        <Section title="Chronology">
          <Field label="Interaction Date" value={chronology.interactionDate ? new Date(chronology.interactionDate).toLocaleDateString() : '—'} />
          {(chronology.startTime || chronology.endTime) && (
            <Field label="Time" value={[chronology.startTime, chronology.endTime].filter(Boolean).join(' – ') || '—'} />
          )}
          <Field label="Created" value={chronology.createdDate ? new Date(chronology.createdDate).toLocaleString() : '—'} />
          {chronology.lastModifiedDate && (
            <Field label="Last Modified" value={new Date(chronology.lastModifiedDate).toLocaleString()} />
          )}
        </Section>

        {/* Ownership */}
        <Section title="Ownership">
          <Field label="Created By" value={ownership.createdByName || '—'} />
          {ownership.actionAssignedToName && <Field label="Assigned To" value={ownership.actionAssignedToName} />}
          {ownership.managerApproverName && <Field label="Manager Approver" value={ownership.managerApproverName} />}
        </Section>

        {/* Notes */}
        <Section title="Meeting Notes">
          {content.notesHtml ? (
            <div
              style={{ lineHeight: '1.6', whiteSpace: 'pre-wrap', wordWrap: 'break-word' }}
              dangerouslySetInnerHTML={{ __html: content.notesHtml }}
            />
          ) : (
            <p className="slds-text-color_weak">No notes recorded.</p>
          )}
        </Section>

        {/* Interview linkage */}
        {linkage.interviewId && (
          <Section title="Linked Interview">
            <Field label="Template" value={linkage.interviewTemplateName || '—'} />
            <Field label="Status" value={linkage.interviewStatus || '—'} />
          </Section>
        )}

        {/* Interview Form Data */}
        {detail.interviewAnswers && detail.interviewAnswers.length > 0 && (
          <InterviewAnswersSection answers={detail.interviewAnswers} />
        )}

        {/* Related Records: Goals */}
        {relatedRecords.goals.length > 0 && (
          <Section title={`Goals (${relatedRecords.goals.length})`}>
            {relatedRecords.goals.map((g) => (
              <div key={g.id} style={{ padding: '8px 0', borderBottom: '1px solid #f0f0f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <span className="slds-text-body_regular" style={{ fontWeight: 600 }}>{g.name || g.id}</span>
                  {g.status && <Badge color="#e8f5e9" text={g.status} />}
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
          </Section>
        )}

        {/* Related Records: Services Provided */}
        {relatedRecords.services.length > 0 && (
          <Section title={`Services Provided (${relatedRecords.services.length})`}>
            {relatedRecords.services.map((s) => (
              <RelatedRow key={s.id} primary={s.name || s.id} secondary={s.status} detail={[
                s.amount != null ? `$${s.amount}` : null,
                s.date ? new Date(s.date).toLocaleDateString() : null,
              ].filter(Boolean).join(' · ') || undefined} />
            ))}
          </Section>
        )}

        {/* Related Records: Diagnoses */}
        {relatedRecords.diagnoses.length > 0 && (
          <Section title={`Diagnoses (${relatedRecords.diagnoses.length})`}>
            {relatedRecords.diagnoses.map((d) => (
              <div key={d.id} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <span className="slds-text-body_regular" style={{ fontWeight: 500 }}>
                    {d.code ? `${d.code} — ${d.name || ''}` : d.name || d.id}
                  </span>
                  <div style={{ display: 'flex', gap: '4px' }}>
                    {d.primary && <Badge color="#e3f2fd" text="Primary" />}
                    {d.status && <Badge color="#e8f5e9" text={d.status} />}
                  </div>
                </div>
                {d.description && <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>{d.description}</p>}
                {(d.category || d.onsetDate) && (
                  <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                    {[d.category, d.onsetDate ? `Onset: ${new Date(d.onsetDate).toLocaleDateString()}` : null].filter(Boolean).join(' · ')}
                  </p>
                )}
              </div>
            ))}
          </Section>
        )}

        {/* Related Records: Assessments (SSRS etc.) */}
        {relatedRecords.assessments.length > 0 && (
          <Section title={`Assessments (${relatedRecords.assessments.length})`}>
            {relatedRecords.assessments.map((a) => (
              <div key={a.id} style={{ padding: '8px 0', borderBottom: '1px solid #f0f0f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <span className="slds-text-body_regular" style={{ fontWeight: 600 }}>{a.type || a.name || 'Assessment'}</span>
                  {a.riskLevel && (
                    <Badge
                      color={a.riskLevel === 'High' || a.riskLevel === 'Imminent' ? '#fce4ec' : a.riskLevel === 'Moderate' ? '#fff3e0' : '#e8f5e9'}
                      text={`Risk: ${a.riskLevel}`}
                    />
                  )}
                </div>
                <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                  {[
                    a.totalScore != null ? `Score: ${a.totalScore}` : null,
                    a.assessedBy ? `By: ${a.assessedBy}` : null,
                    a.date ? new Date(a.date).toLocaleDateString() : null,
                    a.status,
                  ].filter(Boolean).join(' · ')}
                </p>
              </div>
            ))}
          </Section>
        )}

        {/* Related Records: CPT / Service Lines */}
        {relatedRecords.serviceLines && relatedRecords.serviceLines.length > 0 && (
          <Section title={`Service Lines / CPT Codes (${relatedRecords.serviceLines.length})`}>
            {relatedRecords.serviceLines.map((sl) => (
              <div key={sl.id} style={{ padding: '8px 0', borderBottom: '1px solid #f0f0f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <span className="slds-text-body_regular" style={{ fontWeight: 600 }}>
                    {sl.serviceCode || sl.name || sl.id}
                    {(sl.modifier1 || sl.modifier2) && (
                      <span style={{ fontWeight: 400, color: '#666' }}>
                        {' '}({[sl.modifier1, sl.modifier2].filter(Boolean).join(', ')})
                      </span>
                    )}
                  </span>
                  {sl.billingStatus && <Badge color={sl.billingStatus === 'Billed' ? '#e8f5e9' : '#fff3e0'} text={sl.billingStatus} />}
                </div>
                <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>
                  {[
                    sl.durationMinutes != null ? `${sl.durationMinutes} min` : null,
                    sl.units != null ? `${sl.units} unit${sl.units !== 1 ? 's' : ''}` : null,
                  ].filter(Boolean).join(' · ')}
                </p>
              </div>
            ))}
          </Section>
        )}

        {/* Action Buttons */}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', paddingTop: '8px' }}>
          {actions.canAddQuickNote && (
            <button className="slds-button slds-button_neutral" onClick={() => onQuickNote(interactionId)}>
              + Add Quick Note
            </button>
          )}
        </div>

        {/* Manager Approval */}
        {actions.canApproveAsManager && (
          <ManagerApprovalSection interactionId={interactionId} onApproved={() => {
            // Reload detail after approval
            interactionSummaryService.getInteractionDetail(interactionId).then(setDetail);
          }} />
        )}
      </div>
    </div>
  );
}

/* ── tiny helpers ────────────────────────────────────────────────── */

function Badge({ color, text }: { color: string; text: string }) {
  return (
    <span style={{
      display: 'inline-block', padding: '2px 10px', borderRadius: '12px',
      fontSize: '0.75rem', backgroundColor: color, color: '#333',
    }}>
      {text}
    </span>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
      <h2 className="slds-text-heading_small" style={{ marginBottom: '12px' }}>{title}</h2>
      {children}
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}>
      <span className="slds-text-body_small" style={{ fontWeight: 600, color: '#666' }}>{label}</span>
      <span className="slds-text-body_small">{value}</span>
    </div>
  );
}

function RelatedRow({ primary, secondary, detail }: { primary: string; secondary?: string; detail?: string }) {
  return (
    <div style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span className="slds-text-body_regular" style={{ fontWeight: 500 }}>{primary}</span>
        {secondary && <span className="slds-text-body_small slds-text-color_weak">{secondary}</span>}
      </div>
      {detail && <p className="slds-text-body_small slds-text-color_weak" style={{ margin: '2px 0 0' }}>{detail}</p>}
    </div>
  );
}

function InterviewAnswersSection({ answers }: { answers: InteractionDetailInterviewAnswer[] }) {
  // Group by section, preserving order
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
        <Section key={sec.name} title={sec.name}>
          {sec.items.map((item, i) => (
            <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
              <div className="slds-text-body_small" style={{ fontWeight: 600, color: '#666', marginBottom: '2px' }}>
                {item.label}
              </div>
              <div className="slds-text-body_regular" style={{ whiteSpace: 'pre-wrap', wordWrap: 'break-word' }}>
                {item.value || <span className="slds-text-color_weak">—</span>}
              </div>
            </div>
          ))}
        </Section>
      ))}
    </>
  );
}

/* ── Manager Approval with inline signature ──────────────────────── */

function ManagerApprovalSection({ interactionId, onApproved }: { interactionId: string; onApproved: () => void }) {
  const [attested, setAttested] = useState(false);
  const [signing, setSigning] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const isDrawingRef = useRef(false);

  function clearCanvas() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
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

  async function handleApprove() {
    setError('');
    setSubmitting(true);
    try {
      const canvas = canvasRef.current;
      const signatureDataUrl = canvas ? canvas.toDataURL('image/png') : undefined;
      await interactionSummaryService.managerApprove(interactionId, signatureDataUrl);
      setSuccess(true);
      onApproved();
    } catch (err: any) {
      setError(err.message || 'Approval failed');
    } finally {
      setSubmitting(false);
    }
  }

  if (success) {
    return (
      <Section title="Manager Approval">
        <div style={{ textAlign: 'center', padding: '16px' }}>
          <Badge color="#e8f5e9" text="Approved" />
          <p className="slds-text-body_regular" style={{ marginTop: '8px' }}>Document has been signed and approved.</p>
        </div>
      </Section>
    );
  }

  return (
    <Section title="Manager Approval Required">
      <p className="slds-text-body_regular" style={{ marginBottom: '12px' }}>
        This document is pending your signature as the manager approver.
      </p>

      {/* Attestation */}
      <label style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', marginBottom: '12px', cursor: 'pointer' }}>
        <input
          type="checkbox"
          checked={attested}
          onChange={(e) => { setAttested(e.target.checked); if (e.target.checked) setSigning(true); }}
          style={{ marginTop: '3px' }}
        />
        <span className="slds-text-body_small">
          I attest that I have reviewed this documentation and approve its content as the supervising manager.
        </span>
      </label>

      {/* Signature pad */}
      {signing && (
        <div style={{ marginBottom: '12px' }}>
          <p className="slds-text-body_small" style={{ fontWeight: 600, marginBottom: '4px' }}>Signature</p>
          <canvas
            ref={canvasRef}
            width={320}
            height={120}
            onPointerDown={startDraw}
            onPointerMove={draw}
            onPointerUp={endDraw}
            onPointerLeave={endDraw}
            style={{
              border: '1px solid #d8dde6',
              borderRadius: '8px',
              backgroundColor: '#fff',
              touchAction: 'none',
              width: '100%',
              maxWidth: '320px',
            }}
          />
          <button className="slds-button slds-button_neutral slds-m-top_x-small" onClick={clearCanvas} style={{ fontSize: '0.75rem' }}>
            Clear
          </button>
        </div>
      )}

      {error && <p className="slds-text-color_error slds-m-bottom_small">{error}</p>}

      <button
        className="slds-button slds-button_brand"
        disabled={!attested || submitting}
        onClick={handleApprove}
        style={{ width: '100%' }}
      >
        {submitting ? 'Submitting…' : 'Sign & Approve'}
      </button>
    </Section>
  );
}
