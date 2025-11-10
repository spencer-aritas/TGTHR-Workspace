import { useState, useEffect, useCallback } from 'react';
import { Case } from '../services/caseService';
import { interactionSummaryService, InteractionSummaryData } from '../services/interactionSummaryService';
import { SSRSAssessmentWizard } from './SSRSAssessmentWizard';

interface InteractionHistoryProps {
  selectedCase: Case;
  onBack: () => void;
}

interface QuickNoteData {
  parentInteractionId: string | null;
  notes: string;
  date: string;
  startTime: string;
  endTime: string;
}

export function InteractionHistory({ selectedCase, onBack }: InteractionHistoryProps) {
  const [interactions, setInteractions] = useState<InteractionSummaryData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showQuickNoteForm, setShowQuickNoteForm] = useState(false);
  const [quickNoteData, setQuickNoteData] = useState<QuickNoteData>({
    parentInteractionId: null,
    notes: '',
    date: new Date().toISOString().split('T')[0],
    startTime: '',
    endTime: ''
  });
  const [submitting, setSubmitting] = useState(false);
  const [showNewNoteForm, setShowNewNoteForm] = useState(false);
  const [showSSRS, setShowSSRS] = useState(false);

  const loadInteractions = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const data = await interactionSummaryService.getInteractionsByCase(selectedCase.Id, 100);
      setInteractions(data);
    } catch (err) {
      console.error('Failed to load interactions', err);
      setError('Failed to load interaction history. Please try again.');
      setInteractions([]);
    } finally {
      setLoading(false);
    }
  }, [selectedCase.Id]);

  useEffect(() => {
    void loadInteractions();
  }, [loadInteractions]);

  const handleQuickNote = (interactionId: string) => {
    setQuickNoteData({
      parentInteractionId: interactionId,
      notes: '',
      date: new Date().toISOString().split('T')[0],
      startTime: '',
      endTime: ''
    });
    setShowQuickNoteForm(true);
  };

  const handleNewNote = () => {
    setShowNewNoteForm(true);
    setQuickNoteData({
      parentInteractionId: null,
      notes: '',
      date: new Date().toISOString().split('T')[0],
      startTime: '',
      endTime: ''
    });
  };

  const handleSubmitQuickNote = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCase || !quickNoteData.notes) return;

    setSubmitting(true);
    try {
      await interactionSummaryService.createInteractionSummary({
        RelatedRecordId: selectedCase.Id,
        InteractionDate: quickNoteData.date,
        StartTime: quickNoteData.startTime,
        EndTime: quickNoteData.endTime,
        Notes: quickNoteData.notes
      });

      setShowQuickNoteForm(false);
      setShowNewNoteForm(false);
      setQuickNoteData({
        parentInteractionId: null,
        notes: '',
        date: new Date().toISOString().split('T')[0],
        startTime: '',
        endTime: ''
      });

      // Reload interactions to show the new one
      await loadInteractions();
    } catch (err) {
      setError('Failed to save note. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleSSRSComplete = async () => {
    setShowSSRS(false);
    // Reload interactions after SSRS assessment
    await loadInteractions();
  };

  if (showSSRS && selectedCase) {
    return (
      <SSRSAssessmentWizard
        selectedCase={selectedCase}
        onComplete={handleSSRSComplete}
        onCancel={() => setShowSSRS(false)}
      />
    );
  }

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <div className="slds-media">
          <div className="slds-media__body">
            <h1 className="slds-page-header__title">Interaction History</h1>
            <p className="slds-page-header__info">
              {selectedCase.Subject || `Case ${selectedCase.CaseNumber}`}
            </p>
          </div>
          <div className="slds-media__figure">
            <button 
              className="slds-button slds-button_neutral"
              onClick={onBack}
            >
              Back to Cases
            </button>
          </div>
        </div>
      </header>

      <div className="slds-p-around_medium">
        <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
          
          {error && (
            <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium" role="alert">
              <span className="slds-assistive-text">Error</span>
              <span className="slds-icon_container slds-icon-utility-ban slds-m-right_x-small">
                <svg className="slds-icon slds-icon_x-small" aria-hidden="true">
                  <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#ban"></use>
                </svg>
              </span>
              <div className="slds-grid slds-grid_vertical-align-center">
                <div className="slds-col">
                  <h2>{error}</h2>
                </div>
              </div>
            </div>
          )}

          {loading && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <div className="slds-spinner slds-spinner_medium">
                <div className="slds-spinner__dot-a"></div>
                <div className="slds-spinner__dot-b"></div>
              </div>
              <p>Loading interaction history...</p>
            </div>
          )}

          {!loading && interactions.length === 0 && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <p className="slds-text-body_regular">No interactions recorded yet.</p>
            </div>
          )}

          {!loading && interactions.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <div className="slds-m-bottom_medium">
                <div className="slds-grid slds-gutters">
                  <div className="slds-col slds-size_1-of-2">
                    <button
                      className="slds-button slds-button_brand slds-size_1-of-1"
                      onClick={handleNewNote}
                    >
                      New Note
                    </button>
                  </div>
                  <div className="slds-col slds-size_1-of-2">
                    <button
                      className="slds-button slds-button_outline-brand slds-size_1-of-1"
                      onClick={() => setShowSSRS(true)}
                    >
                      SSRS Assessment
                    </button>
                  </div>
                </div>
              </div>

              <div style={{
                maxHeight: '600px',
                overflowY: 'auto',
                borderTop: '1px solid #e5e5e5',
                borderBottom: '1px solid #e5e5e5',
                paddingTop: '16px',
                paddingBottom: '16px'
              }}>
                {interactions.map((interaction, index) => (
                  <div
                    key={interaction.Id}
                    style={{
                      borderBottom: index < interactions.length - 1 ? '1px solid #f0f0f0' : 'none',
                      paddingBottom: '16px',
                      marginBottom: '16px'
                    }}
                  >
                    <div className="slds-grid slds-grid_vertical-align-start slds-gutters">
                      <div className="slds-col slds-size_1-of-3">
                        <div className="slds-text-body_small slds-text-color_weak slds-m-bottom_x-small">
                          {new Date(interaction.InteractionDate).toLocaleDateString()}
                        </div>
                        <div className="slds-text-body_small slds-font-weight_bold">
                          {interaction.CreatedByName}
                        </div>
                      </div>
                      <div className="slds-col slds-size_2-of-3">
                        <div
                          className="slds-text-body_regular slds-m-bottom_small"
                          style={{
                            lineHeight: '1.5',
                            color: '#3c3c3c'
                          }}
                          dangerouslySetInnerHTML={{ __html: interaction.Notes }}
                        />
                        <button
                          className="slds-button slds-button_text-destructive slds-text-body_small"
                          onClick={() => handleQuickNote(interaction.Id)}
                          style={{ padding: '0', fontSize: '0.875rem', color: '#0070d2', textDecoration: 'none' }}
                        >
                          Quick Note →
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {!loading && (
            <div className="slds-grid slds-gutters">
              <div className="slds-col slds-size_1-of-2">
                <button
                  className="slds-button slds-button_neutral slds-size_1-of-1"
                  onClick={onBack}
                >
                  Back to Cases
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Quick Note Form Modal */}
      {(showQuickNoteForm || showNewNoteForm) && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '16px'
        }}>
          <div style={{
            backgroundColor: 'white',
            borderRadius: '16px',
            boxShadow: '0 2px 16px rgba(0,0,0,0.2)',
            maxWidth: '500px',
            width: '100%',
            maxHeight: '80vh',
            overflowY: 'auto',
            padding: '24px'
          }}>
            <h2 className="slds-text-heading_medium slds-m-bottom_medium">
              {showNewNoteForm ? 'New Note' : 'Quick Note'}
            </h2>

            <form onSubmit={handleSubmitQuickNote}>
              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label" htmlFor="note-date">
                  Date *
                </label>
                <div className="slds-form-element__control">
                  <input
                    id="note-date"
                    type="date"
                    className="slds-input"
                    value={quickNoteData.date}
                    onChange={(e) => setQuickNoteData({ ...quickNoteData, date: e.target.value })}
                    required
                  />
                </div>
              </div>

              <div className="slds-grid slds-gutters slds-m-bottom_medium">
                <div className="slds-col slds-size_1-of-2">
                  <div className="slds-form-element">
                    <label className="slds-form-element__label" htmlFor="note-start-time">
                      Start Time *
                    </label>
                    <div className="slds-form-element__control">
                      <input
                        id="note-start-time"
                        type="time"
                        className="slds-input"
                        value={quickNoteData.startTime}
                        onChange={(e) => setQuickNoteData({ ...quickNoteData, startTime: e.target.value })}
                        required
                      />
                    </div>
                  </div>
                </div>
                <div className="slds-col slds-size_1-of-2">
                  <div className="slds-form-element">
                    <label className="slds-form-element__label" htmlFor="note-end-time">
                      End Time *
                    </label>
                    <div className="slds-form-element__control">
                      <input
                        id="note-end-time"
                        type="time"
                        className="slds-input"
                        value={quickNoteData.endTime}
                        onChange={(e) => setQuickNoteData({ ...quickNoteData, endTime: e.target.value })}
                        required
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label" htmlFor="note-notes">
                  Note *
                </label>
                <div className="slds-form-element__control">
                  <textarea
                    id="note-notes"
                    className="slds-textarea"
                    rows={5}
                    value={quickNoteData.notes}
                    onChange={(e) => setQuickNoteData({ ...quickNoteData, notes: e.target.value })}
                    required
                    placeholder="Enter your note here..."
                    style={{ fontFamily: 'inherit', fontSize: '0.875rem' }}
                  />
                </div>
              </div>

              <div className="slds-grid slds-gutters">
                <div className="slds-col slds-size_1-of-2">
                  <button
                    type="submit"
                    className="slds-button slds-button_brand slds-size_1-of-1"
                    disabled={submitting}
                  >
                    {submitting ? 'Saving...' : 'Save Note'}
                  </button>
                </div>
                <div className="slds-col slds-size_1-of-2">
                  <button
                    type="button"
                    className="slds-button slds-button_neutral slds-size_1-of-1"
                    onClick={() => {
                      setShowQuickNoteForm(false);
                      setShowNewNoteForm(false);
                    }}
                    disabled={submitting}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
