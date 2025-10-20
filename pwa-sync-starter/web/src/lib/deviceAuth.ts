// web/src/lib/deviceAuth.ts
interface OutreachWorker {
  id: string;
  name: string;
  email: string;
}

// Pre-configured list of outreach workers
const OUTREACH_WORKERS: OutreachWorker[] = [
  { id: 'worker-001', name: 'Sarah Johnson', email: 'sarah@tgthr.org' },
  { id: 'worker-002', name: 'Mike Chen', email: 'mike@tgthr.org' },
  { id: 'worker-003', name: 'Alex Rivera', email: 'alex@tgthr.org' },
  { id: 'worker-004', name: 'Jordan Smith', email: 'jordan@tgthr.org' },
  // Add your actual outreach workers here
];

export function getOutreachWorkers(): OutreachWorker[] {
  return OUTREACH_WORKERS;
}

export function getDeviceId(): string {
  let deviceId = localStorage.getItem('tgthr_device_id');
  if (!deviceId) {
    deviceId = crypto.randomUUID();
    localStorage.setItem('tgthr_device_id', deviceId);
  }
  return deviceId;
}

export function getCurrentWorker(): OutreachWorker | null {
  const workerId = localStorage.getItem('tgthr_worker_id');
  if (!workerId) return null;
  return OUTREACH_WORKERS.find(w => w.id === workerId) || null;
}

export function setCurrentWorker(workerId: string): void {
  localStorage.setItem('tgthr_worker_id', workerId);
}

export function isDeviceRegistered(): boolean {
  return !!getCurrentWorker();
}