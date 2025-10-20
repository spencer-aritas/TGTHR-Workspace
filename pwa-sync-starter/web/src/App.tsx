// web/src/App.tsx
import React, { useState, useEffect } from "react"
import PersonForm from "./features/person/PersonForm"
import { SyncStatus } from "./components/SyncStatus"
import { UserSelection } from "./components/UserSelection"
import { EnrollmentsPage } from "./components/EnrollmentsPage"
import { isDeviceRegistered, getCurrentUser } from "./lib/salesforceAuth"

export default function App() {
  const [showUserSelection, setShowUserSelection] = useState(false)
  const [currentUser, setCurrentUser] = useState(getCurrentUser())
  const [currentPage, setCurrentPage] = useState<'intake' | 'enrollments'>('intake')

  useEffect(() => {
    if (!isDeviceRegistered()) {
      setShowUserSelection(true)
    }
  }, [])

  const handleUserSelectionComplete = () => {
    setShowUserSelection(false)
    setCurrentUser(getCurrentUser())
  }

  if (showUserSelection) {
    return <UserSelection onUserSelected={handleUserSelectionComplete} />
  }

  if (currentPage === 'enrollments') {
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
        <EnrollmentsPage />
      </div>
    )
  }

  return (
    <div className="slds" style={{minHeight: '100vh', backgroundColor: '#f8f9fa'}}>
      <header className="slds-page-header slds-p-around_medium" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
        <div className="slds-media">
          <div className="slds-media__figure">
            <div className="slds-avatar slds-avatar_large" style={{backgroundColor: '#1976d2', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '24px', fontWeight: 'bold'}}>
              T
            </div>
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
              onClick={() => setCurrentPage('enrollments')}
            >
              📋 View Enrollments
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
