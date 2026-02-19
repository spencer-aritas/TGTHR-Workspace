# Treatment Plan Multi-Signature Implementation

## Implementation Summary

This document tracks the implementation of the multi-signature paradigm for Treatment Plans, where Goals with different Service Modalities require different signers.

### Requirements

1. **Service Modality Picklist**: Change "Service Description/Modality" from text to picklist with options:
   - Clinical
   - Case Management  
   - Peer

2. **Signature Requirements**:
   - **Clinical goals** → Require Clinician (Staff) signature
   - **Case Management goals** → Require Case Manager signature
   - **Peer goals** → Require Peer Support signature
   - **Client signature** → Required for all Treatment Plans
   - **Manager co-sign** → Optional (existing functionality)

3. **Maximum Signatures**: Up to 4 signatures per Treatment Plan:
   - Client (participant)
   - Staff (clinician creating the plan)
   - Case Manager (for Case Management goals)
   - Peer Support (for Peer goals)

4. **User Selection**: Case Manager and Peer Support signers must be:
   - Active Users
   - Have "Python API Access" Permission Set

5. **Override Options**: Checkboxes to allow clinician to sign for multiple roles:
   - "Sign for Peer"
   - "Sign for Case Management"

---

## ✅ Completed Items

### 1. Schema Changes

**GoalAssignment Object**:
- ✅ Created `Service_Modality__c` picklist field
  - File: `force-app/main/default/objects/GoalAssignment/fields/Service_Modality__c.field-meta.xml`
  - Values: Clinical (default), Case Management, Peer
  - Required: No (optional)

**Interview__c Object** - Case Manager Signature Fields:
- ✅ `CaseManager_Signature_File_Id__c` (Text 18) - ContentDocument ID
- ✅ `CaseManager_Signed__c` (Checkbox) - Boolean indicator
- ✅ `Date_CaseManager_Signed__c` (DateTime) - Signature timestamp
- ✅ `CaseManager_Signed_By__c` (Lookup to User) - Who signed

**Interview__c Object** - Peer Support Signature Fields:
- ✅ `PeerSupport_Signature_File_Id__c` (Text 18) - ContentDocument ID
- ✅ `PeerSupport_Signed__c` (Checkbox) - Boolean indicator
- ✅ `Date_PeerSupport_Signed__c` (DateTime) - Signature timestamp
- ✅ `PeerSupport_Signed_By__c` (Lookup to User) - Who signed

### 2. Profile Permissions

✅ Updated **System Administrator** profile:
  - Read/Edit access to all new Interview__c signature fields

✅ Updated **TGTHR Base Profile**:
  - Read/Edit access to all new Interview__c signature fields

### 3. Apex Controllers

✅ **GoalAssignmentController.cls**:
  - Updated `GoalAssignmentDTO` to include `serviceModality` field
  - Updated query to include `Service_Modality__c`
  - Updated save logic to persist `Service_Modality__c` value
  - Maintains backward compatibility with existing `Description` field

✅ **InterviewSessionController.cls**:
  - Updated `updateInterviewSignatures()` method signature:
    ```apex
    public static Boolean updateInterviewSignatures(
        Id interviewId, 
        String clientSignatureId, 
        String staffSignatureId,
        String caseManagerSignatureId,
        Id caseManagerSignedBy,
        String peerSupportSignatureId,
        Id peerSupportSignedBy
    )
    ```
  - Added Case Manager signature save logic
  - Added Peer Support signature save logic
  - Uses `putIfFieldExists()` for safe field updates

### 4. LWC Components

✅ **goalAssignmentCreator** (LWC):
  - Changed Service Description/Modality from textarea to combobox
  - Added `serviceModalityOptions` getter (Clinical, Case Management, Peer)
  - Updated `initializeGoal()` to default to 'Clinical'
  - Updated goal display to show `serviceModality` instead of `description`
  - Updated form modal to use picklist instead of free text

---

## 🚧 Remaining Work

### 1. InterviewSession LWC Updates

**Location**: `force-app/main/default/lwc/interviewSession/`

#### A. Goal Analysis Logic
Add computed properties to determine which signatures are required based on goals:

```javascript
// Computed properties needed:
get hasCaseManagementGoals() {
    // Analyze this.goals array for any goal with serviceModality === 'Case Management'
}

get hasPeerGoals() {
    // Analyze this.goals array for any goal with serviceModality === 'Peer'
}

get showCaseManagerSignature() {
    return this.isTreatmentPlanTemplate && 
           (this.hasCaseManagementGoals || this.signForCaseManagement);
}

get showPeerSupportSignature() {
    return this.isTreatmentPlanTemplate && 
           (this.hasPeerGoals || this.signForPeer);
}

get requireCaseManagerSignature() {
    return this.hasCaseManagementGoals && !this.signForCaseManagement;
}

get requirePeerSupportSignature() {
    return this.hasPeerGoals && !this.signForPeer;
}
```

#### B. Tracked Properties
Add new tracked properties:

```javascript
@track caseManagerSignatureId = null;
@track peerSupportSignatureId = null;
@track caseManagerSignatureStatus = null;
@track peerSupportSignatureStatus = null;
@track caseManagerSignedBy = null;
@track peerSupportSignedBy = null;
@track signForCaseManagement = false;  // Override checkbox
@track signForPeer = false;            // Override checkbox
```

#### C. HTML Template Updates
Add signature sections in `interviewSession.html` after existing Staff Signature section:

```html
<!-- Case Manager Signature Section -->
<template if:true={showCaseManagerSignature}>
    <lightning-card title="Case Manager Signature" icon-name="utility:edit" class="slds-m-top_medium">
        <div class="slds-p-horizontal_medium slds-p-bottom_medium">
            <!-- User selection lookup -->
            <lightning-input 
                label="Select Case Manager" 
                type="text"
                placeholder="Search for user..."
                value={caseManagerSignedBy}
                onchange={handleCaseManagerUserChange}>
            </lightning-input>
            
            <!-- Signature pad -->
            <c-signature-pad
                title="Case Manager Signature"
                data-role="casemanager"
                filename={caseManagerSignatureFilename}
                onsignaturesaved={handleCaseManagerSignatureSaved}>
            </c-signature-pad>
            
            <!-- Status display -->
            <template if:true={caseManagerSignatureStatus}>
                <div class="signature-status slds-text-color_success slds-m-top_small">
                    Signed by {caseManagerSignatureStatus.signedBy}
                    on {caseManagerSignatureStatus.signedAt}
                </div>
            </template>
        </div>
    </lightning-card>
</template>

<!-- Peer Support Signature Section -->
<template if:true={showPeerSupportSignature}>
    <lightning-card title="Peer Support Signature" icon-name="utility:edit" class="slds-m-top_medium">
        <div class="slds-p-horizontal_medium slds-p-bottom_medium">
            <!-- User selection lookup -->
            <lightning-input 
                label="Select Peer Support" 
                type="text"
                placeholder="Search for user..."
                value={peerSupportSignedBy}
                onchange={handlePeerSupportUserChange}>
            </lightning-input>
            
            <!-- Signature pad -->
            <c-signature-pad
                title="Peer Support Signature"
                data-role="peersupport"
                filename={peerSupportSignatureFilename}
                onsignaturesaved={handlePeerSupportSignatureSaved}>
            </c-signature-pad>
            
            <!-- Status display -->
            <template if:true={peerSupportSignatureStatus}>
                <div class="signature-status slds-text-color_success slds-m-top_small">
                    Signed by {peerSupportSignatureStatus.signedBy}
                    on {peerSupportSignatureStatus.signedAt}
                </div>
            </template>
        </div>
    </lightning-card>
</template>

<!-- Override Checkboxes Section -->
<template if:true={isTreatmentPlanTemplate}>
    <lightning-card title="Signature Options" class="slds-m-top_medium">
        <div class="slds-p-around_medium">
            <template if:true={hasPeerGoals}>
                <lightning-input 
                    type="checkbox" 
                    label="Sign for Peer" 
                    checked={signForPeer}
                    onchange={handleSignForPeerChange}>
                </lightning-input>
            </template>
            
            <template if:true={hasCaseManagementGoals}>
                <lightning-input 
                    type="checkbox" 
                    label="Sign for Case Management" 
                    checked={signForCaseManagement}
                    onchange={handleSignForCaseManagementChange}
                    class="slds-m-top_x-small">
                </lightning-input>
            </template>
        </div>
    </lightning-card>
</template>
```

#### D. JavaScript Event Handlers
Add event handlers in `interviewSession.js`:

```javascript
// Filename generators
get caseManagerSignatureFilename() {
    return `casemanager_signature_${new Date().toISOString().split('T')[0]}.png`;
}

get peerSupportSignatureFilename() {
    return `peersupport_signature_${new Date().toISOString().split('T')[0]}.png`;
}

// User selection handlers
handleCaseManagerUserChange(event) {
    this.caseManagerSignedBy = event.target.value;
    // TODO: Implement user lookup/search
}

handlePeerSupportUserChange(event) {
    this.peerSupportSignedBy = event.target.value;
    // TODO: Implement user lookup/search
}

// Signature saved handlers
handleCaseManagerSignatureSaved(event) {
    this.caseManagerSignatureId = event.detail.contentVersionId;
    const now = new Date();
    this.caseManagerSignatureStatus = {
        signedBy: this.caseManagerSignedBy?.name || 'Case Manager',
        signedAt: now.toLocaleString(),
        timestamp: now.getTime()
    };
}

handlePeerSupportSignatureSaved(event) {
    this.peerSupportSignatureId = event.detail.contentVersionId;
    const now = new Date();
    this.peerSupportSignatureStatus = {
        signedBy: this.peerSupportSignedBy?.name || 'Peer Support',
        signedAt: now.toLocaleString(),
        timestamp: now.getTime()
    };
}

// Override checkbox handlers
handleSignForPeerChange(event) {
    this.signForPeer = event.target.checked;
}

handleSignForCaseManagementChange(event) {
    this.signForCaseManagement = event.target.checked;
}
```

#### E. Update Signature Save Logic
Update `saveSignaturesToInterview()` method:

```javascript
async saveSignaturesToInterview(interviewId) {
    const clientPad = this.template.querySelector('[data-role="client"]');
    const staffPad = this.template.querySelector('[data-role="staff"]');
    const caseManagerPad = this.template.querySelector('[data-role="casemanager"]');
    const peerSupportPad = this.template.querySelector('[data-role="peersupport"]');

    let clientSigId = null;
    let staffSigId = null;
    let caseManagerSigId = null;
    let peerSupportSigId = null;

    // Existing client/staff logic...
    
    // Save Case Manager signature if present
    if (this.showCaseManagerSignature && caseManagerPad && caseManagerPad.hasSignature()) {
        try {
            const result = await caseManagerPad.saveSignature(interviewId, true);
            if (result.success) {
                caseManagerSigId = result.contentVersionId;
            }
        } catch (error) {
            console.error('Failed to save case manager signature:', error);
        }
    }

    // Save Peer Support signature if present
    if (this.showPeerSupportSignature && peerSupportPad && peerSupportPad.hasSignature()) {
        try {
            const result = await peerSupportPad.saveSignature(interviewId, true);
            if (result.success) {
                peerSupportSigId = result.contentVersionId;
            }
        } catch (error) {
            console.error('Failed to save peer support signature:', error);
        }
    }

    // Update Interview with all signatures
    if (clientSigId || staffSigId || caseManagerSigId || peerSupportSigId) {
        try {
            await updateInterviewSignatures({
                interviewId: interviewId,
                clientSignatureId: clientSigId,
                staffSignatureId: staffSigId,
                caseManagerSignatureId: caseManagerSigId,
                caseManagerSignedBy: this.caseManagerSignedBy,
                peerSupportSignatureId: peerSupportSigId,
                peerSupportSignedBy: this.peerSupportSignedBy
            });
        } catch (error) {
            console.error('Failed to update interview signatures:', error);
        }
    }
}
```

#### F. Update Signature Validation
Update `validateRequiredSignatures()` method:

```javascript
validateRequiredSignatures() {
    const clientPad = this.template.querySelector('[data-role="client"]');
    const staffPad = this.template.querySelector('[data-role="staff"]');
    const caseManagerPad = this.template.querySelector('[data-role="casemanager"]');
    const peerSupportPad = this.template.querySelector('[data-role="peersupport"]');

    // Existing client/staff validation...
    
    // Validate Case Manager signature
    if (this.requireCaseManagerSignature) {
        if (!this.caseManagerSignedBy) {
            this.showToast('Case Manager Required', 'Please select a Case Manager for this Treatment Plan.', 'error');
            return false;
        }
        if (caseManagerPad && !caseManagerPad.hasSignature()) {
            this.showToast('Case Manager Signature Required', 'Case Manager must sign for Case Management goals.', 'error');
            return false;
        }
    }

    // Validate Peer Support signature
    if (this.requirePeerSupportSignature) {
        if (!this.peerSupportSignedBy) {
            this.showToast('Peer Support Required', 'Please select a Peer Support for this Treatment Plan.', 'error');
            return false;
        }
        if (peerSupportPad && !peerSupportPad.hasSignature()) {
            this.showToast('Peer Support Signature Required', 'Peer Support must sign for Peer goals.', 'error');
            return false;
        }
    }

    return true;
}
```

### 2. User Lookup Component

**Recommended**: Create a new LWC `userLookup` component for selecting Case Manager/Peer Support:

```javascript
// userLookup.js
import { LightningElement, api, track, wire } from 'lwc';
import searchUsers from '@salesforce/apex/UserLookupController.searchUsers';

export default class UserLookup extends LightningElement {
    @api label = 'Select User';
    @api placeholder = 'Search users...';
    @api permissionSetFilter = 'Python API Access'; // Filter by permission set
    
    @track searchTerm = '';
    @track users = [];
    @track selectedUser = null;
    @track showDropdown = false;

    // Wire method to search users
    @wire(searchUsers, { searchTerm: '$searchTerm', permissionSet: '$permissionSetFilter' })
    wiredUsers({ data, error }) {
        if (data) {
            this.users = data;
            this.showDropdown = data.length > 0;
        } else if (error) {
            console.error('Error searching users:', error);
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleUserSelect(event) {
        const userId = event.currentTarget.dataset.id;
        this.selectedUser = this.users.find(u => u.Id === userId);
        this.showDropdown = false;
        
        // Dispatch selection event
        this.dispatchEvent(new CustomEvent('userselected', {
            detail: { userId: this.selectedUser.Id, user: this.selectedUser }
        }));
    }

    get selectedUserName() {
        return this.selectedUser?.Name || '';
    }
}
```

**Apex Controller**: Create `UserLookupController.cls`:

```apex
public with sharing class UserLookupController {
    
    @AuraEnabled(cacheable=true)
    public static List<User> searchUsers(String searchTerm, String permissionSet) {
        if (String.isBlank(searchTerm)) {
            return new List<User>();
        }
        
        // Query users with the specified permission set
        Set<Id> userIds = new Set<Id>();
        if (String.isNotBlank(permissionSet)) {
            for (PermissionSetAssignment psa : [
                SELECT AssigneeId 
                FROM PermissionSetAssignment 
                WHERE PermissionSet.Name = :permissionSet 
                AND Assignee.IsActive = true
            ]) {
                userIds.add(psa.AssigneeId);
            }
        }
        
        // Search for users
        String searchPattern = '%' + searchTerm + '%';
        List<User> users = [
            SELECT Id, Name, Title, Email
            FROM User
            WHERE IsActive = true
            AND (Name LIKE :searchPattern OR Email LIKE :searchPattern)
            AND Id IN :userIds
            ORDER BY Name
            LIMIT 20
        ];
        
        return users;
    }
}
```

### 3. Document Generation Updates

**Location**: `tgthr-docgen/generate_interview_docs.py`

Need to update signature handling logic to include Case Manager and Peer Support signatures in generated documents.

### 4. Testing Required

1. **Unit Tests**:
   - Test `GoalAssignmentController` with new `serviceModality` field
   - Test `InterviewSessionController.updateInterviewSignatures()` with all 4 signatures
   - Test `UserLookupController.searchUsers()` permission set filtering

2. **Integration Tests**:
   - Create Treatment Plan with Clinical goals → verify only Staff + Client signatures required
   - Create Treatment Plan with Case Management goals → verify Case Manager signature required
   - Create Treatment Plan with Peer goals → verify Peer Support signature required
   - Create Treatment Plan with mixed goals → verify all appropriate signatures required
   - Test override checkboxes → verify clinician can sign for multiple roles

3. **Document Generation Tests**:
   - Verify all 4 signatures appear in generated documents
   - Verify signature metadata (name, date, role) is correct

---

## Deployment Checklist

### Phase 1: Schema & Permissions (Ready to Deploy)
- [ ] Deploy `GoalAssignment.Service_Modality__c` field
- [ ] Deploy Interview__c signature fields (8 new fields)
- [ ] Deploy profile updates (System Administrator, TGTHR Base Profile)
- [ ] Test field creation in org

### Phase 2: Apex Controllers (Ready to Deploy)
- [ ] Deploy `GoalAssignmentController.cls`
- [ ] Deploy `InterviewSessionController.cls`
- [ ] Deploy `UserLookupController.cls` (needs creation)
- [ ] Run Apex tests

### Phase 3: LWC Components (Partial - Needs Completion)
- [ ] Deploy updated `goalAssignmentCreator` component
- [ ] Complete and deploy updated `interviewSession` component
- [ ] Create and deploy `userLookup` component
- [ ] Test UI in org

### Phase 4: Document Generation (Needs Work)
- [ ] Update `generate_interview_docs.py` signature logic
- [ ] Test document generation with all 4 signatures
- [ ] Deploy to EC2

---

## Notes & Considerations

1. **Backward Compatibility**: 
   - Existing Treatment Plans without `Service_Modality__c` will not require additional signatures
   - The `Description` field is preserved for backward compatibility

2. **Permission Set Requirement**:
   - Case Manager and Peer Support signers MUST have "Python API Access" permission set
   - This filtering is handled in `UserLookupController`

3. **Override Behavior**:
   - When "Sign for Peer" or "Sign for Case Management" is checked, the clinician's Staff signature counts for that role
   - The separate signature pads are hidden when override is enabled
   - This allows a single person to sign once for multiple roles

4. **Signature Order**:
   - Signatures can be collected in any order
   - All required signatures must be present before document is considered complete

5. **Manager Co-Sign**:
   - Existing manager approval functionality is unchanged
   - Manager signature is independent of Service Modality-based signatures
