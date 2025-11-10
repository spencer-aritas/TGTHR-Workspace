# DTO Validation Setup

**Location**: `docs/setup/`  
**Status**: Complete  
**Last Updated**: 2025-01

## Overview

The DTO Sync Validator is a Node.js script that ensures Apex DTOs and TypeScript contracts stay in sync. It runs automatically before every commit via pre-commit hooks.

## Prerequisites

- Node.js 14+ (already installed in project)
- npm (comes with Node.js)
- Git with husky hooks configured
- Bash or PowerShell terminal

## What's Already Done

✅ Validator script created: `scripts/validate-dto-sync.js`  
✅ Pre-commit integration configured in `package.json`  
✅ Husky hooks active: `.husky/pre-commit`  
✅ All 3 DTOs validated and passing  

**Status: Ready to use immediately** 🚀

## Manual Validation

### Run Validator Anytime

```bash
cd d:\Projects\TGTHR-Workspace\tgthrProgramManagement
npm run validate-dto-sync
```

### Expected Output (Success)

```
🔍 DTO Sync Validator - Starting validation...

📋 Validating: TaskCreationDTO <-> TaskContract.ts
──────────────────────────────────────────────────
✅ PASS - Fields are in sync
   Apex fields: disbursementId, encounterUuid, notes, pos, isCrisis, startUtc, endUtc, createdByUserId
   TS fields:   disbursementId, encounterUuid, notes, pos, isCrisis, startUtc, endUtc, createdByUserId

📋 Validating: FollowUpTaskDTO <-> TaskContract.ts
──────────────────────────────────────────────────
✅ PASS - Fields are in sync
   Apex fields: accountId, encounterUuid, notes, pos, isCrisis, startUtc, endUtc, createdByUserId
   TS fields:   accountId, encounterUuid, notes, pos, isCrisis, startUtc, endUtc, createdByUserId

📋 Validating: PwaEncounter <-> PwaEncounterContract.ts
──────────────────────────────────────────────────
✅ PASS - Fields are in sync
   Apex fields: encounterUuid, personUuid, firstName, lastName, startUtc, endUtc, pos, isCrisis, notes, location, services, deviceId
   TS fields:   encounterUuid, personUuid, firstName, lastName, startUtc, endUtc, pos, isCrisis, notes, location, services, deviceId

══════════════════════════════════════════════════
📊 Validation Summary
══════════════════════════════════════════════════
✅ Passed: 3/3
❌ Failed: 0/3

🟢 VALIDATION PASSED - All DTOs are in sync!
```

### Exit Codes

- **0**: All DTOs in sync (success)
- **1**: DTOs out of sync (failure, commit blocked)

## Automatic Pre-commit Validation

### When It Runs

Every time you attempt to commit:

```bash
git add .
git commit -m "Update DTO fields"

# Pre-commit hook automatically runs:
# 1. npm run validate-dto-sync ← DTO validation
# 2. lint-staged              ← Linting and formatting
# 3. Commit proceeds if all pass
```

### If Validation Fails

**Example failure message:**
```
🔴 VALIDATION FAILED - Please fix the above issues before committing

   ❌ Apex field "encounterUuid" missing in TypeScript (TaskCreationRequest)
```

**Resolution**:
1. Add missing field to Apex DTO or TypeScript contract
2. Run `npm run validate-dto-sync` manually to verify fix
3. Stage the changes: `git add .`
4. Try committing again: `git commit -m "..."`

## How the Validator Works

### 1. File Discovery

- Reads all `.cls` files from `force-app/main/default/classes/`
- Reads all `.ts` files from `pwa-sync-starter/shared/contracts/`

### 2. Apex DTO Extraction

```
For each configured DTO (TaskCreationDTO, FollowUpTaskDTO, PwaEncounter):
  1. Find class definition: `public class ClassName {`
  2. Count braces to find closing brace
  3. Track string context (avoid false matches in strings)
  4. Extract @AuraEnabled fields: `@AuraEnabled public Type fieldName;`
  5. Store field name and type
```

### 3. TypeScript Contract Extraction

```
For each configured interface (TaskCreationRequest, FollowUpTaskRequest, PwaEncounter):
  1. Find interface definition: `export interface InterfaceName {`
  2. Extract properties: `fieldName?: type` or `fieldName: type`
  3. Filter out comments (// and /* */)
  4. Mark optional if ? present
  5. Store field name and type
```

### 4. Field Comparison

```
For each Apex DTO field:
  1. Find matching TypeScript field (by name)
  2. Error if not found
  
For each TypeScript field:
  1. Find matching Apex field (by name)
  2. Warning if not found (orphaned field)
  
For matching fields:
  1. Compare optional/required status
  2. Warning if mismatch (expected for client flexibility)
```

### 5. Reporting

- ✅ **PASS**: All fields match (no errors)
- ❌ **FAIL**: Missing fields (blocking errors)
- ⚠️ **WARN**: Optional mismatches or orphaned fields (informational)

## Common Scenarios

### Scenario 1: Add New Field to DTO

**Steps:**

1. **Update Apex DTO** (`TaskService.cls`):
   ```apex
   @AuraEnabled public String newField;  // Add this
   ```

2. **Update TypeScript Contract** (`TaskContract.ts`):
   ```typescript
   newField?: string;  // Add this
   ```

3. **Run validator**:
   ```bash
   npm run validate-dto-sync
   ```
   → Should PASS if names match

4. **Commit**:
   ```bash
   git add .
   git commit -m "Add newField to TaskCreationDTO"
   ```
   → Pre-commit validates automatically

### Scenario 2: Remove Field from DTO

**Steps:**

1. **Remove from Apex DTO**:
   ```apex
   // @AuraEnabled public String removedField;  // Removed
   ```

2. **Remove from TypeScript Contract**:
   ```typescript
   // removedField?: string;  // Removed
   ```

3. **Run validator**:
   ```bash
   npm run validate-dto-sync
   ```
   → Should PASS

4. **Commit**:
   ```bash
   git add .
   git commit -m "Remove removedField from DTO"
   ```

### Scenario 3: Rename Field

**Steps:**

1. **Rename in Apex DTO**:
   ```apex
   // @AuraEnabled public String oldName;     // Old
   @AuraEnabled public String newName;        // New
   ```

2. **Rename in TypeScript Contract**:
   ```typescript
   // oldName?: string;     // Old
   newName?: string;        // New
   ```

3. **Update FIELD_MAPPINGS** (if needed):
   ```javascript
   // In scripts/validate-dto-sync.js
   const FIELD_MAPPINGS = {
     'oldName': 'newName'  // Add if names don't match
   };
   ```

4. **Run validator and commit**

## Adding New DTOs to Validation

### When You Create a New DTO

**Example: Creating new BenefitAssignmentDTO**

1. **Create Apex DTO** (add to appropriate .cls file):
   ```apex
   public class BenefitAssignmentDTO {
     @AuraEnabled public String benefitId;
     @AuraEnabled public String programId;
     @AuraEnabled public Boolean isActive;
   }
   ```

2. **Create TypeScript Contract** (`pwa-sync-starter/shared/contracts/BenefitContract.ts`):
   ```typescript
   export interface BenefitAssignmentRequest {
     benefitId: string;
     programId: string;
     isActive: boolean;
   }
   ```

3. **Update Validator** (`scripts/validate-dto-sync.js`):
   ```javascript
   const DTO_MAPPINGS = {
     'TaskCreationDTO': 'TaskContract.ts',
     'FollowUpTaskDTO': 'TaskContract.ts',
     'PwaEncounter': 'PwaEncounterContract.ts',
     'BenefitAssignmentDTO': 'BenefitContract.ts'  // Add this
   };
   ```

4. **Test validation**:
   ```bash
   npm run validate-dto-sync
   ```
   → New DTO should now be validated

5. **Commit**:
   ```bash
   git add .
   git commit -m "Add BenefitAssignmentDTO with validation"
   ```

## Optional Field Differences

### Expected Behavior

TypeScript shows optional fields as `field?: type`  
Apex doesn't use optional marker (uses non-nullable semantics)

**Validator output:**
```
⚠️  Optional mismatch for "startUtc": Apex=false, TS=true
```

**This is expected and acceptable!** ✅
- TypeScript uses `?` for client flexibility (values may be undefined in transit)
- Apex enforces non-null at compile time
- Validator correctly reports as warning (non-blocking)

### When to Care

You should fix optional mismatches only if:
1. Field should ALWAYS be required on client (remove `?`)
2. Field should NEVER be required (add to Apex optional fields)

Otherwise, warnings can be safely ignored.

## Troubleshooting

### Issue: Validator exits with code 1 but no errors shown

**Cause**: Apex file has syntax errors (missing braces, etc.)

**Solution**:
1. Check Apex file syntax
2. Verify matching braces in class definitions
3. Look for unclosed string literals

### Issue: Pre-commit hook doesn't run

**Cause**: Husky not installed or hooks not initialized

**Solution**:
```bash
npm install husky --save-dev
npx husky install
```

### Issue: Validation passes but commit still fails

**Cause**: Validation passed but linting failed

**Solution**:
```bash
npm run prettier  # Format files
npm run lint      # Check linting
git add .
git commit -m "..."
```

### Issue: Field exists in Apex but shows as missing

**Cause**: Field name doesn't exactly match (case-sensitive!)

**Check**:
- Apex: `@AuraEnabled public String encounterUuid;`
- TypeScript: `encounterUuid?: string;`
- Must match exactly (case-sensitive)

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Validate DTOs
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm run validate-dto-sync
```

### Local CI Before Push

```bash
#!/bin/bash
# Run before push to catch issues early
npm run validate-dto-sync || exit 1
npm run lint || exit 1
npm run test:unit || exit 1
```

## Performance

- **Script Runtime**: < 500ms (fast)
- **Pre-commit Block Time**: ~1 second total (acceptable)
- **No Performance Impact**: Doesn't block normal commits for long

## Next Steps

1. **Use it**: `npm run validate-dto-sync` after changes
2. **Trust it**: It will block invalid commits
3. **Extend it**: Add new DTOs as they're created
4. **Integrate**: Add to CI/CD pipeline for enforcement

---

*Setup Guide v1.0 | 2025-01 | Complete & Active*
