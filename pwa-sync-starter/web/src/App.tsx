// web/src/App.tsx
import React, { useState, useEffect } from "react"
import PersonForm from "./features/person/PersonForm"
import { SyncStatus } from "./components/SyncStatus"
import { UserSelection } from "./components/UserSelection"
import { MyCasesPage } from "./components/MyCasesPage"
import { OfflineIndicator } from "./components/OfflineIndicator"
import { isDeviceRegistered, getCurrentUser } from "./lib/salesforceAuth"
import { syncService } from "./lib/syncService"

export default function App() {
  const [showUserSelection, setShowUserSelection] = useState(false)
  const [currentUser, setCurrentUser] = useState(getCurrentUser())
  const [currentPage, setCurrentPage] = useState<'intake' | 'cases'>('intake')

  useEffect(() => {
    if (!isDeviceRegistered()) {
      setShowUserSelection(true)
    }
    
    // Start auto-sync service
    syncService.startAutoSync();
  }, [])

  const handleUserSelectionComplete = () => {
    setShowUserSelection(false)
    setCurrentUser(getCurrentUser())
  }

  if (showUserSelection) {
    return <UserSelection onUserSelected={handleUserSelectionComplete} />
  }

  if (currentPage === 'cases') {
    return (
      <div>
        <nav className="slds-p-around_small" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
          <button 
            className="slds-button slds-button_neutral"
            onClick={() => setCurrentPage('intake')}
          >
            ← Back to Client Intake
          </button>
        </nav>
        <MyCasesPage />
      </div>
    )
  }

  return (
    <div className="slds" style={{minHeight: '100vh', backgroundColor: '#f8f9fa'}}>
      <OfflineIndicator />
      <header className="slds-page-header slds-p-around_medium" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
        <div className="slds-media">
          <div className="slds-media__figure">
            <img 
              src="/icons/icon-192.png" 
              alt="TGTHR Logo" 
              className="slds-avatar slds-avatar_large"
              style={{width: '48px', height: '48px', borderRadius: '4px'}}
            />
          </div>
          <div className="slds-media__body">
            <h1 className="slds-page-header__title slds-truncate">New Client Intake</h1>
            <p className="slds-page-header__info">
              {currentUser ? `${currentUser.name} • ` : ''}Capture client information for outreach services
            </p>
          </div>
          <div className="slds-media__figure">
            <button 
              className="slds-button slds-button_outline-brand"
              onClick={() => setCurrentPage('cases')}
            >
              📋 My Cases
            </button>
          </div>
        </div>
        <div className="slds-m-top_small">
          <SyncStatus />
        </div>
      </header>

      <div className="slds-p-around_medium">
        <div style={{backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)'}}>
          <PersonForm />
        </div>
      </div>
      

    </div>
  )
}
