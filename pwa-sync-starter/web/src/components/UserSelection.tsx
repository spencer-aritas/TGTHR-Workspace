import { useState, useEffect } from 'react';
import { getOutreachUsers, registerDevice, isDeviceRegistered, loginWithSalesforce, handleOAuthCallback } from '../lib/salesforceAuth';

interface OutreachUser {
  id: string;
  name: string;
  email: string;
  sfUserId: string;
}

interface UserSelectionProps {
  onUserSelected: () => void;
}

export function UserSelection({ onUserSelected }: UserSelectionProps) {
  const [users, setUsers] = useState<OutreachUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [registering, setRegistering] = useState(false);
  const [showManualSelection, setShowManualSelection] = useState(false);

  useEffect(() => {
    if (isDeviceRegistered()) {
      onUserSelected();
      return;
    }
    
    // Check if this is an OAuth callback
    if (window.location.search.includes('code=')) {
      setRegistering(true);
      
      // Clear the URL parameters to prevent re-handling
      window.history.replaceState({}, '', window.location.pathname);
      
      handleOAuthCallback()
        .then(success => {
          if (success) {
            onUserSelected();
          } else {
            setShowManualSelection(true);
          }
        })
        .catch(error => {
          console.error('OAuth callback failed:', error);
          setShowManualSelection(true);
        })
        .finally(() => setRegistering(false));
      return;
    }
    
    getOutreachUsers().then(setUsers).finally(() => setLoading(false));
  }, [onUserSelected]);

  const handleUserSelect = async (user: OutreachUser) => {
    setRegistering(true);
    
    const success = await registerDevice(user);
    if (success) {
      onUserSelected();
    } else {
      alert('Registration failed. Please try again.');
    }
    
    setRegistering(false);
  };

  if (registering) {
    return <div style={{ padding: '20px', textAlign: 'center' }}>Authenticating with Salesforce...</div>;
  }

  if (loading) {
    return <div style={{ padding: '20px', textAlign: 'center' }}>Loading users...</div>;
  }

  return (
    <div style={{ padding: '20px', maxWidth: '400px', margin: '0 auto' }}>
      <h2>Login to Continue</h2>
      <p>This is a one-time setup to link your device with your Salesforce account.</p>
      
      {!showManualSelection ? (
        <div>
          <button
            onClick={() => loginWithSalesforce().catch(console.error)}
            style={{
              display: 'block',
              width: '100%',
              padding: '16px',
              margin: '16px 0',
              border: 'none',
              borderRadius: '8px',
              backgroundColor: '#1976d2',
              color: 'white',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer'
            }}
          >
            Login with Salesforce
          </button>
          
          <button
            onClick={() => setShowManualSelection(true)}
            style={{
              display: 'block',
              width: '100%',
              padding: '12px',
              margin: '8px 0',
              border: '1px solid #ccc',
              borderRadius: '4px',
              backgroundColor: '#fff',
              cursor: 'pointer'
            }}
          >
            Manual Selection
          </button>
        </div>
      ) : (
        <div>
          <div>
            {users.map(user => (
              <button
                key={user.id}
                onClick={() => handleUserSelect(user)}
                disabled={registering}
                style={{
                  display: 'block',
                  width: '100%',
                  padding: '12px',
                  margin: '8px 0',
                  border: '1px solid #ccc',
                  borderRadius: '4px',
                  backgroundColor: registering ? '#f5f5f5' : '#fff',
                  cursor: registering ? 'not-allowed' : 'pointer'
                }}
              >
                {user.name} ({user.email})
              </button>
            ))}
          </div>
          
          {users.length === 0 && !loading && (
            <p>No users found. Please contact your administrator.</p>
          )}
        </div>
      )}
    </div>
  );
}
