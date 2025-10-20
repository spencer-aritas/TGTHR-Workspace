// web/src/components/WorkerSetup.tsx
import { useState } from 'react';
import { getOutreachWorkers, setCurrentWorker } from '../lib/deviceAuth';

interface WorkerSetupProps {
  onComplete: () => void;
}

export function WorkerSetup({ onComplete }: WorkerSetupProps) {
  const [selectedWorker, setSelectedWorker] = useState('');
  const workers = getOutreachWorkers();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedWorker) {
      setCurrentWorker(selectedWorker);
      onComplete();
    }
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '16px',
        padding: '32px',
        maxWidth: '400px',
        width: '90%',
        boxShadow: '0 8px 32px rgba(0,0,0,0.2)'
      }}>
        <div className="slds-text-align_center slds-m-bottom_large">
          <div className="slds-avatar slds-avatar_large slds-m-bottom_small" style={{
            backgroundColor: '#1976d2',
            color: 'white',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '24px',
            fontWeight: 'bold'
          }}>
            T
          </div>
          <h2 className="slds-text-heading_medium">Welcome to TGTHR Outreach</h2>
          <p className="slds-text-body_small slds-text-color_weak">
            Select your name to get started
          </p>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="slds-form-element slds-m-bottom_large">
            <label className="slds-form-element__label" htmlFor="worker-select">
              Who are you?
            </label>
            <div className="slds-form-element__control">
              <select
                id="worker-select"
                className="slds-select"
                style={{
                  fontSize: '16px',
                  padding: '12px 16px',
                  borderRadius: '8px',
                  border: '2px solid #e5e5e5',
                  width: '100%'
                }}
                value={selectedWorker}
                onChange={(e) => setSelectedWorker(e.target.value)}
                required
              >
                <option value="">Choose your name...</option>
                {workers.map(worker => (
                  <option key={worker.id} value={worker.id}>
                    {worker.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <button
            type="submit"
            className="slds-button slds-button_brand"
            style={{
              width: '100%',
              padding: '16px',
              fontSize: '18px',
              fontWeight: 'bold',
              borderRadius: '12px',
              backgroundColor: '#1976d2',
              border: 'none'
            }}
            disabled={!selectedWorker}
          >
            🚀 Start Outreach
          </button>
        </form>
      </div>
    </div>
  );
}