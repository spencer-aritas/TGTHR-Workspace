# DTO Ecosystem Architecture

**Date**: 2025-01  
**Status**: Production  
**Scope**: Complete Apex/TypeScript DTO unification across PWA and Salesforce backend

## Overview

This document consolidates the complete DTO ecosystem that unifies data contracts between Salesforce backend (Apex) and PWA frontend (TypeScript). Spans 4 implementation phases with 1200+ lines of production code.

## System Components

### Apex DTOs (Backend)
Located in `force-app/main/default/classes/TaskService.cls`

**TaskCreationDTO**
- Purpose: Consolidates validation task creation parameters
- Fields: 8 @AuraEnabled fields
  - `disbursementId` (Id) - WhatId reference
  - `encounterUuid` (String) - Unique encounter ID
  - `notes` (String) - Task description
  - `pos` (String) - Position/location code
  - `isCrisis` (Boolean) - Crisis indicator
  - `startUtc` (Datetime) - Start timestamp
  - `endUtc` (Datetime) - End timestamp
  - `createdByUserId` (String) - Task owner
- Constructors: Default + 8-param full
- Usage: `TaskService.createValidationTask(TaskCreationDTO)`

**FollowUpTaskDTO**
- Purpose: Consolidates follow-up task creation parameters
- Fields: 8 @AuraEnabled fields (same schema as TaskCreationDTO)
  - `accountId` (String) - WhatId reference (instead of disbursementId)
  - Plus 7 other fields matching TaskCreationDTO
- Constructors: Default + 7-param + 8-param (legacy support)
- Usage: `TaskService.createFollowUpTask(FollowUpTaskDTO)`

**PwaEncounter** (Global Class)
- Location: `force-app/main/default/classes/PwaEncounter.cls`
- Purpose: Global class for REST serialization
- Fields: 12 @AuraEnabled fields
  - `encounterUuid`, `personUuid`, `firstName`, `lastName`
  - `startUtc`, `endUtc`, `pos`, `isCrisis`
  - `notes`, `location`, `services`, `deviceId`
- Usage: REST request/response serialization

### TypeScript Contracts (Frontend)
Located in `pwa-sync-starter/shared/contracts/`

**TaskContract.ts** (150+ lines)
- `TaskCreationRequest` - Mirrors TaskCreationDTO
- `FollowUpTaskRequest` - Mirrors FollowUpTaskDTO
- `TaskCreationResponse` - Response envelope
- `TaskDetail` - Full Task record representation
- `TaskServiceContract` - Service interface
- Utilities:
  - Type guards: `isTaskCreationRequest()`, `isFollowUpTaskRequest()`
  - Datetime converters: `convertToISODatetime()`, `convertFromISODatetime()`

**PwaEncounterContract.ts** (200+ lines)
- `PwaEncounter` - Mirrors Apex global class
- `PwaEncounterExtended` - + 5 metadata fields
- `IngestEncounterRequest` - + 6 optional integration fields
- `IngestEncounterResponse` - Response envelope
- `EncounterServiceContract` - Service interface
- Utilities:
  - Validators: `validatePwaEncounter()`, `isValidISODatetime()`
  - Type guards: `isPwaEncounter()`, `isIngestEncounterRequest()`
  - Converters: `encounterToIngestRequest()`, `enrichEncounterWithMetadata()`

## Data Flow

```
PWA (Frontend)
    ↓
[TaskCreationRequest] (TypeScript interface)
    ↓ [JSON.stringify]
HTTP POST /services/apexrest/ProgramEnrollmentService
    ↓ [JSON.parse]
[TaskCreationDTO] (Apex class)
    ↓ [deserialization]
TaskService.createValidationTask(dto)
    ↓ [DML: insert Task]
Salesforce Task Object
    ↓ [SOQL query]
[Serialization to JSON]
    ↓ [HTTP response]
[TaskCreationResponse] (TypeScript interface)
    ↓
PWA State Management
```

## Integration Points

### REST Endpoints
- `POST /services/apexrest/ProgramEnrollmentService`
  - Request: `IngestEncounterRequest` (TypeScript) → `PwaEncounter` (Apex)
  - Response: Task/Encounter IDs with status
  
- `POST /services/apexrest/TaskService`
  - Request: `TaskCreationRequest` (TypeScript) → `TaskCreationDTO` (Apex)
  - Response: `TaskCreationResponse` with created Task ID

### Type Safety Layer
- TypeScript contracts provide compile-time type checking
- Apex DTOs provide runtime validation
- Type guards enable safe type narrowing on client
- Validators catch invalid data before transmission

## Backward Compatibility

All legacy method signatures preserved:
```apex
// Original 8-parameter version still works
TaskService.createValidationTask(
  Id disbursementId, String encounterUuid, String notes, String pos,
  Boolean isCrisis, Datetime startUtc, Datetime endUtc, String createdByUserId
);

// Delegates to new DTO-based method internally
```

## Quality Assurance

### Unit Tests
- 10/10 TaskServiceTest passing (100%)
- Coverage: Happy path, edge cases, batch operations, backward compatibility

### DTO Sync Validation
- 3/3 DTO mappings validated (Apex ↔ TypeScript)
- Pre-commit validation active
- Automated drift detection

### Deployment
- 2/2 deployments successful (zero rollbacks)
- Production deployed and live
- No data migration required

## Key Architectural Decisions

1. **Single DTO per operation**: Consolidates 8+ parameters into typed objects
2. **Global PwaEncounter class**: Single source of truth for encounter data
3. **TypeScript contracts**: Mirror Apex DTOs for type safety
4. **Pre-commit validation**: Automated sync checking between languages
5. **Backward compatible overloads**: Existing code continues working

## Future Enhancement Opportunities

1. **Auto-generation**: Generate TypeScript types from Apex JSDoc
2. **Runtime validation**: Automatic schema validation on REST endpoints
3. **OpenAPI docs**: Generate from contract definitions
4. **Database migrations**: Track schema changes over time
5. **CI/CD integration**: Enforce DTO sync in GitHub Actions

## Related Documents

- [DTOs & REST API](../api/dto-reference.md)
- [DTO Sync Validation](../setup/dto-validation.md)
- [Implementation Summary](0001-dto-consolidation-strategy.md) (ADR)

---

*Architecture v1.0 | 2025-01 | Production Ready*
