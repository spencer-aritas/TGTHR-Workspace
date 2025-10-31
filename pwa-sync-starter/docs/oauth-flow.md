# OAuth Flow Documentation

## Overview

The application uses OAuth 2.0 with Salesforce for authentication. This document outlines the flow and key components involved.

## Components

### Frontend Components

1. `web/src/components/UserSelection.tsx`
   - Manages the login UI and OAuth callback handling
   - Uses hooks from `salesforceAuth.ts` for OAuth operations
   - Handles redirect URI cleanup to prevent callback loops

2. `web/src/lib/salesforceAuth.ts`
   - Provides OAuth-related utilities
   - Manages OAuth state
   - Handles device registration after successful auth

### Backend Components

1. `server/app/api/auth.py`
   - OAuth configuration endpoint (`/api/auth/oauth-config`)
   - OAuth callback handler (`/api/auth/oauth-callback`)
   - Token exchange with Salesforce

## Authentication Flow

1. **Initial Login**
   ```mermaid
   sequenceDiagram
       User->>Frontend: Click "Login with Salesforce"
       Frontend->>Backend: GET /api/auth/oauth-config
       Backend->>Frontend: Return OAuth configuration
       Frontend->>Salesforce: Redirect to OAuth authorization URL
       Salesforce->>User: Display login/consent page
   ```

2. **OAuth Callback**
   ```mermaid
   sequenceDiagram
       Salesforce->>Frontend: Redirect with auth code
       Frontend->>Backend: POST /api/auth/oauth-callback
       Backend->>Salesforce: Exchange code for token
       Salesforce->>Backend: Return access token
       Backend->>Salesforce: Get user info
       Backend->>Frontend: Return user data
       Frontend->>Backend: Register device
   ```

## Critical Settings

### Redirect URIs
Must be configured in Salesforce Connected App settings:
```
http://localhost:5173/auth/callback
https://localhost/auth/callback
https://outreachintake.aritasconsulting.com/auth/callback
```

### Environment Variables
```env
SF_ENV=benefits
SF_BENEFITS_JWT_CONSUMER_KEY=<key>
SF_BENEFITS_JWT_CONSUMER_SECRET=<secret>
SF_BENEFITS_JWT_USERNAME=<username>
SF_BENEFITS_JWT_LOGIN_URL=https://test.salesforce.com
```

## Known Issues and Solutions

### OAuth Callback Loop Prevention

**Issue:**
The OAuth callback URL remaining in the browser's address bar caused React's useEffect to trigger multiple times, attempting to reuse the same OAuth code.

**Solution:**
1. Clear URL parameters immediately after reading:
```typescript
// In UserSelection.tsx
if (window.location.search.includes('code=')) {
  // Clear the URL parameters to prevent re-handling
  window.history.replaceState({}, '', window.location.pathname);
  // Handle OAuth callback...
}
```

2. Added error handling for failed callbacks:
```typescript
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
  });
```

### Domain Configuration

**Important:** The token exchange must use the correct Salesforce domain:
- Sandbox: `https://tgthrnpc--benefits.sandbox.my.salesforce.com`
- Production: `https://tgthrnpc.my.salesforce.com`

## Testing Checklist

1. **Initial Login**
   - [ ] Login button visible
   - [ ] Redirects to Salesforce
   - [ ] Consent screen appears if needed

2. **OAuth Callback**
   - [ ] Successfully returns to app
   - [ ] URL parameters cleared
   - [ ] No callback loops
   - [ ] Device registration succeeds

3. **Error Handling**
   - [ ] Invalid/expired codes handled gracefully
   - [ ] Network errors show appropriate messages
   - [ ] Falls back to manual selection on failure

## Debugging Tips

1. Monitor network requests in browser dev tools
2. Check API logs for token exchange details:
   ```bash
   docker compose logs api | grep -A 10 "oauth"
   ```
3. Verify correct domain usage in auth.py
4. Check for multiple callback attempts in browser console

## Security Considerations

1. OAuth codes are single-use only
2. HTTPS required for production
3. State parameter used to prevent CSRF
4. Secure storage of tokens
5. Regular rotation of client secrets

## Related Files

- `docker-compose.yml`: Service configuration
- `Caddyfile`: HTTPS and proxy settings
- `.env`: Environment configuration
- `server/requirements.txt`: Python dependencies