# Interview Completion, Signature, and Audit Contract

Date: 2026-03-28
Scope: interview completion, completed-document review, signing, UUID continuity, and audit logging across Salesforce LWC, Apex, PWA backend, and docgen

## Purpose

This document defines the concrete contract for the flows that matter most in the current product:

1. Completing Interviews
2. Reviewing completed documentation
3. Capturing and routing signatures
4. Preserving end-to-end UUID and audit continuity
5. Producing compliance evidence that the signer had active control of the device

This is not a generic template-governance spec. It is the contract for the operational path the product uses today.

## Current flow baseline

### Quick intake
- The only true PWA intake flow today is the quick field-service-style launch from the New Client Intake button.
- It should remain a narrow path that creates the minimal required records and launches the active intake interview template version for the selected program.

### Interview completion
- `interviewSession` is the main orchestrator.
- It initializes metadata via `InterviewSessionController.initializeSession`.
- It saves the completed interview via `InterviewSessionController.saveInterviewSession`.
- It saves signature images separately through `signaturePad` and then updates Interview signature fields through `InterviewSessionController.updateInterviewSignatures`.
- It logs signature audit events from the client via `RecordAccessService.logSignatureEvent` after save.

### Completed-document review
- Completed-document review is a consumer of Interview, InteractionSummary, InterviewDocument, and docgen payloads.
- This should become straightforward once Interview identity, signature provenance, and document ownership are canonical.

## Canonical identity contract

These identifiers should be treated differently. The current system blurs them.

### 1. Salesforce record Id is authoritative for persistence
Use Salesforce record Id for:
- Interview__c persistence
- InteractionSummary persistence
- Assessment persistence
- signature file linkage
- workflow routing and pending action items

### 2. UUID is authoritative for cross-system traceability only when present and managed
Use `UUID__c` for:
- stateless document rendering references
- cross-system correlation where a stable external identifier is needed
- audit correlation when the source is not a direct Salesforce record operation

Do not assume UUID is always present today. Active org data already contains null UUIDs on templates and versions.

### 3. Template version Id, not template name, is the runtime launch key
For interview runtime launch and completion, the canonical selector is:
- `Program.Intake_Template__c` -> `InterviewTemplate__c`
- latest active `InterviewTemplateVersion__c` under that template

Do not route behavior by normalized display label or template name text matching.

## Completion contract

### Canonical completion request
The completion request should capture:
- caseId
- accountId
- templateVersionId
- sourceInterviewId when resubmitting a recalled record
- startedAt
- interaction block
- answers
- demographicsJson
- benefit selections
- diagnoses
- selected CPT codes
- reviewed carry-forward question ids
- manager approval request fields

This mostly already exists in `InterviewSessionController.SaveRequest`.

### Canonical completion result
The server should return a result that is sufficient for downstream signature, audit, and document work:
- interviewId
- interviewUuid
- interactionSummaryId
- interactionSummaryUuid if available
- assessmentId
- templateVersionId
- templateId
- requiresManagerApproval
- managerApprovalForced
- documentGenerationRequested
- auditCorrelationId

Current gap: the result currently returns ids but not a stronger identity bundle for downstream consumers.

## Signature contract

### Signature roles
The system currently supports these roles:
- Client
- Staff / Clinician
- Case Manager
- Peer Support
- Manager approver or co-signer as workflow state, not direct signature pad role in this flow

### Signature event types
Canonical auditable actions:
- `SIGN_CAPTURED`
- `SIGN_PERSISTED`
- `SIGN_SUPPRESSED`
- `COSIGN_REQUESTED`
- `COSIGN_COMPLETED`
- `SIGN_REJECTED`
- `SIGN_RECALLED`
- `SIGNATURE_ASSIGNMENT_UPDATED`
- `DEVICE_CONTROL_CONFIRMED`

Current gap: client code logs mostly `SIGN`, `SIGN_SUPPRESSED`, and `COSIGN_REQUESTED`. This is too coarse for compliance reconstruction.

### Canonical signature payload
Every signature event should capture:
- recordId
- recordType
- interviewId
- interviewUuid if present
- interactionSummaryId
- signerRole
- signerUserId when the signer is a Salesforce user
- signerAccountId when the signer is the participant
- assignedSignerUserId when signature is deferred to another user
- signatureContentDocumentId
- signatureCapturedAt
- signaturePersistedAt
- signatureMode: direct | delegated_assignment | suppressed | deferred | recalled_resubmission
- deviceControl
- sessionContext
- complianceReference
- sourceApplication

### Device-control contract
The system needs an explicit signer-control attestation event, not just a saved image.

At minimum, the contract should capture:
- attestationRequired: boolean
- attestationAccepted: boolean
- attestationTimestamp
- attestationMethod: explicit_checkbox | press_and_hold | typed_confirmation | biometric_os_signal
- inputDeviceType: mouse | touch | pen | unknown
- userPresenceSignal: pointer_activity | touch_activity | stylus_activity | explicit_confirmation_only
- sessionId or requestCorrelationId

The compliance standard can be debated, but the contract must stop inferring signer control solely from a stored PNG.

### Assigned staff-signature contract

For authenticated internal users, the existing assignment model remains valid:

- signatures may still be assigned to Case Manager, Peer Support, Clinician, or Manager approver roles
- those assignments may continue to drive existing Salesforce notifications

But once a signature is assigned to another authenticated staff user, the compliant PWA contract should be:

1. the assignee receives the request
2. the assignee opens the request on their own authenticated device/session
3. the assignee reviews the note or interview context before signing
4. the assignee explicitly attests device control before signature completion

This means a PWA-side inline "Peer Support present, sign now" or "Case Manager present, sign now" shortcut should not be treated as the compliant path for deferred CM/Peer/Clinician signatures, even if the user is physically present.

## Audit contract

### Authoritative audit location
`Audit_Log__c` should be the authoritative compliance log for these flows.

### Canonical audit fields
Required minimum fields for completion/signature workflow:
- Action__c
- Event_Type__c
- Record_Id__c
- UUID__c
- Object_Type__c
- User__c
- Timestamp__c
- Description__c
- Access_Context__c
- Status__c
- Compliance_Reference__c
- Audit_JSON__c

### Canonical audit JSON for completion/signing
The structured audit payload should include:
- interviewId
- interviewUuid
- interactionSummaryId
- caseId
- accountId
- templateVersionId
- templateId
- signerRole
- signerUserId
- assignedSignerUserId
- signatureContentDocumentId
- deviceControlAttested
- deviceControlMethod
- requestId
- sourceApplication
- sourceSurface
- recallOrResubmissionSourceInterviewId
- managerApprovalRequired
- managerApproverId

Current gap: some audit calls only carry a freeform description and a record id. That is not enough for reliable end-to-end compliance reconstruction.

## Completed-document review contract

A completed document should be reconstructable without fallback interpretation. The review payload should always be traceable back to:
- interviewId
- interviewUuid if present
- interactionSummaryId
- templateId
- templateVersionId
- completion status
- signature roles and status
- manager approval status
- originating signer/audit events
- generated document ids

Current gap: docgen and review surfaces still rely on lighter-weight signature labels and dates than the underlying provenance needs.

## Observed gaps in current implementation

### 1. Signature persistence and signature audit are split across layers
- Interview creation happens in Apex.
- Signature file creation happens in the signature pad component.
- Signature field persistence happens in `updateInterviewSignatures`.
- Signature audit events are emitted later from client-side LWC code.

This means the persisted signature state and the compliance audit are not transactionally coupled.

### 2. Staff signer identity is currently lossy
The LWC calls `updateInterviewSignatures` with `staffSignedBy`, but the Apex method does not accept that parameter and always stamps `Staff_Signed_By__c` with `UserInfo.getUserId()`.

Implication:
- delegated or alternate clinician selection is not preserved by the persisted signature-update contract
- audit and signature provenance can diverge from UI intent

### 3. Signature capture proves image creation, not device control
`signaturePad` captures a canvas drawing and saves a ContentVersion. It does not capture an explicit signer-control attestation event.

### 4. Audit identity is mixed and shape-driven
The PWA audit service writes either `Record_Id__c` or `UUID__c` depending on entity-id shape. That is practical, but it is not a strong identity contract.

### 5. Record access audit currently sets both UUID and Record_Id from the same Salesforce record id
`RecordAccessService` writes the same `recordId` value into both `UUID__c` and `Record_Id__c`. That weakens the meaning of UUID as a distinct external correlation field.

### 6. Completed-doc signature rendering is presentation-focused
Current docgen signature rendering is primarily label/date based. It does not carry full signer provenance or explicit audit context through to the output layer.

## Implementation hit list

### Phase 1: Make server-side signature persistence authoritative
Files:
- `force-app/main/default/classes/InterviewSessionController.cls`
- `force-app/main/default/lwc/interviewSession/interviewSession.js`
- `force-app/main/default/classes/RecordAccessService.cls`

Changes:
1. Expand `updateInterviewSignatures` to accept the full signer identity contract, including delegated clinician identity.
2. Move canonical signature audit creation server-side so persisted signature state and audit event are created together.
3. Return a structured signature result from Apex instead of only `true/false`.

### Phase 2: Add device-control attestation to signing flow
Files:
- `force-app/main/default/lwc/signaturePad/signaturePad.js`
- `force-app/main/default/lwc/interviewSession/interviewSession.js`
- `force-app/main/default/classes/InterviewSessionController.cls`
- possibly `Audit_Log__c` write helpers

Changes:
1. Add explicit signer attestation UI before final save.
2. Capture device input context and attestation timestamp.
3. Persist that attestation into structured audit JSON.

### Phase 3: Strengthen UUID governance
Files:
- `force-app/main/default/classes/InterviewSessionController.cls`
- `pwa-sync-starter/web/src/db/uuid.ts`
- PWA submission and audit services

Changes:
1. Define where UUID is generated and which system owns it per entity.
2. Stop overloading Salesforce record id as UUID in audit writes.
3. Return Interview UUID in completion/save responses.

### Phase 4: Normalize completed-document identity
Files:
- `force-app/main/default/classes/InterviewDocumentService.cls`
- `force-app/main/default/classes/InterviewDocumentController.cls`
- `tgthr-docgen/generate_interview_docs.py`

Changes:
1. Ensure completed-document payload includes interview id, interview UUID, template version id, signer provenance, and audit reference.
2. Make completed-doc review a consumer of canonical interview identity instead of fallback lookups.
3. Expand docgen signature rendering from label/date-only toward full provenance-aware payload consumption.

## Recommended first implementation change

Start with `updateInterviewSignatures`.

Reason:
- It is the narrowest point where signature capture becomes persisted business state.
- It currently drops delegated clinician identity.
- It is the correct place to make signature persistence and signature audit authoritative.
- Fixing it reduces downstream ambiguity in pending docs, review, and completed-document rendering.

## Success criteria

The contract is working when:
1. A completed interview can be traced from save request to Interview, InteractionSummary, signature file, audit log, and completed document without name-based or fallback inference.
2. Every signature can identify who signed, on whose behalf if delegated, when they signed, how the signature was captured, and whether device control was explicitly attested.
3. Completed-document review can display signer and audit provenance from canonical payload fields, not reconstructed heuristics.
4. UUIDs are stable correlation identifiers rather than optional or overloaded placeholders.
