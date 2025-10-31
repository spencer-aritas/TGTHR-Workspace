import { clearExpired } from '../db/hipaa-client';
import type { AuditLogRequest } from '../../../shared/contracts/AuditLogContract';

interface ClearanceConfig {
  maxAge: number; // milliseconds
  clearOnIdle: number; // milliseconds of inactivity
  clearOnVisibilityChange: boolean;
}

class HIPAACompliance {
  private config: ClearanceConfig = {
    maxAge: 30 * 60 * 1000, // 30 minutes
    clearOnIdle: 15 * 60 * 1000, // 15 minutes idle
    clearOnVisibilityChange: true
  };

  private idleTimer: ReturnType<typeof setTimeout> | null = null;

  init(config?: Partial<ClearanceConfig>) {
    if (config) {
      this.config = { ...this.config, ...config };
    }

    this.setupEventListeners();
    this.startPeriodicCleanup();
    this.resetIdleTimer();
  }

  private setupEventListeners() {
    // Track user activity
    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart'];
    events.forEach(event => {
      document.addEventListener(event, this.handleActivity.bind(this), true);
    });

    // Clear on tab visibility change (HIPAA requirement)
    if (this.config.clearOnVisibilityChange) {
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
          this.clearAllData();
        }
      });
    }

    // Clear on page unload
    window.addEventListener('beforeunload', () => {
      this.clearAllData();
    });
  }

  private handleActivity() {
    this.resetIdleTimer();
  }

  private resetIdleTimer() {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
    }

    this.idleTimer = setTimeout(() => {
      this.clearAllData();
    }, this.config.clearOnIdle);
  }

  private async logAuditEvent(event: AuditLogRequest): Promise<void> {
    try {
      const response = await fetch('/api/audit-log', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(event)
      });
      
      if (!response.ok) {
        console.error('Failed to log audit event:', await response.text());
      }
    } catch (err) {
      console.error('Error logging audit event:', err);
      // Don't throw - we don't want audit logging failures to break core functionality
    }
  }

  private startPeriodicCleanup() {
    setInterval(async () => {
      try {
        await clearExpired(this.config.maxAge);
        await this.logAuditEvent({
          actionType: 'PHI_DATA_EXPIRED',
          entityId: 'SYSTEM',
          details: `Cleared expired PHI data older than ${this.config.maxAge}ms`,
          eventType: 'HIPAA_COMPLIANCE',
          application: 'PWA',
          complianceReference: 'HIPAA_164.312(a)(1)',
          sourceIP: window.location.hostname,
          status: 'SUCCESS'
        });
      } catch (err) {
        console.error('Error in periodic cleanup:', err);
        if (err instanceof Error) {
          await this.logAuditEvent({
            actionType: 'PHI_DATA_EXPIRED',
            entityId: 'SYSTEM',
            details: `Error clearing expired PHI data: ${err.message}`,
            eventType: 'HIPAA_COMPLIANCE',
            application: 'PWA',
            complianceReference: 'HIPAA_164.312(a)(1)',
            sourceIP: window.location.hostname,
            status: 'ERROR'
          });
        }
      }
    }, 5 * 60 * 1000); // Check every 5 minutes
  }

  private async clearAllData() {
    try {
      // Log the action before clearing
      const auditEvent: AuditLogRequest = {
        actionType: 'PHI_DATA_CLEARED',
        entityId: 'SYSTEM',
        details: 'Automated PHI data clearing triggered',
        eventType: 'HIPAA_COMPLIANCE',
        application: 'PWA',
        complianceReference: 'HIPAA_164.312(a)(1)',
        sourceIP: window.location.hostname
      };

      // Clear localStorage
      Object.keys(localStorage).forEach(key => {
        if (key.startsWith('offline_form_') || key.includes('phi_')) {
          localStorage.removeItem(key);
        }
      });
      // Clear sessionStorage
      sessionStorage.clear();

      // Clear IndexedDB
      await clearExpired(0);

      // Append success to audit
      auditEvent.details += ' - Successfully cleared all PHI data';
      auditEvent.status = 'SUCCESS';

      // Send audit log to server
      await this.logAuditEvent(auditEvent);

      console.log('HIPAA compliance: All PHI data cleared');
    } catch (err) {
      console.error('Error during PHI data clearing:', err);
      // Still try to log the failure
      await this.logAuditEvent({
        actionType: 'PHI_DATA_CLEARED',
        entityId: 'SYSTEM',
        details: `Error during PHI data clearing: ${err instanceof Error ? err.message : 'Unknown error'}`,
        eventType: 'HIPAA_COMPLIANCE',
        application: 'PWA',
        complianceReference: 'HIPAA_164.312(a)(1)',
        sourceIP: window.location.hostname,
        status: 'ERROR'
      });
    }
  }

  // Manual clear for logout
  clearOnLogout() {
    this.clearAllData();
  }
}

export const hipaaCompliance = new HIPAACompliance();