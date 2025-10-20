// web/src/components/IntakeStatus.tsx
import React, { useState, useEffect } from 'react';
import { intakeDb } from '../store/intakeStore';
import { syncPendingIntakes } from '../workers/intakeSync';

export default function IntakeStatus() {
  const [stats, setStats] = useState({ total: 0, synced: 0, pending: 0 });
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    loadStats();
  }, []);

  async function loadStats() {
    const total = await intakeDb.intakes.count();
    const synced = await intakeDb.intakes.where('synced').equals(true).count();
    const pending = total - synced;
    setStats({ total, synced, pending });
  }

  async function handleSync() {
    setSyncing(true);
    try {
      await syncPendingIntakes();
      await loadStats();
    } finally {
      setSyncing(false);
    }
  }

  return (
    <div className="slds-card slds-m-around_small">
      <div className="slds-card__header">
        <h3 className="slds-text-heading_small">Intake Status</h3>
      </div>
      <div className="slds-card__body slds-p-horizontal_small">
        <div className="slds-grid slds-wrap">
          <div className="slds-col slds-size_1-of-3 slds-text-align_center">
            <div className="slds-text-heading_large">{stats.total}</div>
            <div className="slds-text-body_small">Total</div>
          </div>
          <div className="slds-col slds-size_1-of-3 slds-text-align_center">
            <div className="slds-text-heading_large slds-text-color_success">{stats.synced}</div>
            <div className="slds-text-body_small">Synced</div>
          </div>
          <div className="slds-col slds-size_1-of-3 slds-text-align_center">
            <div className="slds-text-heading_large slds-text-color_warning">{stats.pending}</div>
            <div className="slds-text-body_small">Pending</div>
          </div>
        </div>
        {stats.pending > 0 && (
          <div className="slds-m-top_small">
            <button 
              className="slds-button slds-button_brand slds-size_1-of-1" 
              onClick={handleSync}
              disabled={syncing}
            >
              {syncing ? 'Syncing...' : 'Sync Now'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}