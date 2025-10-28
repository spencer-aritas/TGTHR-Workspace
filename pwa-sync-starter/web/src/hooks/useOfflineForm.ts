import { useState, useEffect, useCallback } from 'react';

interface OfflineFormOptions {
  formId: string;
  endpoint: string;
  clearAfterMinutes?: number; // Auto-clear for HIPAA compliance
}

interface FormData {
  [key: string]: any;
}

interface OfflineFormState {
  data: FormData;
  isOnline: boolean;
  isSyncing: boolean;
  lastSaved: Date | null;
  pendingSync: boolean;
}

export function useOfflineForm({ formId, endpoint, clearAfterMinutes = 30 }: OfflineFormOptions) {
  const [state, setState] = useState<OfflineFormState>({
    data: {},
    isOnline: navigator.onLine,
    isSyncing: false,
    lastSaved: null,
    pendingSync: false
  });

  const storageKey = `offline_form_${formId}`;

  // Load cached data on mount
  useEffect(() => {
    const cached = localStorage.getItem(storageKey);
    if (cached) {
      const { data, timestamp } = JSON.parse(cached);
      const age = Date.now() - timestamp;
      
      if (age < (clearAfterMinutes * 60 * 1000)) {
        setState(prev => ({ ...prev, data, lastSaved: new Date(timestamp), pendingSync: true }));
      } else {
        localStorage.removeItem(storageKey);
      }
    }
  }, [formId, clearAfterMinutes]);

  // Monitor online status
  useEffect(() => {
    const handleOnline = () => setState(prev => ({ ...prev, isOnline: true }));
    const handleOffline = () => setState(prev => ({ ...prev, isOnline: false }));

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  // Auto-sync when online
  useEffect(() => {
    if (state.isOnline && state.pendingSync && !state.isSyncing) {
      syncData();
    }
  }, [state.isOnline, state.pendingSync]);

  // Auto-clear timer for HIPAA compliance
  useEffect(() => {
    if (!state.lastSaved) return;

    const timeoutId = setTimeout(() => {
      clearData();
    }, clearAfterMinutes * 60 * 1000);

    return () => clearTimeout(timeoutId);
  }, [state.lastSaved, clearAfterMinutes]);

  const saveData = useCallback((data: FormData) => {
    const timestamp = Date.now();
    localStorage.setItem(storageKey, JSON.stringify({ data, timestamp }));
    
    setState(prev => ({
      ...prev,
      data,
      lastSaved: new Date(timestamp),
      pendingSync: !prev.isOnline
    }));

    if (state.isOnline) {
      syncData();
    }
  }, [state.isOnline]);

  const syncData = useCallback(async () => {
    if (!state.data || Object.keys(state.data).length === 0) return;

    setState(prev => ({ ...prev, isSyncing: true }));

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(state.data)
      });

      if (response.ok) {
        clearData();
      }
    } catch (error) {
      console.error('Sync failed:', error);
    } finally {
      setState(prev => ({ ...prev, isSyncing: false }));
    }
  }, [state.data, endpoint]);

  const clearData = useCallback(() => {
    localStorage.removeItem(storageKey);
    setState(prev => ({
      ...prev,
      data: {},
      lastSaved: null,
      pendingSync: false
    }));
  }, []);

  return {
    ...state,
    saveData,
    syncData,
    clearData
  };
}