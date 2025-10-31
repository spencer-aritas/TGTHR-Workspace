
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Register service worker with retry
async function registerServiceWorker() {
  if (!('serviceWorker' in navigator)) {
    console.log('Service workers are not supported');
    return;
  }

  const isOAuthCallback = window.location.pathname === '/auth/callback' || 
                         window.location.search.includes('code=');
  
  if (isOAuthCallback) {
    console.log('Skipping service worker registration during OAuth callback');
    return;
  }

  try {
    // Unregister any existing service workers first
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map(r => r.unregister()));
    
    // Register new service worker
    const registration = await navigator.serviceWorker.register('/sw.js', { 
      scope: '/',
      type: 'module'
    });
    
    console.log('Service worker registered successfully:', registration.scope);
    
    // Handle updates
    registration.addEventListener('updatefound', () => {
      const newWorker = registration.installing;
      if (newWorker) {
        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'activated') {
            console.log('New service worker activated');
            if (!window.location.pathname.includes('/auth/')) {
              window.location.reload();
            }
          }
        });
      }
    });

    // Check if we need immediate activation
    if (registration.active) {
      registration.active.postMessage({ type: 'SKIP_WAITING' });
    }
  } catch (error) {
    console.error('Service worker registration failed:', error);
  }
}

// Call registration function
registerServiceWorker();





const root = createRoot(document.getElementById('root')!)
root.render(<App />)
