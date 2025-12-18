import React from 'react';

export interface EmergencyInfoProps {
  knownAllergies: string | null | undefined;
  currentMedications: string | null | undefined;
  medicationNotes?: string | null;
  compact?: boolean;  // For card view vs full view
  className?: string;
}

/**
 * EmergencyInfoCard - Displays critical medical information prominently
 * 
 * This component is designed for field staff safety - showing allergies
 * and medications in a highly visible, warning-styled format.
 * 
 * CRITICAL: This information should always be visible in participant
 * quick info cards for emergency situations.
 */
export const EmergencyInfoCard: React.FC<EmergencyInfoProps> = ({
  knownAllergies,
  currentMedications,
  medicationNotes,
  compact = false,
  className = '',
}) => {
  const hasAllergies = knownAllergies && knownAllergies.trim().length > 0;
  const hasMedications = currentMedications && currentMedications.trim().length > 0;
  const hasMedicationNotes = medicationNotes && medicationNotes.trim().length > 0;
  
  // Don't render if no emergency info
  if (!hasAllergies && !hasMedications && !hasMedicationNotes) {
    return null;
  }

  // Compact view for cards
  if (compact) {
    return (
      <div className={`emergency-info-compact ${className}`}>
        {hasAllergies && (
          <div 
            className="allergy-badge"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
              backgroundColor: '#fef3f2',
              border: '1px solid #fee4e2',
              borderRadius: '16px',
              padding: '4px 10px',
              marginRight: '8px',
              marginBottom: '4px',
            }}
          >
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              viewBox="0 0 20 20" 
              fill="#dc2626"
              style={{ width: '14px', height: '14px' }}
            >
              <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clipRule="evenodd" />
            </svg>
            <span style={{ 
              fontSize: '12px', 
              fontWeight: '600', 
              color: '#dc2626',
              textTransform: 'uppercase',
              letterSpacing: '0.025em',
            }}>
              Allergies
            </span>
          </div>
        )}
        {hasMedications && (
          <div 
            className="medication-badge"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
              backgroundColor: '#fef9c3',
              border: '1px solid #fef08a',
              borderRadius: '16px',
              padding: '4px 10px',
              marginRight: '8px',
              marginBottom: '4px',
            }}
          >
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              viewBox="0 0 20 20" 
              fill="#ca8a04"
              style={{ width: '14px', height: '14px' }}
            >
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.75-11.25a.75.75 0 00-1.5 0v2.5h-2.5a.75.75 0 000 1.5h2.5v2.5a.75.75 0 001.5 0v-2.5h2.5a.75.75 0 000-1.5h-2.5v-2.5z" clipRule="evenodd" />
            </svg>
            <span style={{ 
              fontSize: '12px', 
              fontWeight: '600', 
              color: '#ca8a04',
              textTransform: 'uppercase',
              letterSpacing: '0.025em',
            }}>
              Medications
            </span>
          </div>
        )}
      </div>
    );
  }

  // Full view with details
  return (
    <div className={`emergency-info-full slds-m-bottom_medium ${className}`}>
      {/* Emergency Header */}
      <div 
        className="emergency-header slds-p-around_small slds-m-bottom_small"
        style={{
          backgroundColor: '#fef2f2',
          borderLeft: '4px solid #dc2626',
          borderRadius: '4px',
        }}
      >
        <div className="slds-grid slds-grid_vertical-align-center">
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            viewBox="0 0 24 24" 
            fill="#dc2626"
            style={{ width: '20px', height: '20px', marginRight: '8px' }}
          >
            <path fillRule="evenodd" d="M9.401 3.003c1.155-2 4.043-2 5.197 0l7.355 12.748c1.154 2-.29 4.5-2.599 4.5H4.645c-2.309 0-3.752-2.5-2.598-4.5L9.4 3.003zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zm0 8.25a.75.75 0 100-1.5.75.75 0 000 1.5z" clipRule="evenodd" />
          </svg>
          <h3 style={{ 
            margin: 0, 
            fontSize: '14px', 
            fontWeight: '700', 
            color: '#dc2626',
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
          }}>
            Emergency Medical Information
          </h3>
        </div>
      </div>

      {/* Allergies Section */}
      {hasAllergies && (
        <div 
          className="allergy-section slds-p-around_small slds-m-bottom_small"
          style={{
            backgroundColor: '#fef3f2',
            border: '1px solid #fecaca',
            borderRadius: '8px',
          }}
        >
          <div className="slds-grid slds-grid_vertical-align-start">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              viewBox="0 0 24 24" 
              fill="#dc2626"
              style={{ width: '24px', height: '24px', marginRight: '12px', flexShrink: 0 }}
            >
              <path fillRule="evenodd" d="M9.401 3.003c1.155-2 4.043-2 5.197 0l7.355 12.748c1.154 2-.29 4.5-2.599 4.5H4.645c-2.309 0-3.752-2.5-2.598-4.5L9.4 3.003zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zm0 8.25a.75.75 0 100-1.5.75.75 0 000 1.5z" clipRule="evenodd" />
            </svg>
            <div style={{ flex: 1 }}>
              <h4 style={{ 
                margin: '0 0 4px 0', 
                fontSize: '13px', 
                fontWeight: '700', 
                color: '#dc2626',
                textTransform: 'uppercase',
              }}>
                Known Allergies
              </h4>
              <p style={{ 
                margin: 0, 
                fontSize: '15px', 
                color: '#7f1d1d',
                fontWeight: '500',
                whiteSpace: 'pre-wrap',
              }}>
                {knownAllergies}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Medications Section */}
      {hasMedications && (
        <div 
          className="medication-section slds-p-around_small slds-m-bottom_small"
          style={{
            backgroundColor: '#fefce8',
            border: '1px solid #fef08a',
            borderRadius: '8px',
          }}
        >
          <div className="slds-grid slds-grid_vertical-align-start">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              viewBox="0 0 24 24" 
              fill="#ca8a04"
              style={{ width: '24px', height: '24px', marginRight: '12px', flexShrink: 0 }}
            >
              <path fillRule="evenodd" d="M10.5 3.798v5.02a3 3 0 01-.879 2.121l-2.377 2.377a9.845 9.845 0 015.091 1.013 8.315 8.315 0 005.713.636l.285-.071-3.954-3.955a3 3 0 01-.879-2.121v-5.02a23.614 23.614 0 00-3 0zm4.5.138a.75.75 0 00.093-1.495A24.837 24.837 0 0012 2.25a25.048 25.048 0 00-3.093.191A.75.75 0 009 3.936v4.882a1.5 1.5 0 01-.44 1.06l-6.293 6.294c-1.62 1.621-.903 4.475 1.471 4.88 2.686.46 5.447.698 8.262.698 2.816 0 5.576-.239 8.262-.697 2.373-.406 3.092-3.26 1.47-4.881L15.44 9.879A1.5 1.5 0 0115 8.818V3.936z" clipRule="evenodd" />
            </svg>
            <div style={{ flex: 1 }}>
              <h4 style={{ 
                margin: '0 0 4px 0', 
                fontSize: '13px', 
                fontWeight: '700', 
                color: '#ca8a04',
                textTransform: 'uppercase',
              }}>
                Current Medications
              </h4>
              <p style={{ 
                margin: 0, 
                fontSize: '15px', 
                color: '#713f12',
                fontWeight: '500',
                whiteSpace: 'pre-wrap',
              }}>
                {currentMedications}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Medication Notes Section */}
      {hasMedicationNotes && (
        <div 
          className="medication-notes-section slds-p-around_small"
          style={{
            backgroundColor: '#f0f9ff',
            border: '1px solid #bae6fd',
            borderRadius: '8px',
          }}
        >
          <div className="slds-grid slds-grid_vertical-align-start">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              viewBox="0 0 24 24" 
              fill="#0284c7"
              style={{ width: '24px', height: '24px', marginRight: '12px', flexShrink: 0 }}
            >
              <path fillRule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm8.706-1.442c1.146-.573 2.437.463 2.126 1.706l-.709 2.836.042-.02a.75.75 0 01.67 1.34l-.04.022c-1.147.573-2.438-.463-2.127-1.706l.71-2.836-.042.02a.75.75 0 11-.671-1.34l.041-.022zM12 9a.75.75 0 100-1.5.75.75 0 000 1.5z" clipRule="evenodd" />
            </svg>
            <div style={{ flex: 1 }}>
              <h4 style={{ 
                margin: '0 0 4px 0', 
                fontSize: '13px', 
                fontWeight: '700', 
                color: '#0284c7',
                textTransform: 'uppercase',
              }}>
                Medication Notes
              </h4>
              <p style={{ 
                margin: 0, 
                fontSize: '14px', 
                color: '#0c4a6e',
                whiteSpace: 'pre-wrap',
              }}>
                {medicationNotes}
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default EmergencyInfoCard;
