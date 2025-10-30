import { hipaaDB, clearAllClientData, clearExpired } from '../db/hipaa-client';

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
  private lastActivity = Date.now();

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
    this.lastActivity = Date.now();
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

  private startPeriodicCleanup() {
    setInterval(() => {
      clearExpired(this.config.maxAge).catch(console.error);
    }, 5 * 60 * 1000); // Check every 5 minutes
  }

  private async clearAllData() {
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

    console.log('HIPAA compliance: All PHI data cleared');
  }

  // Manual clear for logout
  clearOnLogout() {
    this.clearAllData();
  }
}

export const hipaaCompliance = new HIPAACompliance();