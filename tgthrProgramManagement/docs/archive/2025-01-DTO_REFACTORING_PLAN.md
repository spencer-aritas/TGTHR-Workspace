# DTO Inventory & Centralization Plan

## Current State: Existing DTOs (Apex)

### 1. BenefitDisbursementService DTOs
**File**: `force-app/main/default/classes/BenefitDisbursementService.cls`
- `Option` - Label/value pair for dropdowns
- `DisburseRequest` - Consolidates benefit disbursement parameters
- `DisburseResult` - Returns success/failure outcome
- `CreateAssignmentRequest` - Not listed but referenced in code

**Usage**: LWC ← → Apex for benefit disbursement workflows

### 2. ProgramEnrollmentService DTOs
**File**: `force-app/main/default/classes/ProgramEnrollmentService.cls`
- `EnsureResult` - Enrollment creation outcome (public, @AuraEnabled)
- `PwaEncounter` - **INTERNAL ONLY** (private), represents PWA encounter data
  - **DUPLICATE**: Also exists as `global class PwaEncounter` in `PwaEncounter.cls`

**Usage**: REST endpoint response; internal parsing

### 3. ProgramThemeService DTO
**File**: `force-app/main/default/classes/ProgramThemeService.cls`
- `ThemeDTO` - Program theme configuration (colors, icons, images)

**Usage**: LWC ← → Apex for theme retrieval

### 4. SSRSAssessmentHandler DTOs
**File**: `force-app/main/default/classes/SSRSAssessmentHandler.cls`
- `SSRSRequest` - Assessment submission request
- `SSRSResponse` - Question/answer pairs
- `AssessmentData` - 40+ fields covering SSRS assessment items

**Usage**: REST endpoint request/response

### 5. PwaEncounter (Global)
**File**: `force-app/main/default/classes/PwaEncounter.cls`
- Standalone global class (12 fields)
- Currently **NOT used** in TaskService — methods take individual parameters
- **Duplicate of private PwaEncounter in ProgramEnrollmentService**

**Usage**: REST ingestion from PWA

---

## TaskService Current Signature (Problem)

```apex
public static Id createValidationTask(
    Id disbursementId,           // WhatId
    String encounterUuid,        // CallObject
    String notes,                // Description prefix
    String pos,                  // Description field
    Boolean isCrisis,            // Description field
    Datetime startUtc,           // Description field
    Datetime endUtc,             // Description field
    String createdByUserId       // OwnerId
)
```

**Issues**:
- 8 parameters (should be <5)
- All passed to description string builder
- Mixing Task metadata fields with payload data
- Duplicates functionality already in PwaEncounter

---

## Proposed Refactoring

### Step 1: Create TaskCreationDTO
**Location**: `force-app/main/default/classes/TaskCreationDTO.cls` (or inline in TaskService)

```apex
public class TaskCreationDTO {
    @AuraEnabled public Id disbursementId;      // WhatId (what this task relates to)
    @AuraEnabled public String encounterUuid;   // CallObject
    @AuraEnabled public String notes;           // Task description prefix
    @AuraEnabled public String pos;             // Position/location
    @AuraEnabled public Boolean isCrisis;       // Crisis flag
    @AuraEnabled public Datetime startUtc;      // Encounter start time
    @AuraEnabled public Datetime endUtc;        // Encounter end time
    @AuraEnabled public String createdByUserId; // Task owner
}
```

### Step 2: Refactor TaskService
```apex
public static Id createValidationTask(TaskCreationDTO dto) {
    // Extract and validate
    if (dto == null) {
        throw new IllegalArgumentException('TaskCreationDTO cannot be null');
    }
    
    SObject taskSObj = (SObject) Type.forName('Task').newInstance();
    taskSObj.put('Subject', 'Validate Benefit Disbursement for Billing');
    taskSObj.put('WhatId', dto.disbursementId);
    taskSObj.put('CallObject', dto.encounterUuid);
    // ... rest of method
    
    return taskSObj.Id;
}
```

### Step 3: Update ProgramEnrollmentService
Current:
```apex
Id taskId = TaskService.createValidationTask(
    disbursementId,
    e.encounterUuid,
    e.notes,
    e.pos,
    e.isCrisis,
    e.startUtc,
    e.endUtc,
    createdByUserId
);
```

Refactored:
```apex
TaskCreationDTO taskDto = new TaskCreationDTO();
taskDto.disbursementId = disbursementId;
taskDto.encounterUuid = e.encounterUuid;
taskDto.notes = e.notes;
taskDto.pos = e.pos;
taskDto.isCrisis = e.isCrisis;
taskDto.startUtc = e.startUtc;
taskDto.endUtc = e.endUtc;
taskDto.createdByUserId = createdByUserId;

Id taskId = TaskService.createValidationTask(taskDto);
```

---

## DTO Consolidation Roadmap

### Phase 1: Eliminate Duplicates (HIGH PRIORITY)
| Issue | Current State | Action | Benefit |
|-------|---------------|--------|---------|
| **PwaEncounter Duplication** | Private in ProgramEnrollmentService + Global in PwaEncounter.cls | Consolidate to global `PwaEncounter`, remove private version | Single source of truth; avoid sync issues |
| **TaskService Parameters** | 8 individual args | Create `TaskCreationDTO` | Maintainability; extensible |

### Phase 2: Document & Standardize (MEDIUM PRIORITY)
| DTO | Current | Action | Owner |
|-----|---------|--------|-------|
| `Option` | Inline in BenefitDisbursementService | Document usage in DTOs.md | BenefitDisbursementService |
| `DisburseRequest` | InlineSpec defined, used | Document with examples | BenefitDisbursementService |
| `DisburseResult` | Inline, good | Keep as-is; document | BenefitDisbursementService |
| `ThemeDTO` | Dedicated class, clean | Exemplar; keep | ProgramThemeService |
| `SSRSAssessmentHandler.*` | 3 inner classes | Document; consider extraction | SSRSAssessmentHandler |
| `EnsureResult` | Inline, public | Document usage | ProgramEnrollmentService |
| `TaskCreationDTO` | **NEW** | Create; use in refactoring | TaskService |

### Phase 3: Centralized Registry (LOWER PRIORITY)
Create `DTOs.md` with:
- List of all DTOs (name, file, purpose)
- Field mappings (Apex → DB → Frontend)
- Usage examples
- Serialization/deserialization rules

### Phase 4: Contract Alignment (LONG-TERM)
- Map Apex DTOs ↔ TypeScript contracts in `shared/contracts/`
- Generate type definitions (optional: OpenAPI/Swagger)
- Versioning strategy for breaking changes

---

## Immediate Actions

### 1️⃣ **Create TaskCreationDTO** (5 min)
Inline in TaskService.cls or separate file

### 2️⃣ **Refactor TaskService methods** (10 min)
- `createValidationTask(TaskCreationDTO dto)`
- `createFollowUpTask(TaskCreationDTO dto)`

### 3️⃣ **Update ProgramEnrollmentService** (5 min)
Change ingestEncounter to use TaskCreationDTO

### 4️⃣ **Create DTOs.md documentation** (15 min)
Registry + usage guide for all 7+ Apex DTOs

### 5️⃣ **Update test class** (10 min)
Add test for new DTO flow

---

## Naming Conventions (Going Forward)

✅ **Use this pattern**:
- `{DomainArea}DTO` — `TaskCreationDTO`, `BenefitDisbursementRequest`
- Inner classes in service class if tightly coupled
- Separate file if reused across multiple services (like `Option`)

❌ **Avoid**:
- Naming variants: `Result`, `Response`, `Request`, `Payload` (pick one)
- Duplicate definitions across files
- Mixing serialization concerns (add `@AuraEnabled` if LWC-facing)

---

## Success Criteria

- [ ] TaskCreationDTO created and integrated
- [ ] All 7 DTOs documented in DTOs.md with examples
- [ ] PwaEncounter duplication resolved (single global class)
- [ ] TaskService test updated to use DTO
- [ ] All Apex DTOs have @AuraEnabled fields for LWC compatibility
- [ ] No more long parameter lists (>5 params → use DTO)

