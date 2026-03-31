// web/src/App.tsx
import { useState, useEffect } from "react"
import ProgramIntakeForm from "./features/intake/ProgramIntakeForm"
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
        <nav style={{
          backgroundColor: 'white',
          borderBottom: '2px solid #e5e5e5',
          padding: '12px 16px',
          position: 'sticky',
          top: 0,
          zIndex: 10,
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '12px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
              <img
                src="/icons/icon-192.png"
                alt="TGTHR"
                style={{ width: '36px', height: '36px', borderRadius: '8px', flexShrink: 0 }}
              />
              <h1 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, whiteSpace: 'nowrap', color: '#16325c' }}>
                My Cases
              </h1>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexShrink: 0 }}>
              <button
                className="slds-button slds-button_outline-brand"
                onClick={() => setCurrentPage('signatures')}
                style={{ position: 'relative', borderRadius: '6px', overflow: 'visible' }}
              >
                Pending Signatures
                {pendingCount > 0 && (
                  <span style={{
                    position: 'absolute', top: '-10px', right: '-10px',
                    backgroundColor: '#c23934', color: 'white',
                    borderRadius: '10px', minWidth: '22px', height: '22px',
                    fontSize: '0.72rem', fontWeight: 700, lineHeight: '22px',
                    textAlign: 'center', padding: '0 5px',
                    zIndex: 1,
                    boxShadow: '0 1px 3px rgba(0,0,0,0.25)',
                  }}>
                    {pendingCount}
                  </span>
                )}
              </button>
              <button
                className="slds-button slds-button_brand"
                onClick={() => setCurrentPage('intake')}
                style={{ borderRadius: '6px' }}
              >
                + New Intake
              </button>
            </div>
          </div>
        </nav>
        <MyCasesPage />
      </div>
    )
  }

  return (
    <div className="slds" style={{minHeight: '100vh', backgroundColor: '#f8f9fa'}}>
      <OfflineIndicator />
      <nav style={{
        backgroundColor: 'white',
        borderBottom: '2px solid #e5e5e5',
        padding: '12px 16px',
        position: 'sticky',
        top: 0,
        zIndex: 10,
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '12px',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
            <img
              src="/icons/icon-192.png"
              alt="TGTHR"
              style={{ width: '36px', height: '36px', borderRadius: '8px', flexShrink: 0 }}
            />
            <h1 style={{ fontSize: '1.125rem', fontWeight: 700, margin: 0, whiteSpace: 'nowrap', color: '#16325c' }}>
              New Client Intake
            </h1>
          </div>
          <button
            className="slds-button slds-button_outline-brand"
            onClick={() => setCurrentPage('cases')}
            style={{ borderRadius: '6px' }}
          >
            My Cases
          </button>
        </div>
      </nav>
      <header style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5', padding: '10px 16px' }}>
        <p className="slds-text-body_small slds-text-color_weak" style={{ margin: 0 }}>
          {currentUser ? `${currentUser.name} | ` : ''}Capture client information for outreach services
        </p>
      </header>

      <div className="slds-p-around_medium">
        <div style={{backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)'}}>
          <ProgramIntakeForm />
        </div>
      </div>
      

    </div>
  )
}
