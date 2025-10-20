// web/src/components/UserSelection.tsx
import { useState, useEffect } from 'react';
import { getOutreachUsers, setCurrentUser, testSalesforceConnection } from '../lib/userAuth';

interface OutreachUser {
  id: string;
  name: string;
  email: string;
  sfUserId: string;
}

interface UserSelectionProps {
  onComplete: () => void;
}

export function UserSelection({ onComplete }: UserSelectionProps) {
  const [selectedUserId, setSelectedUserId] = useState('');
  const [isConnected, setIsConnected] = useState<boolean | null>(null);
  const [users, setUsers] = useState<OutreachUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const loadData = async () => {
      setIsLoading(true);
      
      // Test connection and load users
      const [connected, userList] = await Promise.all([
        testSalesforceConnection(),
        getOutreachUsers()
      ]);
      
      setIsConnected(connected);
      setUsers(userList);
      setIsLoading(false);
    };
    
    loadData();
  }, []);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const user = users.find(u => u.id === selectedUserId);
    if (user) {
      setCurrentUser(user);
      onComplete();
    }
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: '#f8f9fa',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '16px',
        padding: '48px 32px',
        maxWidth: '400px',
        width: '90%',
        boxShadow: '0 8px 32px rgba(0,0,0,0.1)',
        textAlign: 'center'
      }}>
        <div className="slds-avatar slds-avatar_large slds-m-bottom_medium" style={{
          backgroundColor: '#1976d2',
          color: 'white',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '32px',
          fontWeight: 'bold'
        }}>
          T
        </div>
        
        <h1 className="slds-text-heading_large slds-m-bottom_small">
          TGTHR Outreach
        </h1>
        
        <div className="slds-m-bottom_medium">
          {isLoading && (
            <p className="slds-text-body_small slds-text-color_weak">Loading users...</p>
          )}
          {!isLoading && isConnected === true && (
            <p className="slds-text-body_small slds-text-color_success">✅ Connected to Salesforce ({users.length} users)</p>
          )}
          {!isLoading && isConnected === false && (
            <p className="slds-text-body_small slds-text-color_error">⚠️ Salesforce connection issue</p>
          )}
        </div>

        <form onSubmit={handleSubmit}>
          <div className="slds-form-element slds-m-bottom_large">
            <label className="slds-form-element__label" htmlFor="user-select">
              Who are you?
            </label>
            <div className="slds-form-element__control">
              <select
                id="user-select"
                className="slds-select"
                style={{
                  fontSize: '16px',
                  padding: '12px 16px',
                  borderRadius: '8px',
                  border: '2px solid #e5e5e5',
                  width: '100%'
                }}
                value={selectedUserId}
                onChange={(e) => setSelectedUserId(e.target.value)}
                required
              >
                <option value="">Choose your name...</option>
                {users.map(user => (
                  <option key={user.id} value={user.id}>
                    {user.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <button
            type="submit"
            className="slds-button slds-button_brand"
            style={{
              width: '100%',
              padding: '16px',
              fontSize: '18px',
              fontWeight: 'bold',
              borderRadius: '12px',
              backgroundColor: '#1976d2',
              border: 'none'
            }}
            disabled={!selectedUserId || isLoading}
          >
            🚀 Start Outreach
          </button>
        </form>
        
        <p className="slds-text-body_small slds-text-color_weak slds-m-top_medium">
          One-time setup • Uses existing Salesforce connection
        </p>
      </div>
    </div>
  );
}