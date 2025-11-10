# DTO & REST API Reference

**Location**: `docs/api/`  
**Status**: Complete  
**Last Updated**: 2025-01

## DTO Mappings

### TaskCreationDTO ↔ TaskCreationRequest

**Apex (Backend)**
```apex
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

**TypeScript (Frontend)**
```typescript
export interface TaskCreationRequest {
  disbursementId?: string;        // Optional WhatId
  encounterUuid: string;          // Required
  notes?: string;                 // Optional
  pos?: string;                   // Optional
  isCrisis: boolean;              // Required
  startUtc?: string;              // ISO datetime string
  endUtc?: string;                // ISO datetime string
  createdByUserId?: string;       // Optional
}
```

### FollowUpTaskDTO ↔ FollowUpTaskRequest

**Apex (Backend)**
```apex
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

**TypeScript (Frontend)**
```typescript
export interface FollowUpTaskRequest {
  accountId: string;              // Required WhatId
  encounterUuid: string;          // Required
  notes?: string;                 // Optional
  pos?: string;                   // Optional
  isCrisis: boolean;              // Required
  startUtc?: string;              // ISO datetime string
  endUtc?: string;                // ISO datetime string
  createdByUserId?: string;       // Optional
}
```

### PwaEncounter

**Apex (Backend)**
```apex
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

**TypeScript (Frontend)**
```typescript
export interface PwaEncounter {
  encounterUuid: string;          // Required
  personUuid: string;             // Required
  firstName: string;              // Required
  lastName: string;               // Required
  startUtc?: string;              // ISO datetime
  endUtc?: string;                // ISO datetime
  pos?: string;                   // Optional
  isCrisis: boolean;              // Required
  notes?: string;                 // Optional
  location?: string;              // Optional
  services?: string;              // Optional
  deviceId?: string;              // Optional
}
```

## REST Endpoints

### POST /services/apexrest/ProgramEnrollmentService

**Purpose**: Ingest encounter data and create tasks

**Request**
```json
{
  "encounterUuid": "enc-2025-01-08-001",
  "personUuid": "person-456",
  "firstName": "John",
  "lastName": "Doe",
  "startUtc": "2025-01-08T14:30:00Z",
  "endUtc": "2025-01-08T15:45:00Z",
  "pos": "27",
  "isCrisis": false,
  "notes": "Intake follow-up needed",
  "location": "Clinic A",
  "services": "Case management",
  "deviceId": "device-xyz"
}
```

**Response** (Success)
```json
{
  "success": true,
  "encounterId": "a0C6d000003LpAEAV",
  "programEnrollmentId": "a0D6d000003LpBEAV",
  "accountId": "001xx000003DGbEAAW",
  "taskIds": ["00T6d000003MpAEAV"],
  "message": "Encounter and tasks created successfully"
}
```

**Response** (Error)
```json
{
  "success": false,
  "errorCode": "INVALID_ENCOUNTER",
  "message": "encounterUuid cannot be null",
  "details": {
    "field": "encounterUuid",
    "reason": "Required field missing"
  }
}
```

### POST /services/apexrest/TaskService

**Purpose**: Create validation task for benefit disbursement

**Request**
```json
{
  "disbursementId": "a0B6d000003LpIEAV",
  "encounterUuid": "enc-2025-01-08-001",
  "notes": "Validate billing coding",
  "pos": "27",
  "isCrisis": false,
  "startUtc": "2025-01-08T14:30:00Z",
  "endUtc": "2025-01-08T15:45:00Z",
  "createdByUserId": "0056d000003JRDCAA4"
}
```

**Response** (Success)
```json
{
  "success": true,
  "taskId": "00T6d000003MpAEAV",
  "message": "Task created successfully"
}
```

**Response** (Error)
```json
{
  "success": false,
  "errorCode": "INVALID_DTO",
  "message": "encounterUuid cannot be null"
}
```

## Datetime Handling

### Format Conversion

**Apex → TypeScript**
```
Apex Datetime:   2025-01-08 14:30:45 UTC
↓ [JSON serialization]
ISO 8601 String: "2025-01-08T14:30:45.000Z"
↓ [HTTP transmission]
TypeScript Date: new Date("2025-01-08T14:30:45.000Z")
```

**TypeScript → Apex**
```
TypeScript Date:   new Date("2025-01-08T14:30:45.000Z")
↓ [JSON serialization]
ISO 8601 String:  "2025-01-08T14:30:45Z"
↓ [HTTP transmission]
Apex Datetime:    Datetime.valueOfGmt('2025-01-08T14:30:45Z')
```

### Helper Functions

**TypeScript**
```typescript
// Convert Date to ISO string
function convertToISODatetime(date: Date): string {
  return date.toISOString();  // "2025-01-08T14:30:45.000Z"
}

// Convert ISO string to Date
function convertFromISODatetime(iso: string): Date {
  return new Date(iso);
}
```

**Apex**
```apex
// Convert Datetime to ISO string
String isoString = dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

// Convert ISO string to Datetime
Datetime dt = Datetime.valueOfGmt('2025-01-08T14:30:45Z');
```

## Type Guards & Validators

### TypeScript

```typescript
// Type guard: Is this a TaskCreationRequest?
export function isTaskCreationRequest(obj: any): obj is TaskCreationRequest {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.encounterUuid === 'string' &&
    typeof obj.isCrisis === 'boolean'
  );
}

// Validator: Check PwaEncounter validity
export function validatePwaEncounter(encounter: any) {
  const errors: string[] = [];
  if (!encounter.encounterUuid) errors.push('encounterUuid required');
  if (!encounter.personUuid) errors.push('personUuid required');
  if (typeof encounter.isCrisis !== 'boolean') errors.push('isCrisis must be boolean');
  return { valid: errors.length === 0, errors };
}

// Usage
const { valid, errors } = validatePwaEncounter(data);
if (!valid) console.error('Validation failed:', errors);
```

## Import Examples

**Using in PWA**
```typescript
import {
  TaskCreationRequest,
  FollowUpTaskRequest,
  TaskCreationResponse,
  PwaEncounter,
  IngestEncounterRequest,
  validatePwaEncounter,
  isTaskCreationRequest,
  convertToISODatetime,
  convertFromISODatetime
} from '@shared/contracts';

// Create a request
const request: TaskCreationRequest = {
  encounterUuid: 'enc-123',
  isCrisis: false,
  notes: 'Follow up'
};

// Validate before sending
if (isTaskCreationRequest(request)) {
  // TypeScript knows this is a TaskCreationRequest
  const response = await fetch('/services/apexrest/TaskService', {
    method: 'POST',
    body: JSON.stringify(request)
  });
}
```

## Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 OK | Success | Task created, encounter saved |
| 400 Bad Request | Invalid input | Missing required field |
| 401 Unauthorized | Authentication failed | Invalid session |
| 403 Forbidden | Permission denied | User lacks DTO permissions |
| 404 Not Found | Resource missing | Disbursement ID not found |
| 500 Server Error | Backend issue | Database error |

## Error Handling

**Apex throws on DTO null**
```apex
if (dto == null) {
  throw new IllegalArgumentException('TaskCreationDTO cannot be null');
}
```

**TypeScript should check type guard**
```typescript
if (!isTaskCreationRequest(data)) {
  throw new Error('Invalid TaskCreationRequest structure');
}
```

## Field Validation Rules

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| encounterUuid | String | Yes | Non-empty, unique per encounter |
| personUuid | String | Yes | Valid person reference |
| isCrisis | Boolean | Yes | true or false |
| startUtc | String | No | ISO 8601 format if present |
| endUtc | String | No | ISO 8601 format if present, > startUtc |
| notes | String | No | Max 2000 chars |
| pos | String | No | Valid position code |
| disbursementId | String | No | Valid Salesforce ID if present |
| accountId | String | Yes | Valid Salesforce Account ID |

## Rate Limiting

Currently: **No rate limits applied**  
Future: Implement per-user or per-org throttling if needed

## Versioning Strategy

Current: **v1.0** (implicit, no version in URL)

Future versions would use:
- `/services/apexrest/v2/ProgramEnrollmentService` (URL versioning)
- Or API-Version header (Salesforce pattern)

---

*API Reference v1.0 | 2025-01 | Complete & Validated*
