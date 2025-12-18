import React, { useState, useEffect } from 'react';
import { EmergencyInfoCard } from './EmergencyInfoCard';
import { getAccountPhotoAndEmergencyInfo, AccountPhotoInfo } from '../services/photoService';

export interface ParticipantQuickCardProps {
  accountId: string;
  name: string;
  birthdate?: string;
  phone?: string;
  email?: string;
  programName?: string;
  enrollmentStatus?: string;
  unitNumber?: string;
  caseManager?: string;
  onClick?: () => void;
  onPhotoClick?: () => void;
  showEmergencyInfo?: boolean;
  compact?: boolean;
}

/**
 * ParticipantQuickCard - Quick info card for participant/client
 * 
 * Displays:
 * - Photo thumbnail (clickable to view/capture)
 * - Name and basic info
 * - Emergency info badges (allergies/medications) - CRITICAL for safety
 * - Program enrollment status
 */
export const ParticipantQuickCard: React.FC<ParticipantQuickCardProps> = ({
  accountId,
  name,
  birthdate,
  phone,
  email,
  programName,
  enrollmentStatus,
  unitNumber,
  caseManager,
  onClick,
  onPhotoClick,
  showEmergencyInfo = true,
  compact = false,
}) => {
  const [photoInfo, setPhotoInfo] = useState<AccountPhotoInfo | null>(null);
  const [loading, setLoading] = useState(false);
  const [photoError, setPhotoError] = useState(false);

  // Fetch photo and emergency info when component mounts
  useEffect(() => {
    if (accountId && showEmergencyInfo) {
      setLoading(true);
      getAccountPhotoAndEmergencyInfo(accountId)
        .then(setPhotoInfo)
        .catch((err) => {
          console.error('Failed to load participant info:', err);
        })
        .finally(() => setLoading(false));
    }
  }, [accountId, showEmergencyInfo]);

  // Calculate age from birthdate
  const getAge = (birthdate: string | undefined): string | null => {
    if (!birthdate) return null;
    const birth = new Date(birthdate);
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const monthDiff = today.getMonth() - birth.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
      age--;
    }
    return `${age}y`;
  };

  // Status badge colors
  const getStatusColor = (status: string | undefined): { bg: string; text: string; border: string } => {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'enrolled':
        return { bg: '#dcfce7', text: '#166534', border: '#86efac' };
      case 'pending':
      case 'in progress':
        return { bg: '#fef9c3', text: '#854d0e', border: '#fde047' };
      case 'exited':
      case 'completed':
        return { bg: '#e5e7eb', text: '#374151', border: '#d1d5db' };
      case 'inactive':
        return { bg: '#fee2e2', text: '#991b1b', border: '#fecaca' };
      default:
        return { bg: '#f3f4f6', text: '#6b7280', border: '#e5e7eb' };
    }
  };

  const statusColors = getStatusColor(enrollmentStatus);
  const age = getAge(birthdate);

  // Placeholder initials for when no photo
  const getInitials = (name: string): string => {
    return name
      .split(' ')
      .map((part) => part[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  return (
    <div
      className={`participant-quick-card slds-box slds-theme_default ${onClick ? 'slds-cursor-pointer' : ''}`}
      onClick={onClick}
      style={{
        borderRadius: '12px',
        boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
        padding: compact ? '12px' : '16px',
        transition: 'box-shadow 0.2s, transform 0.2s',
        cursor: onClick ? 'pointer' : 'default',
      }}
      onMouseEnter={(e) => {
        if (onClick) {
          e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
          e.currentTarget.style.transform = 'translateY(-2px)';
        }
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.1)';
        e.currentTarget.style.transform = 'translateY(0)';
      }}
    >
      <div className="slds-grid slds-gutters_small">
        {/* Photo Section */}
        <div className="slds-col slds-shrink-none">
          <div
            className="photo-container"
            onClick={(e) => {
              if (onPhotoClick) {
                e.stopPropagation();
                onPhotoClick();
              }
            }}
            style={{
              width: compact ? '48px' : '64px',
              height: compact ? '48px' : '64px',
              borderRadius: '50%',
              overflow: 'hidden',
              backgroundColor: '#e5e7eb',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: onPhotoClick ? 'pointer' : 'default',
              border: '2px solid #fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
            }}
          >
            {photoInfo?.photoUrl && !photoError ? (
              <img
                src={photoInfo.photoUrl}
                alt={name}
                onError={() => setPhotoError(true)}
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'cover',
                }}
              />
            ) : (
              <span
                style={{
                  fontSize: compact ? '16px' : '20px',
                  fontWeight: '600',
                  color: '#6b7280',
                }}
              >
                {getInitials(name)}
              </span>
            )}
          </div>
        </div>

        {/* Info Section */}
        <div className="slds-col slds-grow">
          {/* Name and Age */}
          <div className="slds-grid slds-grid_vertical-align-center slds-m-bottom_xx-small">
            <h3
              style={{
                margin: 0,
                fontSize: compact ? '15px' : '17px',
                fontWeight: '600',
                color: '#111827',
              }}
            >
              {name}
            </h3>
            {age && (
              <span
                style={{
                  marginLeft: '8px',
                  fontSize: '13px',
                  color: '#6b7280',
                }}
              >
                {age}
              </span>
            )}
          </div>

          {/* Emergency Info Badges (compact) */}
          {showEmergencyInfo && photoInfo && (
            <EmergencyInfoCard
              knownAllergies={photoInfo.knownAllergies}
              currentMedications={photoInfo.currentMedications}
              compact={true}
            />
          )}

          {/* Contact and Program Info */}
          <div className="slds-grid slds-wrap slds-grid_vertical-align-center" style={{ gap: '8px', marginTop: '4px' }}>
            {phone && (
              <span
                style={{
                  fontSize: '13px',
                  color: '#4b5563',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                }}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  style={{ width: '14px', height: '14px' }}
                >
                  <path
                    fillRule="evenodd"
                    d="M2 3.5A1.5 1.5 0 013.5 2h1.148a1.5 1.5 0 011.465 1.175l.716 3.223a1.5 1.5 0 01-1.052 1.767l-.933.267c-.41.117-.643.555-.48.95a11.542 11.542 0 006.254 6.254c.395.163.833-.07.95-.48l.267-.933a1.5 1.5 0 011.767-1.052l3.223.716A1.5 1.5 0 0118 15.352V16.5a1.5 1.5 0 01-1.5 1.5H15c-1.149 0-2.263-.15-3.326-.43A13.022 13.022 0 012.43 8.326 13.019 13.019 0 012 5V3.5z"
                    clipRule="evenodd"
                  />
                </svg>
                {phone}
              </span>
            )}
            
            {unitNumber && (
              <span
                style={{
                  fontSize: '12px',
                  color: '#6b7280',
                  backgroundColor: '#f3f4f6',
                  padding: '2px 8px',
                  borderRadius: '4px',
                }}
              >
                Unit {unitNumber}
              </span>
            )}

            {email && !compact && (
              <span
                style={{
                  fontSize: '13px',
                  color: '#4b5563',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                }}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  style={{ width: '14px', height: '14px' }}
                >
                  <path d="M3 4a2 2 0 00-2 2v1.161l8.441 4.221a1.25 1.25 0 001.118 0L19 7.162V6a2 2 0 00-2-2H3z" />
                  <path d="M19 8.839l-7.77 3.885a2.75 2.75 0 01-2.46 0L1 8.839V14a2 2 0 002 2h14a2 2 0 002-2V8.839z" />
                </svg>
                {email}
              </span>
            )}

            {programName && (
              <span
                style={{
                  fontSize: '12px',
                  color: '#4b5563',
                }}
              >
                {programName}
              </span>
            )}
          </div>

          {/* Status Badge */}
          {enrollmentStatus && (
            <div style={{ marginTop: '8px' }}>
              <span
                style={{
                  display: 'inline-block',
                  fontSize: '11px',
                  fontWeight: '600',
                  textTransform: 'uppercase',
                  letterSpacing: '0.025em',
                  padding: '3px 8px',
                  borderRadius: '4px',
                  backgroundColor: statusColors.bg,
                  color: statusColors.text,
                  border: `1px solid ${statusColors.border}`,
                }}
              >
                {enrollmentStatus}
              </span>
            </div>
          )}

          {/* Case Manager */}
          {caseManager && !compact && (
            <div style={{ marginTop: '8px' }}>
              <span style={{ fontSize: '12px', color: '#6b7280' }}>
                CM: <span style={{ color: '#374151', fontWeight: '500' }}>{caseManager}</span>
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Full Emergency Info (non-compact view) */}
      {showEmergencyInfo && !compact && photoInfo && (
        <div style={{ marginTop: '12px', borderTop: '1px solid #e5e7eb', paddingTop: '12px' }}>
          <EmergencyInfoCard
            knownAllergies={photoInfo.knownAllergies}
            currentMedications={photoInfo.currentMedications}
            medicationNotes={photoInfo.medicationNotes}
            compact={false}
          />
        </div>
      )}

      {/* Loading State */}
      {loading && (
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(255,255,255,0.7)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '12px',
          }}
        >
          <div className="slds-spinner slds-spinner_small" role="status">
            <span className="slds-assistive-text">Loading...</span>
            <div className="slds-spinner__dot-a"></div>
            <div className="slds-spinner__dot-b"></div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ParticipantQuickCard;
