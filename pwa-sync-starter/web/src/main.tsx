
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'
import './lib/manualSync' // Auto-trigger background sync when online

const root = createRoot(document.getElementById('root')!)
root.render(<App />)
