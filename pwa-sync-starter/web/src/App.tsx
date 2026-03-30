// web/src/App.tsx
import { useState, useEffect } from "react"
import ProgramIntakeForm from "./features/intake/ProgramIntakeForm"
import { SyncStatus } from "./components/SyncStatus"
import { UserSelection } from "./components/UserSelection"
import { MyCasesPage } from "./components/MyCasesPage"
import { PendingSignaturesPage } from "./components/PendingSignaturesPage"
import { OfflineIndicator } from "./components/OfflineIndicator"
import { isDeviceRegistered, getCurrentUser } from "./lib/salesforceAuth"
import { syncService } from "./lib/syncService"
import { pendingSignatureService } from "./services/pendingSignatureService"

export default function App() {
  const [showUserSelection, setShowUserSelection] = useState(false)
  const [currentUser, setCurrentUser] = useState(getCurrentUser())
  const [currentPage, setCurrentPage] = useState<'intake' | 'cases' | 'signatures'>('cases')
  const [pendingCount, setPendingCount] = useState(0)

  useEffect(() => {
    if (!isDeviceRegistered()) {
      setShowUserSelection(true)
    }
    
    // Start auto-sync service
    syncService.startAutoSync();

    // Poll pending signature count
    const refreshCount = () => {
      pendingSignatureService.getPendingSignatures()
        .then(items => setPendingCount(items.length))
        .catch(() => {});
    };
    refreshCount();
    const interval = setInterval(refreshCount, 60_000); // every 60s
    return () => clearInterval(interval);
  }, [])

  const handleUserSelectionComplete = () => {
    setShowUserSelection(false)
    setCurrentUser(getCurrentUser())
  }

  if (showUserSelection) {
    return <UserSelection onUserSelected={handleUserSelectionComplete} />
  }

  if (currentPage === 'signatures') {
    return <PendingSignaturesPage onBack={() => setCurrentPage('cases')} />
  }

  if (currentPage === 'cases') {
    return (
      <div>
        <nav className="slds-p-around_small" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
          <div className="slds-grid slds-grid_align-spread">
            <div className="slds-col">
              <div className="slds-media">
                <div className="slds-media__figure">
                  <img 
                    src="/icons/icon-192.png" 
                    alt="TGTHR Logo" 
                    style={{width: '40px', height: '40px', borderRadius: '4px'}}
                  />
                </div>
                <div className="slds-media__body">
                  <h2 className="slds-text-heading_small" style={{margin: '0'}}>My Cases</h2>
                </div>
              </div>
            </div>
            <div className="slds-col slds-text-align_right">
              <div className="slds-button-group">
                <button
                  className="slds-button slds-button_outline-brand"
                  onClick={() => setCurrentPage('signatures')}
                  style={{ position: 'relative' }}
                >
                  Pending Signatures
                  {pendingCount > 0 && (
                    <span style={{
                      position: 'absolute', top: '-6px', right: '-6px',
                      backgroundColor: '#c23934', color: 'white',
                      borderRadius: '50%', width: '20px', height: '20px',
                      fontSize: '0.7rem', fontWeight: 700, lineHeight: '20px',
                      textAlign: 'center',
                    }}>
                      {pendingCount}
                    </span>
                  )}
                </button>
                <button 
                  className="slds-button slds-button_outline-brand"
                  onClick={() => setCurrentPage('intake')}
                >
                  New Client Intake
                </button>
              </div>
            </div>
          </div>
          <div className="slds-m-top_x-small">
            <SyncStatus />
          </div>
        </nav>
        <MyCasesPage />
      </div>
    )
  }

  return (
    <div className="slds" style={{minHeight: '100vh', backgroundColor: '#f8f9fa'}}>
      <OfflineIndicator />
      <nav className="slds-p-around_small" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
        <div className="slds-grid slds-grid_align-spread">
          <div className="slds-col">
            <div className="slds-media">
              <div className="slds-media__figure">
                <img 
                  src="/icons/icon-192.png" 
                  alt="TGTHR Logo" 
                  style={{width: '40px', height: '40px', borderRadius: '4px'}}
                />
              </div>
              <div className="slds-media__body">
                <h2 className="slds-text-heading_small" style={{margin: '0'}}>New Client Intake</h2>
              </div>
            </div>
          </div>
          <div className="slds-col slds-text-align_right">
            <div className="slds-button-group">
              <button 
                className="slds-button slds-button_outline-brand"
                onClick={() => setCurrentPage('cases')}
              >
                My Cases
              </button>
            </div>
          </div>
        </div>
      </nav>
      <header className="slds-page-header slds-p-around_medium" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
        <div className="slds-media">
          <div className="slds-media__body">
            <p className="slds-page-header__info">
              {currentUser ? `${currentUser.name} | ` : ''}Capture client information for outreach services
            </p>
          </div>
        </div>
        <div className="slds-m-top_small">
          <SyncStatus />
        </div>
      </header>

      <div className="slds-p-around_medium">
        <div style={{backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)'}}>
          <ProgramIntakeForm />
        </div>
      </div>
      

    </div>
  )
}
