import { useState, useEffect } from 'react';
import { caseService, Case } from '../services/caseService';
import { interactionSummaryService, InteractionSummary } from '../services/interactionSummaryService';

interface InteractionFormData {
  notes: string;
  date: string;
  startTime: string;
  endTime: string;
}

export function MyCasesPage() {
  const [cases, setCases] = useState<Case[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedCase, setSelectedCase] = useState<Case | null>(null);
  const [formData, setFormData] = useState<InteractionFormData>({
    notes: '',
    date: new Date().toISOString().split('T')[0],
    startTime: '',
    endTime: ''
  });
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadCases();
  }, []);

  const loadCases = async () => {
    try {
      setLoading(true);
      const data = await caseService.getMyCases();
      setCases(data);
    } catch (err) {
      setError('Failed to load cases');
    } finally {
      setLoading(false);
    }
  };

  const handleCaseSelect = (caseItem: Case) => {
    setSelectedCase(caseItem);
    setFormData({
      notes: '',
      date: new Date().toISOString().split('T')[0],
      startTime: '',
      endTime: ''
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCase) return;

    setSubmitting(true);
    try {
      await interactionSummaryService.createInteractionSummary({
        RelatedRecordId: selectedCase.Id,
        InteractionDate: formData.date,
        StartTime: formData.startTime,
        EndTime: formData.endTime,
        Notes: formData.notes
      });
      
      setSelectedCase(null);
      setFormData({
        notes: '',
        date: new Date().toISOString().split('T')[0],
        startTime: '',
        endTime: ''
      });
    } catch (err) {
      setError('Failed to save interaction summary');
    } finally {
      setSubmitting(false);
    }
  };

  if (selectedCase) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
          <div className="slds-media">
            <div className="slds-media__body">
              <h1 className="slds-page-header__title">Log Interaction</h1>
              <p className="slds-page-header__info">
                {selectedCase.Contact.Name} - {selectedCase.CaseNumber}
              </p>
            </div>
            <div className="slds-media__figure">
              <button 
                className="slds-button slds-button_neutral"
                onClick={() => setSelectedCase(null)}
              >
                ← Back to Cases
              </button>
            </div>
          </div>
        </header>

        <div className="slds-p-around_medium">
          <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
            <form onSubmit={handleSubmit}>
              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label" htmlFor="notes">
                  Interaction Notes *
                </label>
                <div className="slds-form-element__control">
                  <textarea
                    id="notes"
                    className="slds-textarea"
                    rows={6}
                    value={formData.notes}
                    onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                    required
                    placeholder="Enter interaction details..."
                  />
                </div>
              </div>

              <div className="slds-grid slds-gutters slds-m-bottom_medium">
                <div className="slds-col slds-size_1-of-3">
                  <div className="slds-form-element">
                    <label className="slds-form-element__label" htmlFor="date">
                      Date
                    </label>
                    <div className="slds-form-element__control">
                      <input
                        id="date"
                        type="date"
                        className="slds-input"
                        value={formData.date}
                        onChange={(e) => setFormData({ ...formData, date: e.target.value })}
                        required
                      />
                    </div>
                  </div>
                </div>
                
                <div className="slds-col slds-size_1-of-3">
                  <div className="slds-form-element">
                    <label className="slds-form-element__label" htmlFor="startTime">
                      Start Time *
                    </label>
                    <div className="slds-form-element__control">
                      <input
                        id="startTime"
                        type="time"
                        className="slds-input"
                        value={formData.startTime}
                        onChange={(e) => setFormData({ ...formData, startTime: e.target.value })}
                        required
                      />
                    </div>
                  </div>
                </div>
                
                <div className="slds-col slds-size_1-of-3">
                  <div className="slds-form-element">
                    <label className="slds-form-element__label" htmlFor="endTime">
                      End Time *
                    </label>
                    <div className="slds-form-element__control">
                      <input
                        id="endTime"
                        type="time"
                        className="slds-input"
                        value={formData.endTime}
                        onChange={(e) => setFormData({ ...formData, endTime: e.target.value })}
                        required
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div className="slds-text-align_center">
                <button
                  type="submit"
                  className="slds-button slds-button_brand"
                  disabled={submitting}
                >
                  {submitting ? 'Saving...' : 'Save Interaction'}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <h1 className="slds-page-header__title">My Cases</h1>
        <p className="slds-page-header__info">Select a case to log an interaction</p>
      </header>

      <div className="slds-p-around_medium">
        <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
          
          {loading && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <div className="slds-spinner slds-spinner_medium">
                <div className="slds-spinner__dot-a"></div>
                <div className="slds-spinner__dot-b"></div>
              </div>
              <p>Loading cases...</p>
            </div>
          )}

          {error && (
            <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium">
              <span className="slds-assistive-text">Error</span>
              <h2>{error}</h2>
            </div>
          )}

          {!loading && cases.length === 0 && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <p className="slds-text-body_regular">No active cases found.</p>
            </div>
          )}

          {!loading && cases.length > 0 && (
            <div className="slds-grid slds-wrap slds-gutters">
              {cases.map((caseItem) => (
                <div key={caseItem.Id} className="slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3">
                  <div 
                    className="slds-card slds-card_boundary"
                    style={{ cursor: 'pointer', transition: 'transform 0.2s' }}
                    onClick={() => handleCaseSelect(caseItem)}
                  >
                    <div className="slds-card__header">
                      <h3 className="slds-card__header-title slds-truncate">
                        {caseItem.Contact.Name}
                      </h3>
                    </div>
                    <div className="slds-card__body slds-card__body_inner">
                      <p className="slds-text-body_regular slds-m-bottom_x-small">
                        <strong>Case:</strong> {caseItem.CaseNumber}
                      </p>
                      <p className="slds-text-body_small slds-text-color_weak">
                        Status: {caseItem.Status}
                      </p>
                      {caseItem.Subject && (
                        <p className="slds-text-body_small slds-m-top_x-small slds-truncate">
                          {caseItem.Subject}
                        </p>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}