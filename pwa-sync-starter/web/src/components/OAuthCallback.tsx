import { useEffect } from 'react';
import { handleOAuthCallback } from '../lib/salesforceAuth';
import { useNavigate } from 'react-router-dom';

export function OAuthCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    async function processCallback() {
      try {
        const success = await handleOAuthCallback();
        if (success) {
          // Redirect to the main app
          navigate('/');
        } else {
          // Handle failure
          console.error('OAuth callback failed');
          navigate('/?error=auth_failed');
        }
      } catch (error) {
        console.error('OAuth error:', error);
        navigate('/?error=auth_error');
      }
    }

    processCallback();
  }, [navigate]);

  return (
    <div className="slds-align_absolute-center" style={{ height: '100vh' }}>
      <div className="slds-text-heading_medium">
        Completing login...
      </div>
    </div>
  );
}