import { useState } from 'react';

interface Enrollment {
  Id: string;
  Name: string;
  Program__r: { Name: string };
  Status__c: string;
  Start_Date__c: string;
  End_Date__c?: string;
}

interface PersonEnrollments {
  personId: string;
  personName: string;
  enrollments: Enrollment[];
}

export function EnrollmentsPage() {
  const [searchUuid, setSearchUuid] = useState('');
  const [enrollments, setEnrollments] = useState<PersonEnrollments | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const searchEnrollments = async () => {
    if (!searchUuid.trim()) return;
    
    setLoading(true);
    setError('');
    
    try {
      const response = await fetch(`/api/person/${searchUuid}/enrollments`);
      
      if (response.ok) {
        const data = await response.json();
        setEnrollments(data);
      } else if (response.status === 404) {
        setError('Person not found');
        setEnrollments(null);
      } else {
        setError('Failed to load enrollments');
      }
    } catch (err) {
      setError('Network error');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateStr?: string) => {
    if (!dateStr) return 'N/A';
    return new Date(dateStr).toLocaleDateString();
  };

  const getStatusColor = (status: string) => {
    switch (status?.toLowerCase()) {
      case 'active': return 'slds-badge slds-theme_success';
      case 'completed': return 'slds-badge slds-theme_info';
      case 'exited': return 'slds-badge slds-theme_warning';
      default: return 'slds-badge';
    }
  };

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <h1 className="slds-page-header__title">Program Enrollments</h1>
        <p className="slds-page-header__info">Search for client program enrollments by UUID</p>
      </header>

      <div className="slds-p-around_medium">
        <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
          
          {/* Search Section */}
          <div className="slds-form-element slds-m-bottom_large">
            <label className="slds-form-element__label slds-text-body_regular" htmlFor="uuid-search">
              Client UUID
            </label>
            <div className="slds-form-element__control slds-input-has-icon slds-input-has-icon_right">
              <input
                id="uuid-search"
                className="slds-input"
                style={{ fontSize: '16px', padding: '12px 50px 12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5' }}
                type="text"
                placeholder="Enter client UUID..."
                value={searchUuid}
                onChange={(e) => setSearchUuid(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && searchEnrollments()}
              />
              <button
                className="slds-input__icon slds-input__icon_right slds-button slds-button_icon"
                onClick={searchEnrollments}
                disabled={loading}
                style={{ right: '8px' }}
              >
                🔍
              </button>
            </div>
          </div>

          {/* Loading State */}
          {loading && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <div className="slds-spinner slds-spinner_medium">
                <div className="slds-spinner__dot-a"></div>
                <div className="slds-spinner__dot-b"></div>
              </div>
              <p>Loading enrollments...</p>
            </div>
          )}

          {/* Error State */}
          {error && (
            <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium">
              <span className="slds-assistive-text">Error</span>
              <h2>{error}</h2>
            </div>
          )}

          {/* Results */}
          {enrollments && (
            <div>
              <div className="slds-m-bottom_large">
                <h2 className="slds-text-heading_medium">{enrollments.personName}</h2>
                <p className="slds-text-body_small slds-text-color_weak">
                  Salesforce ID: {enrollments.personId}
                </p>
              </div>

              {enrollments.enrollments.length === 0 ? (
                <div className="slds-text-align_center slds-p-vertical_large">
                  <p className="slds-text-body_regular">No program enrollments found for this client.</p>
                </div>
              ) : (
                <div className="slds-card">
                  <div className="slds-card__header">
                    <h3 className="slds-card__header-title">
                      Program Enrollments ({enrollments.enrollments.length})
                    </h3>
                  </div>
                  <div className="slds-card__body">
                    <table className="slds-table slds-table_cell-buffer slds-table_bordered">
                      <thead>
                        <tr className="slds-line-height_reset">
                          <th scope="col">Program</th>
                          <th scope="col">Status</th>
                          <th scope="col">Start Date</th>
                          <th scope="col">End Date</th>
                        </tr>
                      </thead>
                      <tbody>
                        {enrollments.enrollments.map((enrollment) => (
                          <tr key={enrollment.Id}>
                            <td>{enrollment.Program__r?.Name || 'N/A'}</td>
                            <td>
                              <span className={getStatusColor(enrollment.Status__c)}>
                                {enrollment.Status__c || 'Unknown'}
                              </span>
                            </td>
                            <td>{formatDate(enrollment.Start_Date__c)}</td>
                            <td>{formatDate(enrollment.End_Date__c)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}