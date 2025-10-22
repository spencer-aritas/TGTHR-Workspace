
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

// Simple Service Worker registration
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js')
    .then(reg => console.log('SW registered'))
    .catch(err => console.log('SW failed:', err))
}



const root = createRoot(document.getElementById('root')!)
root.render(<App />)
