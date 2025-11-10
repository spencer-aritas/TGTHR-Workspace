# Developer Quick Reference

**Location**: `docs/guides/`  
**Audience**: Frontend developers, backend developers, DevOps  
**Purpose**: Fast lookup for common tasks

## TL;DR - What's Available

### Apex (Backend)
✅ Use `TaskService.createValidationTask(TaskCreationDTO)`  
✅ Use `TaskService.createFollowUpTask(FollowUpTaskDTO)`  
✅ Use global `PwaEncounter` class for REST responses  

### TypeScript (Frontend)
✅ Import: `import { TaskCreationRequest } from '@shared/contracts';`  
✅ Use type guards: `if (isTaskCreationRequest(data)) { ... }`  
✅ Validate: `const { valid, errors } = validatePwaEncounter(data);`  

### DevOps (Automation)
✅ Run: `npm run validate-dto-sync`  
✅ Pre-commit: Automatic on every commit  
✅ Exit code 0: Success, code 1: Failure  

---

## Common Tasks

### I want to create a validation task (Backend)

```apex
// Create DTO
TaskService.TaskCreationDTO dto = new TaskService.TaskCreationDTO(
  disbursementId,    // WhatId
  encounterUuid,     // Unique ID
  notes,             // Description
  pos,               // Position code
  isCrisis,          // Boolean
  startUtc,          // Datetime
  endUtc,            // Datetime
  createdByUserId    // Owner
);

// Create task
Id taskId = TaskService.createValidationTask(dto);
```

### I want to send task data from PWA (Frontend)

```typescript
import { TaskCreationRequest, TaskServiceContract } from '@shared/contracts';

// Create typed request
const request: TaskCreationRequest = {
  encounterUuid: 'enc-123',
  isCrisis: false,
  notes: 'Follow up needed',
  disbursementId: 'disburse-abc'
};

// Send to Salesforce
const response = await fetch('/services/apexrest/TaskService', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(request)
});

const result = await response.json();
console.log(result.taskId);
```

### I want to validate data (Frontend)

```typescript
import { PwaEncounter, validatePwaEncounter } from '@shared/contracts';

const encounterData: any = { /* ... */ };

const { valid, errors } = validatePwaEncounter(encounterData);
if (!valid) {
  console.error('Validation failed:', errors);
  // Handle error
}
```

### I want to check DTOs are in sync (DevOps)

```bash
cd d:\Projects\TGTHR-Workspace\tgthrProgramManagement
npm run validate-dto-sync

# Expected: All 3 DTOs PASS
```

### I want to add a new field to a DTO

1. Update Apex DTO file
2. Update TypeScript contract file
3. Run `npm run validate-dto-sync` to verify
4. Commit (pre-commit validation runs automatically)

### I want to understand the architecture

→ Read: `docs/architecture/DTO_ECOSYSTEM.md` (10 min)

### I want REST API examples

→ Read: `docs/api/DTO_REFERENCE.md` (5 min)

### I want to set up validation

→ Read: `docs/setup/DTO_VALIDATION.md` (5 min)

---

## Field Reference

### TaskCreationDTO
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| disbursementId | String | No | WhatId for BenefitDisbursement |
| encounterUuid | String | Yes | Unique encounter ID |
| notes | String | No | Task description |
| pos | String | No | Position/location code |
| isCrisis | Boolean | Yes | Crisis indicator |
| startUtc | Datetime | No | Start timestamp (UTC) |
| endUtc | Datetime | No | End timestamp (UTC) |
| createdByUserId | String | No | Task owner |

### FollowUpTaskDTO
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| accountId | String | Yes | WhatId for Account |
| encounterUuid | String | Yes | Unique encounter ID |
| notes | String | No | Task description |
| pos | String | No | Position/location code |
| isCrisis | Boolean | Yes | Crisis indicator |
| startUtc | Datetime | No | Start timestamp (UTC) |
| endUtc | Datetime | No | End timestamp (UTC) |
| createdByUserId | String | No | Task owner |

### PwaEncounter
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| encounterUuid | String | Yes | Unique encounter ID |
| personUuid | String | Yes | Person reference |
| firstName | String | Yes | First name |
| lastName | String | Yes | Last name |
| startUtc | Datetime | No | Start (UTC) |
| endUtc | Datetime | No | End (UTC) |
| pos | String | No | Point of service |
| isCrisis | Boolean | Yes | Crisis flag |
| notes | String | No | Notes |
| location | String | No | Location |
| services | String | No | Services provided |
| deviceId | String | No | Device identifier |

---

## Datetime Handling

### Apex to TypeScript
```
Apex: Datetime.now()              → JSON string "2025-01-08T14:30:45Z"
TypeScript: new Date(iso_string)  → Date object
```

### TypeScript to Apex
```
TypeScript: date.toISOString()           → "2025-01-08T14:30:45.000Z"
Apex: Datetime.valueOfGmt(iso_string)   → Datetime object
```

### Helper Functions

**TypeScript**
```typescript
convertToISODatetime(date)      // Date → ISO string
convertFromISODatetime(iso)     // ISO string → Date
```

**Apex**
```apex
dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')  // Datetime → ISO string
Datetime.valueOfGmt('2025-01-08T14:30:45Z')  // ISO string → Datetime
```

---

## Import Statements

### All Available Exports

```typescript
import {
  // TaskContract.ts
  TaskCreationRequest,
  FollowUpTaskRequest,
  TaskCreationResponse,
  TaskDetail,
  TaskServiceContract,
  isTaskCreationRequest,
  isFollowUpTaskRequest,
  convertToISODatetime,
  convertFromISODatetime,

  // PwaEncounterContract.ts
  PwaEncounter,
  PwaEncounterExtended,
  IngestEncounterRequest,
  IngestEncounterResponse,
  EncounterServiceContract,
  isPwaEncounter,
  isIngestEncounterRequest,
  validatePwaEncounter,
  isValidISODatetime,
  encounterToIngestRequest,
  enrichEncounterWithMetadata
} from '@shared/contracts';
```

---

## Validation Patterns

### Type Guard Pattern

```typescript
function processRequest(data: any) {
  if (isTaskCreationRequest(data)) {
    // TypeScript knows data is TaskCreationRequest
    console.log(data.encounterUuid);  // ✅ No error
  }
}
```

### Validator Pattern

```typescript
const result = validatePwaEncounter(data);
if (result.valid) {
  // Safe to use data
} else {
  console.error('Errors:', result.errors);
}
```

### Optional Check Pattern

```typescript
// Check if optional field exists
if (data.startUtc) {
  const startDate = convertFromISODatetime(data.startUtc);
  console.log(startDate);
}
```

---

## REST API Quick Reference

### Create Validation Task
```
POST /services/apexrest/TaskService
Body: TaskCreationRequest (JSON)
Response: { success, taskId, message }
```

### Ingest Encounter
```
POST /services/apexrest/ProgramEnrollmentService
Body: IngestEncounterRequest (JSON)
Response: { success, encounterId, accountId, taskIds }
```

### Status Codes
- `200`: Success
- `400`: Invalid input (bad DTO)
- `401`: Not authenticated
- `403`: Not authorized
- `500`: Server error

---

## Troubleshooting

### TypeScript Error: Property not found
**Cause**: Field name typo or not in interface  
**Fix**: Check field name spelling (case-sensitive)

### Pre-commit Blocks Commit
**Cause**: Apex and TypeScript DTO fields don't match  
**Fix**: Run `npm run validate-dto-sync` to see which fields differ

### REST Request Returns Error
**Cause**: DTO validation failed  
**Fix**: Check required fields in request, verify types

### Type Error in IDE
**Cause**: Wrong import or TypeScript file not updated  
**Fix**: Verify import path, check `pwa-sync-starter/shared/contracts/`

---

## File Locations

| Component | File |
|-----------|------|
| Apex DTOs | `force-app/main/default/classes/TaskService.cls` |
| PwaEncounter | `force-app/main/default/classes/PwaEncounter.cls` |
| TaskContract | `pwa-sync-starter/shared/contracts/TaskContract.ts` |
| PwaEncounterContract | `pwa-sync-starter/shared/contracts/PwaEncounterContract.ts` |
| Validator | `scripts/validate-dto-sync.js` |
| Documentation | `docs/` (this folder) |

---

## Learn More

**Architecture**: `docs/architecture/DTO_ECOSYSTEM.md`  
**API Docs**: `docs/api/DTO_REFERENCE.md`  
**Setup Guide**: `docs/setup/DTO_VALIDATION.md`  
**Decisions**: `docs/decisions/ADR-0001-DTO-CONSOLIDATION-STRATEGY.md`  

---

*Quick Reference v1.0 | 2025-01 | Complete & Ready to Use*
