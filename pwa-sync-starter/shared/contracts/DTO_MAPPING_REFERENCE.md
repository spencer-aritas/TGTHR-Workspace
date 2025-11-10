# TypeScript-Apex DTO Mapping Reference

**Date**: November 9, 2025  
**Status**: ✅ COMPLETE  
**Scope**: TaskContract.ts, PwaEncounterContract.ts mapped to Apex DTOs

---

## Overview

This document maps TypeScript contracts (PWA frontend) to Apex DTOs (Salesforce backend), ensuring consistent data models across the TGTHR platform.

### File Structure
```
Apex (Salesforce Backend)          TypeScript (PWA Frontend)
└── TaskService.cls                 └── TaskContract.ts
    ├── TaskCreationDTO              ├── TaskCreationRequest
    └── FollowUpTaskDTO              └── FollowUpTaskRequest
└── PwaEncounter.cls                 └── PwaEncounterContract.ts
    └── PwaEncounter                 └── PwaEncounter
└── ProgramEnrollmentService.cls     └── PwaEncounterContract.ts
    └── REST endpoint                └── EncounterServiceContract
```

---

## 1. Task Contracts

### 1A. TaskCreationDTO ↔ TaskCreationRequest

**Purpose**: Create validation tasks for benefit disbursements

**Apex (Source)**:
```apex
// TaskService.cls
public class TaskCreationDTO {
    @AuraEnabled public Id disbursementId;
    @AuraEnabled public String encounterUuid;
    @AuraEnabled public String notes;
    @AuraEnabled public String pos;
    @AuraEnabled public Boolean isCrisis;
    @AuraEnabled public Datetime startUtc;
    @AuraEnabled public Datetime endUtc;
    @AuraEnabled public String createdByUserId;
}
```

**TypeScript (Consumer)**:
```typescript
// TaskContract.ts
export interface TaskCreationRequest {
  disbursementId?: string;        // Optional (Apex allows null)
  encounterUuid: string;          // Required
  notes?: string;
  pos?: string;
  isCrisis: boolean;              // Required
  startUtc?: string;              // ISO datetime string
  endUtc?: string;                // ISO datetime string
  createdByUserId?: string;
}
```

**Field Mapping**:
| Apex | Type | TypeScript | Type | Notes |
|------|------|-----------|------|-------|
| disbursementId | Id | disbursementId | string | Optional, WhatId field |
| encounterUuid | String | encounterUuid | string | Required, CallObject field |
| notes | String | notes | string | Task description |
| pos | String | pos | string | Position code (default "27") |
| isCrisis | Boolean | isCrisis | boolean | Crisis indicator |
| startUtc | Datetime | startUtc | string | ISO datetime format |
| endUtc | Datetime | endUtc | string | ISO datetime format |
| createdByUserId | String | createdByUserId | string | Task owner (User ID) |

**Datetime Format Conversion**:
- **Apex**: Datetime objects (e.g., Datetime.now())
- **TypeScript**: ISO 8601 strings (e.g., "2025-11-08T14:30:00Z")
- **Conversion Helper**: `convertToISODatetime()` / `convertFromISODatetime()`

**REST Flow**:
```
PWA (TypeScript)
  ↓ JSON serialize TaskCreationRequest
→ POST /services/apexrest/TaskService
  ↓ JSON deserialize to TaskCreationDTO
Apex (Salesforce)
  ↓ Create Task record
  ↓ Return TaskCreationResponse (success/error)
→ PWA (TypeScript)
  ↓ JSON deserialize TaskCreationResponse
```

---

### 1B. FollowUpTaskDTO ↔ FollowUpTaskRequest

**Purpose**: Create follow-up tasks for outreach encounters

**Apex (Source)**:
```apex
// TaskService.cls
public class FollowUpTaskDTO {
    @AuraEnabled public String accountId;
    @AuraEnabled public String encounterUuid;
    @AuraEnabled public String notes;
    @AuraEnabled public String pos;
    @AuraEnabled public Boolean isCrisis;
    @AuraEnabled public Datetime startUtc;
    @AuraEnabled public Datetime endUtc;
    @AuraEnabled public String createdByUserId;
}
```

**TypeScript (Consumer)**:
```typescript
// TaskContract.ts
export interface FollowUpTaskRequest {
  accountId: string;              // Required: WhatId
  encounterUuid: string;          // Required: CallObject
  notes?: string;
  pos?: string;
  isCrisis: boolean;              // Required
  startUtc?: string;              // ISO datetime string
  endUtc?: string;                // ISO datetime string
  createdByUserId?: string;
}
```

**Field Mapping**:
| Apex | Type | TypeScript | Type | Notes |
|------|------|-----------|------|-------|
| accountId | String | accountId | string | Required, WhatId field |
| encounterUuid | String | encounterUuid | string | Required, CallObject field |
| notes | String | notes | string | Task description |
| pos | String | pos | string | Position code |
| isCrisis | Boolean | isCrisis | boolean | Required |
| startUtc | Datetime | startUtc | string | ISO datetime |
| endUtc | Datetime | endUtc | string | ISO datetime |
| createdByUserId | String | createdByUserId | string | Optional task owner |

**Difference from TaskCreationDTO**:
- `accountId` instead of `disbursementId` (what the task relates to)
- Both serve the same pattern (7-8 parameters → DTO)
- Both create Task records with different purposes

---

## 2. Encounter Contracts

### 2A. PwaEncounter ↔ PwaEncounter (TypeScript)

**Purpose**: Model encounter data captured by mobile app

**Apex (Source)**:
```apex
// PwaEncounter.cls
global class PwaEncounter {
    @AuraEnabled public String encounterUuid;
    @AuraEnabled public String personUuid;
    @AuraEnabled public String firstName;
    @AuraEnabled public String lastName;
    @AuraEnabled public Datetime startUtc;
    @AuraEnabled public Datetime endUtc;
    @AuraEnabled public String pos;
    @AuraEnabled public Boolean isCrisis;
    @AuraEnabled public String notes;
    @AuraEnabled public String location;
    @AuraEnabled public String services;
    @AuraEnabled public String deviceId;
}
```

**TypeScript (Consumer)**:
```typescript
// PwaEncounterContract.ts
export interface PwaEncounter {
  encounterUuid: string;          // Required
  personUuid: string;             // Required
  firstName: string;              // Required
  lastName: string;               // Required
  startUtc?: string;              // ISO datetime
  endUtc?: string;                // ISO datetime
  pos?: string;
  isCrisis: boolean;              // Required
  notes?: string;
  location?: string;
  services?: string;
  deviceId?: string;
}
```

**Field Mapping**:
| Apex | Type | TypeScript | Type | Notes |
|------|------|-----------|------|-------|
| encounterUuid | String | encounterUuid | string | Unique encounter ID, CallObject |
| personUuid | String | personUuid | string | Person Account UUID__c |
| firstName | String | firstName | string | First name |
| lastName | String | lastName | string | Last name |
| startUtc | Datetime | startUtc | string | ISO datetime |
| endUtc | Datetime | endUtc | string | ISO datetime |
| pos | String | pos | string | Position/location code |
| isCrisis | Boolean | isCrisis | boolean | Crisis indicator |
| notes | String | notes | string | Encounter notes |
| location | String | location | string | Physical address |
| services | String | services | string | Services provided |
| deviceId | String | deviceId | string | Mobile device ID |

**Key Features**:
- ✅ Full 12-field model (deduplication complete)
- ✅ All fields @AuraEnabled in Apex
- ✅ Datetime fields → ISO strings in TypeScript
- ✅ Extended version available: `PwaEncounterExtended` (adds metadata)

---

### 2B. IngestEncounterRequest ↔ REST Endpoint

**Purpose**: Payload sent to ProgramEnrollmentService.ingestEncounter() REST endpoint

**Apex Endpoint**:
```apex
// ProgramEnrollmentService.cls
@RestResource(urlMapping='/ProgramEnrollmentService/*')
global static String ingestEncounter() {
    RestRequest req = RestContext.request;
    String requestBody = req.requestBody.toString();
    Map<String, Object> rawData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
    PwaEncounter e = parseEncounter(rawData);
    // ... create Account, ProgramEnrollment, Task, Disbursements
}
```

**TypeScript Request**:
```typescript
export interface IngestEncounterRequest {
  email?: string;
  phone?: string;
  birthdate?: string;             // ISO date (YYYY-MM-DD)
  createdByUserId?: string;
  programId?: string;
  programName?: string;
  // Plus all PwaEncounter fields
  encounterUuid: string;
  personUuid: string;
  firstName: string;
  lastName: string;
  startUtc?: string;
  endUtc?: string;
  pos?: string;
  isCrisis: boolean;
  notes?: string;
  location?: string;
  services?: string;
  deviceId?: string;
}
```

**API Call Flow**:
```
PWA Frontend (TypeScript)
  ↓ Build IngestEncounterRequest
  ↓ JSON.stringify()
→ POST /services/apexrest/ProgramEnrollmentService
  ↓ Salesforce routes to ProgramEnrollmentService.ingestEncounter()
  ↓ Parse JSON into Map<String, Object>
  ↓ deserialize to PwaEncounter
  ↓ Extract optional fields (email, phone, createdByUserId, etc.)
  ↓ Create/update Account, ProgramEnrollment, Task, Disbursements
  ↓ JSON serialize IngestEncounterResponse
→ PWA Frontend (TypeScript)
  ↓ Receive IngestEncounterResponse
  ↓ JSON.parse()
  ↓ Use response IDs for UI updates
```

**REST URL**:
```
POST https://[salesforce-instance]/services/apexrest/ProgramEnrollmentService

Headers:
  Authorization: Bearer [access_token]
  Content-Type: application/json

Body:
{
  "encounterUuid": "enc-2025-001",
  "personUuid": "person-456",
  "firstName": "John",
  "lastName": "Doe",
  "startUtc": "2025-11-08T14:30:00Z",
  "endUtc": "2025-11-08T15:00:00Z",
  "pos": "27",
  "isCrisis": false,
  "notes": "Intake assessment complete",
  "email": "john@example.com",
  "createdByUserId": "005XXXXXXXXXXXXXXX"
}

Response:
{
  "success": true,
  "encounterId": "enc-2025-001",
  "programEnrollmentId": "a01XXXXXXXXXXXXXXX",
  "accountId": "001XXXXXXXXXXXXXXX",
  "message": "Encounter ingested successfully"
}
```

---

## 3. DTO Conversion Patterns

### 3.1 JSON Serialization (PWA → Apex)

**TypeScript Code**:
```typescript
import { TaskCreationRequest, convertToISODatetime } from '@shared/contracts';

const taskRequest: TaskCreationRequest = {
  disbursementId: 'a04XXXXXXXXXXXXXXX',
  encounterUuid: 'enc-2025-001',
  notes: 'Validation required',
  pos: '27',
  isCrisis: false,
  startUtc: convertToISODatetime(new Date('2025-11-08T14:30:00')),
  endUtc: convertToISODatetime(new Date('2025-11-08T15:00:00')),
  createdByUserId: '005XXXXXXXXXXXXXXX',
};

const jsonBody = JSON.stringify(taskRequest);
// Result: {"disbursementId":"a04...","encounterUuid":"enc-2025-001",...}
```

**Apex Deserialization**:
```apex
Map<String, Object> rawData = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
TaskService.TaskCreationDTO dto = new TaskService.TaskCreationDTO();
dto.disbursementId = (Id) rawData.get('disbursementId');
dto.encounterUuid = (String) rawData.get('encounterUuid');
dto.notes = (String) rawData.get('notes');
dto.pos = (String) rawData.get('pos');
dto.isCrisis = (Boolean) rawData.get('isCrisis');
// For Datetime fields, parse from ISO string:
String startStr = (String) rawData.get('startUtc');
if (startStr != null) {
    dto.startUtc = Datetime.valueOf(startStr.replace('T', ' ').replace('Z', ''));
}
```

---

### 3.2 JSON Deserialization (Apex → PWA)

**Apex Response**:
```apex
public class TaskCreationResponse {
    public Boolean success;
    public String taskId;
    public String message;
    public String errorCode;
}

TaskCreationResponse response = new TaskCreationResponse();
response.success = true;
response.taskId = createdTaskId;
response.message = 'Task created successfully';

String jsonResponse = JSON.serialize(response);
// Result: {"success":true,"taskId":"00TXXXXXXXXXXXXXXX",...}
```

**TypeScript Consumption**:
```typescript
import { TaskCreationResponse } from '@shared/contracts';

const response: TaskCreationResponse = JSON.parse(jsonResponse);
if (response.success) {
  console.log(`Task created: ${response.taskId}`);
} else {
  console.error(`Error: ${response.message}`);
}
```

---

## 4. Validation & Type Safety

### 4.1 TypeScript Type Guards

**Available Type Guards**:
```typescript
// TaskContract.ts
export function isTaskCreationRequest(obj: any): obj is TaskCreationRequest
export function isFollowUpTaskRequest(obj: any): obj is FollowUpTaskRequest

// PwaEncounterContract.ts
export function isPwaEncounter(obj: any): obj is PwaEncounter
export function isIngestEncounterRequest(obj: any): obj is IngestEncounterRequest
export function validatePwaEncounter(encounter: any): { valid: boolean; errors: string[] }
```

**Usage Example**:
```typescript
import { isPwaEncounter, validatePwaEncounter } from '@shared/contracts';

const data = JSON.parse(apiResponse);
if (isPwaEncounter(data)) {
  const validation = validatePwaEncounter(data);
  if (validation.valid) {
    // Safe to use data
  } else {
    console.error('Validation errors:', validation.errors);
  }
}
```

### 4.2 Apex Validation

**No explicit type guards in Apex (dynamic language)**:
- Defensive casting: `(String) rawData.get('fieldName')`
- Null checks before usage
- Try/catch for parsing errors

---

## 5. Backward Compatibility

### Legacy Support

**Apex (Backward Compatible)**:
- TaskService maintains legacy method overloads (7-param, 8-param)
- Can accept both old direct calls and new DTO calls
- Gradual migration path

**TypeScript (Contracts Only)**:
- Contracts represent current/future API shape
- Legacy implementations handled on Apex side
- PWA always uses current REST API version

---

## 6. Extension Points

### Adding New Fields

**When adding fields to Apex DTO**:
1. Add @AuraEnabled field to Apex class
2. Create new TypeScript interface version (v2) or extend existing
3. Add field to REST request/response type
4. Update type guards and validators
5. Update this mapping document

**Example**:
```apex
// Apex - New field
public class TaskCreationDTO {
    // ... existing fields
    @AuraEnabled public String customField;
}
```

```typescript
// TypeScript - Extend interface
export interface TaskCreationRequest {
    // ... existing fields
    customField?: string;  // Make optional for graceful degradation
}
```

---

## 7. Testing Contracts

### Unit Test Pattern

```typescript
import { isTaskCreationRequest, TaskCreationRequest } from '@shared/contracts';

describe('TaskContract', () => {
  it('validates TaskCreationRequest', () => {
    const valid: TaskCreationRequest = {
      encounterUuid: 'enc-001',
      isCrisis: false,
    };
    expect(isTaskCreationRequest(valid)).toBe(true);
  });

  it('rejects invalid TaskCreationRequest', () => {
    const invalid = { encounterUuid: 'enc-001' }; // Missing isCrisis
    expect(isTaskCreationRequest(invalid)).toBe(false);
  });
});
```

---

## 8. Documentation Links

- **Apex DTOs**: See DTOs.md for Apex specifications
- **DTO_REFACTORING_PLAN.md**: Why DTOs matter
- **DTO_IMPLEMENTATION_SUMMARY.md**: Phase 1-2 progress
- **PHASE2_COMPLETION_SUMMARY.md**: DTO deduplication & migration

---

## 9. Contact & Maintenance

**TypeScript Contracts**:
- Location: `pwa-sync-starter/shared/contracts/`
- Owned by: PWA Frontend Team
- Review: API changes reviewed for backward compatibility

**Apex DTOs**:
- Location: `force-app/main/default/classes/`
- Owned by: Salesforce Backend Team
- Review: DTO changes require TypeScript contract updates

**Sync Requirements**:
- ✅ Any Apex DTO change → update TypeScript contract
- ✅ Type names & field names must match (for documentation)
- ✅ Datetime conversion logic documented
- ✅ Validators & type guards kept in sync

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-09 | Initial: TaskContract.ts, PwaEncounterContract.ts created |
| TBD | Future | Additional DTOs mapped (DisburseRequest, etc.) |

