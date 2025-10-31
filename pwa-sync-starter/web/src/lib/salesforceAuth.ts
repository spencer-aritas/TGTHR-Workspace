// web/src/lib/salesforceAuth.ts
interface OutreachUser {
  id: string;
  name: string;
  email: string;
  sfUserId: string;
}

interface DeviceRegistration {
  deviceId: string;
  userId: string;
  sfUserId: string;
  registeredAt: string;
  lastSyncAt?: string;
}

let _cachedUsers: OutreachUser[] | null = null;

export async function getOutreachUsers(): Promise<OutreachUser[]> {
  if (_cachedUsers) {
    return _cachedUsers;
  }
  
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000); // 3 second timeout
    
    const response = await fetch('/api/users/outreach', {
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    if (response.ok) {
      _cachedUsers = await response.json();
      if (_cachedUsers && _cachedUsers.length > 0) {
        return _cachedUsers;
      }
    }
  } catch (error) {
    console.error('Failed to fetch users:', error);
  }
  
  // Fallback mock users for development
  _cachedUsers = [
    {
      id: 'user1',
      name: 'Demo User',
      email: 'demo@example.com',
      sfUserId: 'sf_user_1'
    }
  ];
  
  return _cachedUsers;
}

export function getCurrentUser(): OutreachUser | null {
  const userData = localStorage.getItem('tgthr_current_user');
  return userData ? JSON.parse(userData) : null;
}

export function setCurrentUser(user: OutreachUser): void {
  localStorage.setItem('tgthr_current_user', JSON.stringify(user));
}

export function isUserSelected(): boolean {
  return !!getCurrentUser();
}

function generateUUID(): string {
  if (crypto.randomUUID) {
    return crypto.randomUUID();
  }
  // Fallback for older browsers
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

export function getDeviceId(): string {
  let deviceId = localStorage.getItem('tgthr_device_id');
  if (!deviceId) {
    deviceId = generateUUID();
    localStorage.setItem('tgthr_device_id', deviceId);
  }
  return deviceId;
}

// One-time device registration with user selection
export async function registerDevice(user: OutreachUser): Promise<boolean> {
  const deviceId = getDeviceId();
  const registration: DeviceRegistration = {
    deviceId,
    userId: user.id,
    sfUserId: user.sfUserId,
    registeredAt: new Date().toISOString()
  };
  
  try {
    const response = await fetch('/api/device/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(registration)
    });
    
    if (response.ok) {
      setCurrentUser(user);
      localStorage.setItem('tgthr_device_registered', 'true');
      return true;
    }
  } catch (error) {
    console.error('Device registration failed:', error);
  }
  
  return false;
}

// Check if device is already registered
export function isDeviceRegistered(): boolean {
  return localStorage.getItem('tgthr_device_registered') === 'true' && !!getCurrentUser();
}

// Salesforce OAuth Web Flow
export async function loginWithSalesforce(): Promise<void> {
  try {
    console.log('Starting OAuth flow...');
    const response = await fetch('/api/auth/oauth-config');
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const { clientId, loginUrl } = await response.json();
    console.log('OAuth config received:', { clientId: clientId?.substring(0, 10) + '...', loginUrl });
    
    // Use current origin for redirect (works for both localhost and IP addresses)
    const redirectUri = encodeURIComponent(window.location.origin + '/auth/callback');
    console.log('Redirect URI:', redirectUri);
    const state = generateUUID();
    
    localStorage.setItem('oauth_state', state);
    
    const authUrl = `${loginUrl}/services/oauth2/authorize?` +
      `response_type=code&` +
      `client_id=${clientId}&` +
      `redirect_uri=${redirectUri}&` +
      `state=${state}&` +
      `scope=full%20refresh_token`;
    
    console.log('Redirecting to:', authUrl.substring(0, 100) + '...');
    window.location.href = authUrl;
  } catch (error) {
    console.error('OAuth flow failed:', error);
    alert(`Login failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// Handle OAuth callback
export async function handleOAuthCallback(): Promise<boolean> {
  const urlParams = new URLSearchParams(window.location.search);
  const code = urlParams.get('code');
  const state = urlParams.get('state');
  const storedState = localStorage.getItem('oauth_state');
  
  console.log('OAuth callback params:', { code: code?.substring(0, 10) + '...', state, storedState });
  
  if (!code || !state || state !== storedState) {
    console.error('OAuth validation failed:', { code: !!code, state: !!state, stateMatch: state === storedState });
    throw new Error('Invalid OAuth callback');
  }
  
  try {
    console.log('Sending OAuth callback request...');
    const response = await fetch('/api/auth/oauth-callback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code })
    });
    
    console.log('OAuth callback response:', response.status, response.statusText);
    
    if (response.ok) {
      const { user } = await response.json();
      console.log('OAuth success, registering device for user:', user.name);
      return registerDevice(user);
    } else {
      const errorText = await response.text();
      console.error('OAuth callback failed:', response.status, errorText);
    }
  } catch (error) {
    console.error('OAuth callback failed:', error instanceof Error ? error.message : String(error));
  }
  
  return false;
}

// Test Salesforce connection using existing JWT
export async function testSalesforceConnection(): Promise<boolean> {
  try {
    const response = await fetch('/api/sf/whoami');
    return response.ok;
  } catch {
    return false;
  }
}