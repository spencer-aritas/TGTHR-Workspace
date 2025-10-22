
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Register Service Worker manually
if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register('/sw.js')
      console.log('SW registered:', registration)
      
      // Auto-trigger sync when online
      window.addEventListener('online', async () => {
        console.log('Back online - triggering sync')
        try {
          await registration.sync.register('syncQueue')
        } catch (error) {
          console.error('Failed to trigger sync:', error)
        }
      })
    } catch (error) {
      console.error('SW registration failed:', error)
    }
  })
}

// Prevent Vite HMR from interfering when offline
if (import.meta.hot && !navigator.onLine) {
  import.meta.hot.dispose(() => {})
}

const root = createRoot(document.getElementById('root')!)
root.render(<App />)
