# Salesforce DTOs Registry & Documentation

## Overview
This document provides a centralized registry of all Data Transfer Objects (DTOs) used in the TGTHR Salesforce environment. DTOs facilitate clean separation between Apex services and Lightning Web Components, reduce method complexity, and provide a versioning strategy for API changes.

---

## Master DTO List

| DTO Name | File | Type | Status | Purpose | LWC-Facing |
|----------|------|------|--------|---------|-----------|
| `TaskCreationDTO` | TaskService.cls | Public Inner | ✅ NEW | Consolidate task creation parameters | Yes |
| `DisburseRequest` | BenefitDisbursementService.cls | Public Inner | ✅ Active | Consolidate benefit disbursement request | Yes |
| `DisburseResult` | BenefitDisbursementService.cls | Public Inner | ✅ Active | Benefit disbursement outcome | Yes |
| `Option` | BenefitDisbursementService.cls | Public Inner | ✅ Active | Label/value pair for dropdowns | Yes |
| `EnsureResult` | ProgramEnrollmentService.cls | Global Inner | ✅ Active | Enrollment creation outcome | Yes |
| `PwaEncounter` | PwaEncounter.cls | Global | ✅ Active | PWA encounter data model | Yes |
| `ThemeDTO` | ProgramThemeService.cls | Public Inner | ✅ Active | Program theme configuration | Yes |
| `SSRSRequest` | SSRSAssessmentHandler.cls | Global Inner | ✅ Active | SSRS assessment submission | Yes |
| `SSRSResponse` | SSRSAssessmentHandler.cls | Global Inner | ✅ Active | SSRS question/answer | Yes |
| `AssessmentData` | SSRSAssessmentHandler.cls | Global Inner | ✅ Active | SSRS assessment fields (~40+) | Yes |

---

## DTO Specifications

### 1. TaskCreationDTO
**Location**: `TaskService.cls` (inner public class)  
**Status**: ✅ NEW (replaces 8-parameter method)  
**Purpose**: Consolidate all task-related parameters for validation and follow-up tasks

**Fields**:
```apex
@AuraEnabled public Id disbursementId;       // WhatId: relates task to BenefitDisbursement or Account
@AuraEnabled public String encounterUuid;    // CallObject: unique encounter identifier
@AuraEnabled public String notes;            // Description prefix (encounter notes)
@AuraEnabled public String pos;              // Position/location (default "27")
@AuraEnabled public Boolean isCrisis;        // Crisis flag
@AuraEnabled public Datetime startUtc;       // Encounter start time (UTC)
@AuraEnabled public Datetime endUtc;         // Encounter end time (UTC)
@AuraEnabled public String createdByUserId;  // Task owner/assignee (User Id)
```

**Usage**:
```apex
// In ProgramEnrollmentService
TaskService.TaskCreationDTO taskDto = new TaskService.TaskCreationDTO(
    disbursementId, encounterUuid, notes, pos, isCrisis, startUtc, endUtc, createdByUserId
);
Id taskId = TaskService.createValidationTask(taskDto);
```

**Mapping**:
- `disbursementId` → Task.WhatId
- `encounterUuid` → Task.CallObject
- `createdByUserId` → Task.OwnerId
- Other fields → Task.Description (concatenated)

**Backward Compatibility**: Legacy method `createValidationTask(Id, String, String, String, Boolean, Datetime, Datetime, String)` still supported (delegates to DTO overload)

---

### 2. DisburseRequest
**Location**: `BenefitDisbursementService.cls` (public inner class)  
**Status**: ✅ Active (well-established)  
**Purpose**: Consolidate benefit disbursement request parameters

**Fields**:
```apex
@AuraEnabled public List<String> participantAccountIds;  // Selected participant IDs
@AuraEnabled public String programId;                    // Program Id (as string)
@AuraEnabled public String programName;                  // Program Name (fallback if programId null)
@AuraEnabled public String eventType;                    // Benefit type filter (optional)
@AuraEnabled public String benefitId;                    // Chosen Benefit Id
@AuraEnabled public String startDateTime;                // Clinical: ISO string (e.g., 2025-10-12T14:30)
@AuraEnabled public String endDateTime;                  // Clinical: ISO string
@AuraEnabled public String caseNotes;                    // Notes for InteractionSummary
@AuraEnabled public String serviceDate;                  // Service date (YYYY-MM-DD)
@AuraEnabled public Integer quantity;                    // Quantity (default 1)
@AuraEnabled public String notes;                        // Optional notes
@AuraEnabled public Boolean ensureAssignment;            // Auto-create missing BenefitAssignment (default true)
@AuraEnabled public Boolean isClinical;                  // Clinical flow flag
@AuraEnabled public Map<String, String> individualCaseNotesByParticipant;
```

**Usage**:
```apex
// From LWC
DisburseRequest req = new DisburseRequest();
req.participantAccountIds = selectedAccountIds;
req.programId = programId;
req.benefitId = benefitId;
req.serviceDate = '2025-11-08';
req.quantity = 1;

List<DisburseResult> results = BenefitDisbursementService.createDisbursements(req);
```

**Mapping**:
- `programId` / `programName` → Program lookup
- `benefitId` → Benefit lookup
- `participantAccountIds` → Iteration for each participant
- `startDateTime`, `endDateTime` → Clinical interaction datetime fields
- `caseNotes` → InteractionSummary description

---

### 3. DisburseResult
**Location**: `BenefitDisbursementService.cls` (public inner class)  
**Status**: ✅ Active  
**Purpose**: Return outcome of benefit disbursement creation

**Fields**:
```apex
@AuraEnabled public Id disbursementId;       // Created BenefitDisbursement Id
@AuraEnabled public Id accountId;            // Participant Account Id
@AuraEnabled public Boolean success;         // Operation success flag
@AuraEnabled public String message;          // Success/error message
@AuraEnabled public String errorCode;        // Error code for diagnostics
```

**Usage**:
```apex
List<DisburseResult> results = BenefitDisbursementService.createDisbursements(request);
for (DisburseResult r : results) {
    if (r.success) {
        System.debug('Created disbursement: ' + r.disbursementId);
    } else {
        System.debug('Failed for ' + r.accountId + ': ' + r.message);
    }
}
```

---

### 4. Option
**Location**: `BenefitDisbursementService.cls` (public inner class)  
**Status**: ✅ Active  
**Purpose**: Generic label/value dropdown pair

**Fields**:
```apex
@AuraEnabled public String label;    // Display text
@AuraEnabled public String value;    // Internal value (typically Id)
```

**Usage**:
```apex
List<Option> eventTypes = BenefitDisbursementService.getEventTypes(programId, null);
// Returns: [{label: 'Housing', value: '001XXXXX'}, {label: 'Food', value: '002XXXXX'}, ...]
```

**Mapping**:
- `label` ← Benefit.Name or BenefitType.Name
- `value` ← Benefit.Id or BenefitType.Id

---

### 5. EnsureResult
**Location**: `ProgramEnrollmentService.cls` (global inner class)  
**Status**: ✅ Active  
**Purpose**: Return outcome of enrollment creation/update

**Fields**:
```apex
@AuraEnabled public String encounterId;            // Encounter UUID
@AuraEnabled public Id programEnrollmentId;        // Created/found ProgramEnrollment Id
@AuraEnabled public Id programId;                  // Program Id
@AuraEnabled public Id accountId;                  // Account Id
@AuraEnabled public String personUuid;             // Person Account UUID
@AuraEnabled public String firstName;              // Person first name
@AuraEnabled public String lastName;               // Person last name
@AuraEnabled public Datetime startUtc;             // Encounter start
@AuraEnabled public Datetime endUtc;               // Encounter end
@AuraEnabled public String pos;                    // Position/location
@AuraEnabled public Boolean isCrisis;              // Crisis flag
@AuraEnabled public String notes;                  // Encounter notes
```

**Usage**:
```apex
// REST endpoint response
{
    "programEnrollmentId": "a01XXXXX",
    "accountId": "001XXXXX",
    "personUuid": "person-123"
}
```

---

### 6. PwaEncounter (Global)
**Location**: `PwaEncounter.cls` (standalone global class)  
**Status**: ✅ Active  
**Purpose**: Represent PWA encounter data ingested from external system

**Fields**:
```apex
@AuraEnabled public String encounterUuid;    // Unique encounter ID
@AuraEnabled public String personUuid;       // Person UUID
@AuraEnabled public String firstName;        // First name
@AuraEnabled public String lastName;         // Last name
@AuraEnabled public Datetime startUtc;       // Encounter start time
@AuraEnabled public Datetime endUtc;         // Encounter end time
@AuraEnabled public String pos;              // Position/location code
@AuraEnabled public Boolean isCrisis;        // Crisis indicator
@AuraEnabled public String notes;            // Encounter notes
@AuraEnabled public String location;         // Physical location/address
@AuraEnabled public String services;         // Services provided (comma-separated or JSON)
@AuraEnabled public String deviceId;         // Device identifier (mobile app)
```

**Usage**:
```apex
// Deserialized from PWA REST request
{
    "encounterUuid": "enc-2025-001",
    "personUuid": "person-456",
    "firstName": "John",
    "lastName": "Doe",
    "startUtc": "2025-11-08T14:30:00Z",
    "endUtc": "2025-11-08T15:00:00Z",
    "pos": "27",
    "isCrisis": false,
    "notes": "Outreach intake complete",
    "services": "Assessment,Housing Search"
}
```

**Note**: Private duplicate exists in `ProgramEnrollmentService.cls` (deprecated; use global class instead)

---

### 7. ThemeDTO
**Location**: `ProgramThemeService.cls` (public inner class)  
**Status**: ✅ Active (exemplar DTO structure)  
**Purpose**: Return program theme configuration (colors, icons)

**Fields**:
```apex
@AuraEnabled public String programName;         // Program developer name
@AuraEnabled public String colorHex;            // Primary color hex (from CodeHex__c)
@AuraEnabled public String accentHex;           // Accent color hex
@AuraEnabled public String iconName;            // SLDS icon name
@AuraEnabled public String imageResource;       // Image resource name
@AuraEnabled public Id programId;               // Program record Id
```

**Usage**:
```apex
ThemeDTO theme = ProgramThemeService.getThemeByProgramName('1440 Pine');
// Returns: {colorHex: '#1F497D', accentHex: '#70AD47', iconName: 'standard:home', ...}
```

**Mapping**:
- Sourced from `Program_Theme__mdt` (custom metadata type)

---

### 8. SSRSRequest, SSRSResponse, AssessmentData
**Location**: `SSRSAssessmentHandler.cls` (global inner classes)  
**Status**: ✅ Active  
**Purpose**: Capture SSRS-4 suicide risk assessment data

**Fields** (abbreviated):
```apex
// SSRSRequest
@AuraEnabled public String accountId;
@AuraEnabled public String caseId;
@AuraEnabled public List<SSRSResponse> responses;
@AuraEnabled public AssessmentData assessmentData;
@AuraEnabled public String assessmentDate;
@AuraEnabled public String assessedById;

// SSRSResponse
@AuraEnabled public String questionId;
@AuraEnabled public String value;

// AssessmentData (~40 fields)
@AuraEnabled public Boolean wishDeadLifetime;
@AuraEnabled public String wishDeadLifetimeDesc;
@AuraEnabled public Boolean suicidalThoughtsLifetime;
// ... (many more ideation, intensity, and attempt fields)
```

**Usage**: REST endpoint for risk assessment submission

---

## Field Mapping Reference

### PwaEncounter → Task (via TaskCreationDTO)
| PwaEncounter | Task Field | Method |
|--------------|-----------|--------|
| `encounterUuid` | CallObject | Direct |
| `startUtc`, `endUtc` | (Description) | Formatted string |
| `pos` | (Description) | Formatted string |
| `isCrisis` | (Description) | Formatted string |
| `notes` | Description prefix | Concatenated |

### DisburseRequest → BenefitDisbursement
| Request Field | Target | Notes |
|---------------|--------|-------|
| `benefitId` | BenefitAssignment.BenefitId | Via assignment |
| `startDateTime` / `endDateTime` | BenefitDisbursement datetime fields | Clinical flow |
| `serviceDate` | BenefitDisbursement.StartDate | Non-clinical |
| `quantity` | BenefitDisbursement.DisbursedQuantity | Default 1 |
| `caseNotes` | InteractionSummary.Description | Via async service |

---

## Serialization Guidelines

### LWC → Apex
All DTOs with `@AuraEnabled` fields serialize automatically. For complex nested types:
- ✅ Use `Object` or `Map<String, Object>` in DTO
- ✅ Parse/cast server-side to avoid serialization issues
- ❌ Avoid deeply nested generic types

**Example** (BenefitDisbursementService):
```apex
// LWC sends simple types
{
  participantAccountIds: ['001XXX', '001YYY'],
  benefitId: 'a04XXX',
  serviceDate: '2025-11-08',
  quantity: 1
}

// Apex DTO receives and handles
@AuraEnabled public List<String> participantAccountIds;  // String list, not Id list
```

### Apex → LWC
DTOs with `@AuraEnabled` annotations automatically serialize to JSON. Return as:
- Single DTO: `return singleDto;`
- List of DTOs: `return List<DTOs>;`
- Map with DTO values: Not recommended; use List instead

---

## Versioning & Backward Compatibility

### Strategy
1. **Add new fields** to end of DTO (old clients ignore new fields)
2. **Deprecate fields** but keep for 2+ releases
3. **Rename DTOs** only in major releases; create new copy first
4. **Support overloads** for legacy signatures (e.g., TaskService)

### Current Examples
- `TaskCreationDTO`: Replaces 8-param method via overload (legacy method still works)
- `BenefitDisbursementService`: Extended `DisburseRequest` over time (no breaking changes)

---

## Naming Conventions

✅ **Recommended**:
- `{DomainArea}DTO` — `TaskCreationDTO`, `DisburseRequest`
- `{Action}Result` — `DisburseResult`, `EnsureResult`
- `Option` — Generic label/value pair
- Inner public class in service class if tightly coupled to one service
- Separate global class if reused across multiple services (e.g., `PwaEncounter`)

❌ **Avoid**:
- `Request`, `Response`, `Payload`, `Data`, `Info` — pick one and use consistently
- Duplicate definitions (one file per unique DTO structure)
- Long parameter lists without DTOs (>5 params → use DTO)

---

## Checklist for New DTOs

- [ ] Clear field purpose documentation in class-level comments
- [ ] All LWC-facing fields annotated with `@AuraEnabled`
- [ ] Inner class or standalone? (decision criteria: single service vs. multi-service reuse)
- [ ] Serialization edge cases tested (Map, nested objects)
- [ ] Backward compatibility plan (if refactoring existing method)
- [ ] Entry added to this registry (DTOs.md)
- [ ] Example usage in method javadoc
- [ ] Unit test coverage for DTO construction

---

## Related Files

- **Contract Layer**: `pwa-sync-starter/shared/contracts/` (TypeScript equivalents)
- **Service Classes**: `force-app/main/default/classes/`
- **LWC Calls**: `force-app/main/default/lwc/*/`

---

## Future Work

- [ ] Auto-generate TypeScript types from Apex DTOs (OpenAPI/Swagger)
- [ ] Create DTOMapper utility for common field transformations
- [ ] Centralize `Option` into shared library (currently duplicated)
- [ ] Documentation site with visual diagrams of DTO flows

