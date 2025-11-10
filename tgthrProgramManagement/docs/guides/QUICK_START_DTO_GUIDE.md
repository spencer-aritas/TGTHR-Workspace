# Quick Start: DTO Ecosystem Guide

**Last Updated**: Phase 4 Complete  
**Status**: Production Ready ✅

## TL;DR - What's Available Now

### Apex DTOs (Use in TaskService)

```apex
// Create validation task (benefits)
TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
  disbursementId,     // WhatId
  encounterUuid,      // Unique ID
  notes,              // Description
  pos,                // Position code
  isCrisis,           // Boolean flag
  startUtc,           // Datetime
  endUtc,             // Datetime
  createdByUserId     // Owner
);
Id taskId = TaskService.createValidationTask(taskDto);

// Create follow-up task (outreach)
TaskService.FollowUpTaskDTO followUpDto = new TaskService.FollowUpTaskDTO(
  accountId,          // WhatId
  encounterUuid,      // Unique ID
  notes,              // Description
  pos,                // Position code
  isCrisis,           // Boolean flag
  startUtc,           // Datetime
  endUtc,             // Datetime
  createdByUserId     // Owner
);
Id followUpTaskId = TaskService.createFollowUpTask(followUpDto);

// Global class with 12 @AuraEnabled fields
PwaEncounter encounter = new PwaEncounter();
encounter.encounterUuid = 'enc-123';
encounter.personUuid = 'person-456';
encounter.firstName = 'John';
encounter.lastName = 'Doe';
encounter.isCrisis = false;
// ... set other fields
```

### TypeScript Contracts (Use in PWA)

```typescript
import { 
  TaskCreationRequest, 
  FollowUpTaskRequest,
  TaskCreationResponse,
  PwaEncounter,
  IngestEncounterRequest,
  validatePwaEncounter,
  isTaskCreationRequest
} from '@shared/contracts';

// Type-safe request
const taskRequest: TaskCreationRequest = {
  encounterUuid: 'enc-123',
  isCrisis: false,
  notes: 'Follow up needed',
  disbursementId: 'disburse-abc',
  createdByUserId: 'user-xyz'
};

// Type guard
if (isTaskCreationRequest(data)) {
  // TypeScript knows this is a TaskCreationRequest
}

// Validation
const { valid, errors } = validatePwaEncounter(encounterData);
if (!valid) {
  console.error('Encounter validation failed:', errors);
}
```

---

## Manual Validation

Check DTO sync at any time:

```bash
cd d:\Projects\TGTHR-Workspace\tgthrProgramManagement
npm run validate-dto-sync
```

**Expected output** (when all good):
```
✅ TaskCreationDTO <-> TaskContract.ts      PASS (8/8 fields)
✅ FollowUpTaskDTO <-> TaskContract.ts      PASS (8/8 fields)
✅ PwaEncounter <-> PwaEncounterContract.ts PASS (12/12 fields)

🟢 VALIDATION PASSED - All DTOs are in sync!
```

---

## Pre-commit Validation (Automatic)

When you commit, validation runs automatically:

```bash
git add .
git commit -m "Update DTO fields"

# Pre-commit hook runs automatically:
# 1. npm run validate-dto-sync ← Blocks if DTOs out of sync
# 2. lint-staged               ← Lints staged files
# 3. Commit proceeds if all pass
```

If validation fails:
```
🔴 VALIDATION FAILED - Please fix the above issues before committing

   ❌ Apex field "encounterUuid" missing in TypeScript
```

→ Fix the DTO mismatch, then commit again

---

## Where Things Are

| Component | Location | Type | Status |
|-----------|----------|------|--------|
| TaskCreationDTO | `force-app/main/default/classes/TaskService.cls` | Apex | ✅ Active |
| FollowUpTaskDTO | `force-app/main/default/classes/TaskService.cls` | Apex | ✅ Active |
| PwaEncounter | `force-app/main/default/classes/PwaEncounter.cls` | Apex (Global) | ✅ Active |
| TaskContract.ts | `pwa-sync-starter/shared/contracts/TaskContract.ts` | TypeScript | ✅ Active |
| PwaEncounterContract.ts | `pwa-sync-starter/shared/contracts/PwaEncounterContract.ts` | TypeScript | ✅ Active |
| Validator | `scripts/validate-dto-sync.js` | Node.js | ✅ Active |
| Docs (Mapping) | `DTO_MAPPING_REFERENCE.md` | Reference | ✅ Current |
| Docs (Phases) | `PHASE3_COMPLETION_SUMMARY.md` + `PHASE4_CI_CD_INTEGRATION.md` | Reference | ✅ Current |

---

## Field Reference

### TaskCreationDTO (Apex)
```
disbursementId  (String)  - Optional - WhatId for BenefitDisbursement
encounterUuid   (String)  - Required - Unique encounter identifier
notes           (String)  - Optional - Task description
pos             (String)  - Optional - Position/location code
isCrisis        (Boolean) - Required - Crisis indicator
startUtc        (Datetime)- Optional - Start timestamp (UTC)
endUtc          (Datetime)- Optional - End timestamp (UTC)
createdByUserId (String)  - Optional - Task owner User ID
```

### FollowUpTaskDTO (Apex)
```
accountId       (String)  - Required - WhatId for Account
encounterUuid   (String)  - Required - Unique encounter identifier
notes           (String)  - Optional - Task description
pos             (String)  - Optional - Position/location code
isCrisis        (Boolean) - Required - Crisis indicator
startUtc        (Datetime)- Optional - Start timestamp (UTC)
endUtc          (Datetime)- Optional - End timestamp (UTC)
createdByUserId (String)  - Optional - Task owner User ID
```

### PwaEncounter (Apex Global Class)
```
encounterUuid   (String)  - Required - Unique encounter ID
personUuid      (String)  - Required - Person reference
firstName       (String)  - Required - Person first name
lastName        (String)  - Required - Person last name
startUtc        (Datetime)- Optional - Encounter start (UTC)
endUtc          (Datetime)- Optional - Encounter end (UTC)
pos             (String)  - Optional - Point of service
isCrisis        (Boolean) - Required - Crisis flag
notes           (String)  - Optional - Encounter notes
location        (String)  - Optional - Location info
services        (String)  - Optional - Services provided
deviceId        (String)  - Optional - Device identifier
```

### TaskCreationRequest (TypeScript)
```
disbursementId  (string?)  - Optional - WhatId reference
encounterUuid   (string)   - Required - Unique ID
notes           (string?)  - Optional - Description
pos             (string?)  - Optional - Location code
isCrisis        (boolean)  - Required - Crisis flag
startUtc        (string?)  - Optional - ISO datetime
endUtc          (string?)  - Optional - ISO datetime
createdByUserId (string?)  - Optional - Owner User ID
```

### FollowUpTaskRequest (TypeScript)
```
accountId       (string)   - Required - WhatId
encounterUuid   (string)   - Required - Unique ID
notes           (string?)  - Optional - Description
pos             (string?)  - Optional - Location code
isCrisis        (boolean)  - Required - Crisis flag
startUtc        (string?)  - Optional - ISO datetime
endUtc          (string?)  - Optional - ISO datetime
createdByUserId (string?)  - Optional - Owner User ID
```

### PwaEncounter (TypeScript)
```
encounterUuid   (string)   - Required - Unique ID
personUuid      (string)   - Required - Person ref
firstName       (string)   - Required - First name
lastName        (string)   - Required - Last name
startUtc        (string?)  - Optional - ISO datetime
endUtc          (string?)  - Optional - ISO datetime
pos             (string?)  - Optional - Point of service
isCrisis        (boolean)  - Required - Crisis flag
notes           (string?)  - Optional - Notes
location        (string?)  - Optional - Location
services        (string?)  - Optional - Services
deviceId        (string?)  - Optional - Device ID
```

---

## Common Tasks

### I want to add a new field to TaskCreationDTO

1. **Add to Apex DTO** (`TaskService.cls`):
   ```apex
   @AuraEnabled public String newField;
   ```

2. **Add to TypeScript Contract** (`TaskContract.ts`):
   ```typescript
   export interface TaskCreationRequest {
     // ... existing fields
     newField?: string;  // Optional on client side
   }
   ```

3. **Run validation**:
   ```bash
   npm run validate-dto-sync
   ```
   → Should PASS if field matches

4. **Commit**:
   ```bash
   git add .
   git commit -m "Add newField to TaskCreationDTO"
   → Pre-commit validation runs automatically
   ```

### I want to use a DTO from PWA

1. Import the contract:
   ```typescript
   import { TaskCreationRequest } from '@shared/contracts';
   ```

2. Create typed object:
   ```typescript
   const request: TaskCreationRequest = {
     encounterUuid: 'enc-123',
     isCrisis: false,
     notes: 'Follow up'
   };
   ```

3. Send to Salesforce:
   ```typescript
   const response = await fetch('/services/apexrest/TaskService', {
     method: 'POST',
     body: JSON.stringify(request)
   });
   ```

### I want to verify DTOs are in sync

```bash
npm run validate-dto-sync
```

If all DTOs pass: ✅ All good!  
If any fail: ❌ Fix mismatches and retry

---

## Datetime Handling

**Apex** (stored internally):
```apex
Datetime now = Datetime.now();  // 2025-01-08 14:30:45 UTC
```

**TypeScript** (JSON transport):
```typescript
const isoString = "2025-01-08T14:30:45.000Z";  // ISO 8601
```

**Conversion** (REST API):
- **Request**: TypeScript sends ISO string → Apex parses to Datetime
- **Response**: Apex sends Datetime → TypeScript receives ISO string

Helper functions available in contracts:
```typescript
convertToISODatetime(date: Date): string;      // Date → "2025-01-08T14:30:45Z"
convertFromISODatetime(iso: string): Date;     // "2025-01-08T14:30:45Z" → Date
```

---

## Troubleshooting

### Validation fails: "Field X missing in TypeScript"

**Problem**: Added field to Apex DTO but forgot TypeScript

**Solution**:
1. Open `pwa-sync-starter/shared/contracts/TaskContract.ts`
2. Add field to matching interface (e.g., TaskCreationRequest)
3. Run `npm run validate-dto-sync` to verify
4. Commit

### Pre-commit blocks my commit

**Problem**: "Validation failed - Please fix the above issues"

**Solution**:
1. Check the error message
2. Open the validation script output
3. Add missing fields to Apex or TypeScript
4. Run `npm run validate-dto-sync` manually to verify
5. Try committing again

### I see optional/required mismatches in validation

**This is expected and OK!**
- Apex: Uses strict types (non-nullable by default)
- TypeScript: Uses optional `?` for client flexibility
- Validator correctly reports as **warnings**, not errors
- Your commit will still succeed

---

## Testing

### Run TaskService Tests

```bash
cd d:\Projects\TGTHR-Workspace\tgthrProgramManagement
sf apex run test --test-level RunLocalTests --synchronous
```

Expected: **10/10 TaskServiceTest PASSING** ✅

### Test Coverage

Tests cover:
- ✅ DTO creation (happy path)
- ✅ Default constructors
- ✅ Null handling
- ✅ Legacy overload compatibility
- ✅ DTO vs legacy equivalence
- ✅ Crisis flag handling
- ✅ Batch operations
- ✅ Field preservation

---

## Integration Examples

### REST Endpoint: Create Validation Task

**Request**:
```http
POST /services/apexrest/TaskService HTTP/1.1
Content-Type: application/json

{
  "disbursementId": "a0B6d000003LpIEAV",
  "encounterUuid": "enc-2025-01-08-001",
  "notes": "Intake forms incomplete",
  "pos": "27",
  "isCrisis": false,
  "startUtc": "2025-01-08T14:30:00Z",
  "endUtc": "2025-01-08T15:45:00Z",
  "createdByUserId": "0056d000003JRDCAA4"
}
```

**Response** (success):
```json
{
  "success": true,
  "taskId": "00T6d000003MpAEAV",
  "message": "Task created successfully"
}
```

**Response** (error):
```json
{
  "success": false,
  "taskId": null,
  "errorCode": "INVALID_DTO",
  "message": "encounterUuid cannot be null"
}
```

---

## Need Help?

1. **Check the docs**:
   - `DTO_MAPPING_REFERENCE.md` - REST examples, field mappings
   - `PHASE3_COMPLETION_SUMMARY.md` - Architecture, integration
   - `PHASE4_CI_CD_INTEGRATION.md` - Validator details

2. **Run validation**:
   ```bash
   npm run validate-dto-sync
   ```

3. **Review test code**:
   - `force-app/main/default/classes/TaskServiceTest.cls` - Usage examples

4. **Check TypeScript contracts**:
   - `pwa-sync-starter/shared/contracts/TaskContract.ts` - Type definitions
   - `pwa-sync-starter/shared/contracts/PwaEncounterContract.ts` - Encounter types

---

## Summary

✅ **Apex DTOs** - 2 classes (TaskCreationDTO, FollowUpTaskDTO) in TaskService.cls  
✅ **TypeScript Contracts** - 2 interfaces in separate .ts files  
✅ **Global Class** - PwaEncounter with 12 @AuraEnabled fields  
✅ **Validation** - Automated pre-commit DTO sync checking  
✅ **Tests** - 10/10 TaskServiceTest passing  
✅ **Deployments** - 2/2 succeeded, all live  

**Ready to use! Add types to your PWA code now.** 🚀
