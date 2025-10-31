
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Register service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js', { scope: '/' })
    .then((registration) => {
      console.log('Service worker registered successfully:', registration.scope);
      
      // Force update if needed
      registration.update();
      
      // Listen for new service workers
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing;
        if (newWorker) {
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'activated') {
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
}





const root = createRoot(document.getElementById('root')!)
root.render(<App />)
