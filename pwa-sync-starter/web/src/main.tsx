
import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'
import '@salesforce-ux/design-system/assets/styles/salesforce-lightning-design-system.min.css';

const root = createRoot(document.getElementById('root')!)
root.render(<App />)
