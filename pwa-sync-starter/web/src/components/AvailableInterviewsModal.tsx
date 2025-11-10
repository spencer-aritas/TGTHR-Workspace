// web/src/components/AvailableInterviewsModal.tsx
import { useState, useEffect } from 'react';
import { interviewTemplateService } from '../services/interviewTemplateService';
import type { InterviewTemplateDefinition } from '@shared/contracts/index.ts';

interface AvailableInterviewsModalProps {
  onSelect: (template: InterviewTemplateDefinition) => void;
  onClose: () => void;
}

export function AvailableInterviewsModal({ onSelect, onClose }: AvailableInterviewsModalProps) {
  const [templates, setTemplates] = useState<InterviewTemplateDefinition[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const loadTemplates = async () => {
      try {
        setLoading(true);
        setError('');
        const data = await interviewTemplateService.getMobileAvailableTemplates();
        setTemplates(data);
      } catch (err) {
        console.error('Failed to load templates', err);
        setError('Failed to load available interviews. Please try again.');
        setTemplates([]);
      } finally {
        setLoading(false);
      }
    };

    void loadTemplates();
  }, []);

  return (
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
        maxWidth: '600px',
        width: '100%',
        maxHeight: '80vh',
        overflowY: 'auto',
        padding: '24px',
        display: 'flex',
        flexDirection: 'column'
      }}>
        <h2 className="slds-text-heading_medium slds-m-bottom_medium">
          Available Interviews
        </h2>

        {error && (
          <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium" role="alert">
            <span className="slds-icon_container slds-icon-utility-ban">
              <svg className="slds-icon slds-icon_x-small" aria-hidden="true">
                <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#ban"></use>
              </svg>
            </span>
            <div>{error}</div>
          </div>
        )}

        {loading && (
          <div className="slds-text-align_center slds-p-vertical_large">
            <div className="slds-spinner slds-spinner_medium">
              <div className="slds-spinner__dot-a"></div>
              <div className="slds-spinner__dot-b"></div>
            </div>
            <p>Loading available interviews...</p>
          </div>
        )}

        {!loading && templates.length === 0 && (
          <div className="slds-text-align_center slds-p-vertical_large">
            <p className="slds-text-body_regular">No interviews available.</p>
          </div>
        )}

        {!loading && templates.length > 0 && (
          <div style={{
            flex: 1,
            overflowY: 'auto',
            marginBottom: '16px'
          }}>
            <div style={{
              display: 'grid',
              gap: '12px'
            }}>
              {templates.map((template) => (
                <button
                  key={template.templateVersionId}
                  onClick={() => onSelect(template)}
                  style={{
                    padding: '16px',
                    border: '1px solid #e5e5e5',
                    borderRadius: '8px',
                    backgroundColor: '#f8f9fa',
                    cursor: 'pointer',
                    textAlign: 'left',
                    transition: 'all 0.2s ease'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = '#f0f1f2';
                    e.currentTarget.style.borderColor = '#0070d2';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = '#f8f9fa';
                    e.currentTarget.style.borderColor = '#e5e5e5';
                  }}
                >
                  <div className="slds-text-body_regular slds-font-weight_bold">
                    {template.templateName}
                  </div>
                  {template.versionName && (
                    <div className="slds-text-body_small slds-text-color_weak">
                      Version: {template.versionName}
                    </div>
                  )}
                  {template.category && (
                    <div className="slds-text-body_small slds-text-color_weak">
                      Category: {template.category}
                    </div>
                  )}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="slds-grid slds-gutters">
          <div className="slds-col slds-size_1-of-1">
            <button
              className="slds-button slds-button_neutral slds-size_1-of-1"
              onClick={onClose}
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
