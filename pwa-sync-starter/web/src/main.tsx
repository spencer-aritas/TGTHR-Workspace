
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Register service worker
if ('serviceWorker' in navigator) {
  // Skip immediate registration if we're handling OAuth callback
  const isOAuthCallback = window.location.pathname === '/auth/callback' || 
                         window.location.search.includes('code=');
  
  if (!isOAuthCallback) {
    navigator.serviceWorker.register('/sw.js', { scope: '/' })
      .then((registration) => {
        console.log('Service worker registered successfully:', registration.scope);
        
        // Only update if we're not in the middle of auth
        if (!window.location.pathname.includes('/auth/')) {
          registration.update();
        }
        
        // Listen for new service workers
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          if (newWorker) {
            newWorker.addEventListener('statechange', () => {
              if (newWorker.state === 'activated' && !window.location.pathname.includes('/auth/')) {
                console.log('New service worker activated');
                window.location.reload();
              }
            });
          }
        });
      })
      .catch((error) => {
        console.error('Service worker registration failed:', error);
      });
  } else {
    console.log('Skipping service worker registration during OAuth callback');
  }
}





const root = createRoot(document.getElementById('root')!)
root.render(<App />)
