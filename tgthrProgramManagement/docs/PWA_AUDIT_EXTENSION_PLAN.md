# PWA Audit Extension Plan: HIPAA Safe Harbor 18 PII Tracking

## Overview

This document outlines the plan to extend the audit tracking system to the mobile PWA (Progressive Web App) to ensure consistent HIPAA compliance across both Salesforce LWC and the mobile platform.

## Current State

### Salesforce LWC (Completed)
The following components now log PHI access with specific PII category tracking:

| Component | Access Source | PII Categories Tracked |
|-----------|---------------|----------------------|
| `clinicalNote` | ClinicalNote | NAMES, DATES, PHONE, EMAIL, MEDICAL_RECORD |
| `peerNote` | PeerNote | NAMES, DATES, PHONE, EMAIL, MEDICAL_RECORD |
| `interactionSummaryBoard` | InteractionSummaryBoard | NAMES |
| `interviewSession` | InterviewSession | NAMES, GEOGRAPHIC, DATES, PHONE, EMAIL, SSN, MEDICAL_RECORD, HEALTH_PLAN, PHOTO |

### PWA (Existing Infrastructure)
The PWA already has:
- `audit_integration.py` - Middleware that captures API requests to PHI endpoints
- `audit_log_service.py` - Service that writes to Salesforce `Audit_Log__c`
- PHI endpoint detection (`PHI_ACCESS_PATTERNS`)

## HIPAA Safe Harbor 18 Identifiers

The 18 types of identifiers that must be removed for Safe Harbor de-identification:

| # | Identifier | Field Examples | PWA Endpoint |
|---|------------|----------------|--------------|
| 1 | Names | FirstName, LastName, Goes_By__c | `/api/person`, `/api/sync` |
| 2 | Geographic (smaller than state) | Address, City, ZIP | `/api/person` |
| 3 | Dates (except year) | DOB, Admission, Discharge | `/api/person`, `/api/interaction` |
| 4 | Phone numbers | Phone, Mobile | `/api/person` |
| 5 | Fax numbers | Fax | `/api/person` |
| 6 | Email addresses | PersonEmail | `/api/person` |
| 7 | SSN | SSN__c | `/api/person` |
| 8 | Medical record numbers | HMIS_Id__c, Medicaid_Id__c | `/api/person` |
| 9 | Health plan beneficiary numbers | Insurance_Id__c | `/api/person` |
| 10 | Account numbers | External_Id__c | `/api/person` |
| 11 | Certificate/license numbers | - | - |
| 12 | Vehicle identifiers | - | - |
| 13 | Device identifiers | Device Token | `/api/device` |
| 14 | Web URLs | - | - |
| 15 | IP addresses | (logged in middleware) | All endpoints |
| 16 | Biometric identifiers | Signature Images | `/api/signature` |
| 17 | Full-face photographs | PhotoUrl | `/api/person` |
| 18 | Any unique identifier | UUID, Salesforce ID | All endpoints |

## Implementation Plan

### Phase 1: Enhance Audit Integration Middleware

**File:** `pwa-sync-starter/server/app/middleware/audit_integration.py`

Add PII category detection based on request/response content:

```python
# Add to audit_integration.py

PII_FIELD_CATEGORIES = {
    'NAMES': ['firstName', 'lastName', 'name', 'goesBy', 'goes_by'],
    'GEOGRAPHIC': ['mailingStreet', 'mailingCity', 'mailingState', 'mailingPostalCode', 'address'],
    'DATES': ['birthdate', 'personBirthdate', 'dateOfBirth', 'dob'],
    'PHONE': ['phone', 'mobilePhone', 'homePhone', 'personMobilePhone'],
    'FAX': ['fax'],
    'EMAIL': ['email', 'personEmail'],
    'SSN': ['ssn', 'socialSecurityNumber'],
    'MEDICAL_RECORD': ['hmisId', 'hmis_id', 'medicaidId', 'medicaid_id'],
    'HEALTH_PLAN': ['insuranceProvider', 'insuranceId'],
    'ACCOUNT_NUMBERS': ['externalId', 'clientId'],
    'DEVICE': ['deviceToken', 'device_id'],
    'BIOMETRIC': ['signature', 'signatureId'],
    'PHOTO': ['photoUrl', 'photo_url', 'profilePhoto']
}

def detect_pii_categories(request_body: dict, response_body: dict) -> list[str]:
    """
    Analyze request/response to detect which PII categories were accessed.
    Returns list of category names (e.g., ['NAMES', 'PHONE', 'EMAIL'])
    """
    categories = set()
    
    # Combine all fields from request and response
    all_fields = set()
    if request_body:
        all_fields.update(_extract_field_names(request_body))
    if response_body:
        all_fields.update(_extract_field_names(response_body))
    
    # Match fields to categories
    for category, field_patterns in PII_FIELD_CATEGORIES.items():
        for field in all_fields:
            field_lower = field.lower()
            if any(pattern.lower() in field_lower for pattern in field_patterns):
                categories.add(category)
                break
    
    return list(categories)

def _extract_field_names(obj: any, prefix: str = '') -> set[str]:
    """Recursively extract all field names from a dict/list structure."""
    fields = set()
    if isinstance(obj, dict):
        for key, value in obj.items():
            fields.add(key)
            fields.update(_extract_field_names(value, f"{prefix}{key}."))
    elif isinstance(obj, list):
        for item in obj:
            fields.update(_extract_field_names(item, prefix))
    return fields
```

### Phase 2: Update Audit Log Service

**File:** `pwa-sync-starter/server/app/salesforce/audit_log_service.py`

Add PII tracking fields to the audit record:

```python
def log_action(
    self,
    action_type: str,
    entity_id: Optional[str],
    details: str,
    *,
    pii_categories: Optional[list[str]] = None,  # NEW
    access_context: Optional[str] = None,        # NEW
    is_curiosity_browse: bool = False,           # NEW
    # ... existing params
) -> None:
    record: Dict[str, Any] = {
        # ... existing fields
    }
    
    # Add PII tracking
    if pii_categories:
        # Store in Description for visibility
        pii_desc = f"PII accessed: {', '.join(pii_categories)}"
        record["Description__c"] = f"{details}. {pii_desc}"[:32768]
        
        # Also store in Audit_JSON for structured queries
        if audit_json is None:
            audit_json = {}
        audit_json["pii_categories"] = pii_categories
    
    # Add curiosity browse flag
    if is_curiosity_browse:
        record["Is_Curiosity_Browse__c"] = True
        record["Has_Legitimate_Access__c"] = False
    
    if access_context:
        record["Access_Context__c"] = access_context[:255]
```

### Phase 3: Update API Routers

Add PII tracking to key endpoints:

**File:** `pwa-sync-starter/server/app/routers/baseline.py` (example)

```python
from ..middleware.audit_integration import detect_pii_categories, audit_integration

@router.get("/person/{account_id}")
async def get_person(
    account_id: str,
    current_user: User = Depends(get_current_user),
    request: Request = None
):
    # ... existing logic to fetch person data
    result = await person_service.get_person(account_id)
    
    # Log PHI access with PII categories
    pii_categories = detect_pii_categories({}, result)
    audit_integration.log_api_access(
        request=request,
        response_status=200,
        user_id=current_user.id,
        entity_ids=[account_id],
        pii_categories=pii_categories,
        access_context=f"PWA:{current_user.role}"
    )
    
    return result
```

### Phase 4: Frontend Tracking (PWA Client)

Add client-side tracking for UI interactions that don't trigger API calls but still display PHI:

**File:** `pwa-sync-starter/src/services/auditService.ts` (new)

```typescript
interface PHIAccessEvent {
  recordId: string;
  objectType: string;
  accessSource: string;
  piiCategories: string[];
  timestamp: Date;
}

class AuditService {
  private accessQueue: PHIAccessEvent[] = [];
  private flushInterval: number = 5000; // 5 seconds
  
  constructor() {
    // Batch flush to avoid excessive API calls
    setInterval(() => this.flush(), this.flushInterval);
  }
  
  logPHIAccess(event: PHIAccessEvent): void {
    this.accessQueue.push({ ...event, timestamp: new Date() });
  }
  
  private async flush(): Promise<void> {
    if (this.accessQueue.length === 0) return;
    
    const events = [...this.accessQueue];
    this.accessQueue = [];
    
    try {
      await fetch('/api/audit/batch', {
        method: 'POST',
        body: JSON.stringify({ events }),
        headers: { 'Content-Type': 'application/json' }
      });
    } catch (error) {
      // Re-queue failed events
      this.accessQueue.unshift(...events);
      console.error('Failed to flush audit events:', error);
    }
  }
}

export const auditService = new AuditService();
```

### Phase 5: Curiosity Browse Detection

Add logic to detect when PWA users access records they don't have legitimate access to:

**File:** `pwa-sync-starter/server/app/middleware/access_validation.py` (new)

```python
from typing import Optional
from .audit_integration import audit_integration

async def check_legitimate_access(
    user_id: str,
    record_id: str,
    object_type: str,
) -> tuple[bool, str]:
    """
    Check if user has legitimate access to the record.
    Returns (has_access, context_description)
    """
    # Check if user is admin/supervisor
    if await is_supervisor_or_admin(user_id):
        return True, "Supervisor/Admin Access"
    
    # Check based on object type
    if object_type == 'PersonAccount':
        # Check if user owns any cases for this person
        if await owns_case_for_account(user_id, record_id):
            return True, "Case Owner"
        # Check if user is on case team
        if await is_on_case_team(user_id, record_id):
            return True, "Case Team Member"
    
    elif object_type == 'InteractionSummary':
        # Check if user authored the note
        if await is_note_author(user_id, record_id):
            return True, "Note Author"
        # Check if user owns related case
        if await owns_related_case(user_id, record_id):
            return True, "Case Owner"
    
    # No legitimate access found
    return False, "No Direct Assignment"
```

## Migration Steps

### Step 1: Deploy Salesforce Changes (Completed)
- [x] `RecordAccessService.cls` with PII tracking
- [x] `Audit_Log__c` fields for curiosity browse
- [x] LWC component updates

### Step 2: PWA Backend Updates
1. Update `audit_integration.py` with PII detection
2. Update `audit_log_service.py` with new fields
3. Add `access_validation.py` for curiosity detection
4. Update key routers to include PII categories

### Step 3: PWA Frontend Updates
1. Create `auditService.ts` for client-side tracking
2. Add tracking calls to person/case/interview views
3. Implement batch flush for performance

### Step 4: Testing
1. Unit tests for PII detection logic
2. Integration tests for audit log creation
3. End-to-end tests for curiosity browse detection

### Step 5: Monitoring
1. Create Salesforce report for curiosity browse events
2. Set up alerts for unusual access patterns
3. Weekly audit review dashboard

## Rollout Plan

| Phase | Timeline | Scope |
|-------|----------|-------|
| 1 | Week 1 | Salesforce LWC tracking (COMPLETE) |
| 2 | Week 2 | PWA backend audit integration |
| 3 | Week 3 | PWA frontend tracking |
| 4 | Week 4 | Testing & monitoring |
| 5 | Week 5 | Production rollout |

## Success Metrics

1. **Coverage**: 100% of PHI access logged with PII categories
2. **Latency**: < 50ms overhead per request
3. **Completeness**: All 18 HIPAA identifiers tracked where applicable
4. **Detection Rate**: Curiosity browse events surfaced within 24 hours

## Questions for Implementation

1. Should we add a user-facing "access log" showing who viewed their record?
2. Do we need real-time alerts for curiosity browse, or is daily report sufficient?
3. Should offline PWA access be logged when device reconnects?
4. What retention period for audit logs (default: 7 years for HIPAA)?

---

**Document Version:** 1.0
**Created:** 2025-12-18
**Author:** TGTHR Development Team
