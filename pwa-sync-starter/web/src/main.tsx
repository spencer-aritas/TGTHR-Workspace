
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Register service worker
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
    // Register service worker if not already registered
    const registration = await navigator.serviceWorker.register('/sw.js', { 
      scope: '/',
      type: 'module'
    });
    
    console.log('Service worker registered successfully:', registration.scope);
    
    // Handle updates more gracefully
    registration.addEventListener('updatefound', () => {
      const newWorker = registration.installing;
      if (newWorker) {
        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed') {
            if (registration.active) {
              // New version available - show prompt or handle update
              console.log('New service worker version available');
              // Optional: implement user prompt for reload
            }
          }
        });
      }
    });
  } catch (error) {
    console.error('Service worker registration failed:', error);
  }
}

// Call registration function
registerServiceWorker();





const root = createRoot(document.getElementById('root')!)
root.render(<App />)
