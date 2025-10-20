# PWA Cleanup & MVP Stabilization

## What's Been Cleaned Up

### 1. **Consolidated Database Structure**
- `web/src/store/intakeStore.ts` - Single source for intake data
- Removed duplicate database schemas
- Clean offline-first storage with sync tracking

### 2. **Simplified Intake Flow**
- Minimal form: First Name, Last Name, Phone, Email, DOB, Notes
- Auto-generates UUIDs, timestamps, user context
- Stores locally first, syncs when possible

### 3. **Clean Sync Architecture**
- `web/src/workers/intakeSync.ts` - Dedicated intake sync
- `web/src/workers/syncWorkers.ts` - Cleaned up encounter sync
- No duplicate sync logic

### 4. **Contract-Based Integration**
- `shared/contracts/IntakeContract.ts` - Clear interface
- PWA and Salesforce use same data structure
- Prevents integration confusion

## Next Steps for Stable MVP

### 1. **Remove Unused Files**
```bash
# Remove duplicate database files
rm web/src/lib/db.ts

# Remove old encounter form if using new intake
rm web/src/features/outreach/OutreachForm.tsx  # if exists
```

### 2. **Update Service Worker**
Add intake sync to background sync:
```typescript
// In your service worker
import { syncPendingIntakes } from './workers/intakeSync';

self.addEventListener('sync', event => {
  if (event.tag === 'intake-sync') {
    event.waitUntil(syncPendingIntakes());
  }
});
```

### 3. **Environment Setup**
Ensure these are set in `.env.local`:
```
VITE_TGTHR_API=https://your-api-endpoint.com/api
```

### 4. **Salesforce Integration**
Your existing Salesforce components work as-is:
- `ProgramEnrollmentService.ingestEncounter()` handles full workflow
- Creates Person Account, Program Enrollment, Benefits, Interaction, Task
- No changes needed to Salesforce side

## File Structure (Clean MVP)
```
web/src/
├── api/intakeApi.ts           # API client
├── features/intake/           # Intake form
├── store/intakeStore.ts       # Local storage
├── types/intake.ts            # TypeScript types
├── workers/intakeSync.ts      # Sync logic
└── shared/contracts/          # Integration contract
```

## Deployment Strategy
1. **PWA Repo** (`pwa-sync-starter`) - Deploy to EC2
2. **Salesforce Repo** (`tgthrProgramManagement`) - Deploy to Salesforce
3. **Contract** ensures compatibility between both

This gives you a clean, stable MVP with offline-first PWA that creates complete client records in Salesforce.