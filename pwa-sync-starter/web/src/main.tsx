
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Auto-trigger background sync when online
if ('serviceWorker' in navigator) {
  window.addEventListener('online', async () => {
    console.log('Back online - triggering sync')
    try {
      const registration = await navigator.serviceWorker.ready
      await registration.sync.register('syncQueue')
    } catch (error) {
      console.error('Failed to trigger sync:', error)
    }
  })
}

const root = createRoot(document.getElementById('root')!)
root.render(<App />)
