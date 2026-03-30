# PWA Case Review And Mobile Signing Plan

## Objective

Move the PWA toward the two highest-value workflows the product still lacks:

1. Case review must open interaction and note cards into a full detail view instead of leaving them as static summary blocks.
2. Staff must be able to send a signing request and let the signer complete that signature in context on their phone, with a server-owned audit trail.

This plan is intentionally scoped to the current operational seams in `pwa-sync-starter` and the already-running Salesforce workflow. It does not try to redesign all interview, document, and signature architecture at once.

## Current State

### Case review

- `web/src/components/MyCasesPage.tsx` routes staff from the case list into `InteractionHistory`.
- `web/src/components/InteractionHistory.tsx` renders interaction rows as read-only summary blocks with meeting notes and a `+ Add Quick Note` action.
- `web/src/services/interactionSummaryService.ts` only exposes a thin `InteractionSummaryData` model.
- `server/app/api/interaction_summary.py` only serves a case-scoped list endpoint.
- `server/app/salesforce/interaction_summary_service.py` only queries a minimal subset of `InteractionSummary` fields.

### Mobile signing

- `web/src/components/SignaturePad.tsx` already captures a signature locally.
- `web/src/services/signatureService.ts` stores the PNG locally, queues it in the outbox, and uploads it to `/api/signatures/upload`.
- `server/app/api/signatures.py` creates a `ContentVersion` and stops.
- `server/app/salesforce/audit_log_service.py` can write `Audit_Log__c`, but the current signature upload flow does not use it.

### Important local evidence

The current API is thinner than the actual Salesforce data the app already knows about. `case_trace_interactions.json` shows that `InteractionSummary` records can carry useful review/signature context such as:

- `Name`
- `Status`
- `InteractionPurpose`
- `Interview__c`
- `Action_Required__c`
- `Action_Assigned_To__c`
- `Requires_Manager_Approval__c`
- `Manager_Signed__c`
- `Manager_Rejected__c`
- `Manager_Approver__c`

That means the first problem is not missing UI alone. The PWA is discarding data before it reaches the UI.

## Delivery Strategy

Split the work into two tracks:

1. Make case review useful by widening the read contract and adding a real detail surface.
2. Make mobile signing authoritative by introducing a server-owned signing request flow above the existing raw signature upload path.

The first track is a good near-term ship target. The second track should reuse existing signature capture, but it should not reuse the current "upload a PNG and hope downstream state lines up" contract as the final workflow.

## Track 1: Full Detail Case Review

### Target outcome

From a case timeline, a staff user can tap any interaction card and open a mobile-friendly detail view that shows:

- record title and type
- author and timestamps
- full note content
- review status
- linked interview/document references
- routing flags such as action required or manager approval
- next actions such as add note, open interview, or request signature

### Required backend changes

#### 1. Widen the list payload

Update `server/app/salesforce/interaction_summary_service.py` and the API response model in `server/app/api/interaction_summary.py` so the case timeline returns at least:

- `Id`
- `Name`
- `InteractionPurpose`
- `Status`
- `RelatedRecordId`
- `InteractionDate`
- `StartTime`
- `EndTime`
- `Notes`
- `CreatedByName`
- `CreatedDate`
- `LastModifiedDate`
- `InterviewId`
- `ActionRequired`
- `ActionAssignedTo`
- `RequiresManagerApproval`
- `ManagerSigned`
- `ManagerRejected`
- `ManagerApprover`

This is enough to make the case timeline informative before a detail endpoint exists.

#### 2. Add a detail endpoint

Add a new endpoint such as:

- `GET /api/interaction-summary/{interactionId}`

The detail endpoint should return a normalized DTO rather than raw Salesforce field names. It should compose from `InteractionSummary` first and then hydrate linked records when available.

Recommended detail shape:

- summary section
  - `id`, `name`, `kind`, `status`, `interactionPurpose`
- chronology section
  - `interactionDate`, `startTime`, `endTime`, `createdDate`, `lastModifiedDate`
- ownership section
  - `createdByName`, `actionAssignedToName`, `managerApproverName`
- content section
  - `notesHtml`, `notesText`
- linkage section
  - `caseId`, `accountId`, `interviewId`, `interviewStatus`, `interviewTemplateName`
- signature section
  - `requiresManagerApproval`, `managerSigned`, `managerRejected`, `signatureState`
- actions section
  - booleans for `canOpenInterview`, `canAddQuickNote`, `canRequestSignature`

If related interview/doc data is unavailable, the endpoint should still return the interaction detail with null linkage fields rather than failing the whole request.

#### 3. Keep the contract explicit

Add a dedicated shared contract file in `shared/contracts` for interaction timeline/detail data instead of continuing to overload the current summary-only contract.

Suggested split:

- `InteractionTimelineContract.ts` for case list rows
- `InteractionDetailContract.ts` for the detail endpoint

That keeps future completed-doc review work from mutating the lightweight create-request contract in place.

### Required frontend changes

#### 1. Make cards actionable

Update `web/src/components/InteractionHistory.tsx` so each interaction row is a real interactive card instead of a passive block. The card should open a detail surface on tap/click.

Do not make the whole experience route-heavy on the first pass. A detail drawer or full-screen mobile sheet is a better initial fit than introducing another top-level page state immediately.

#### 2. Add a detail component

Create a dedicated component such as:

- `web/src/components/InteractionDetailPanel.tsx`

Responsibilities:

- fetch detail by interaction id
- render a mobile-first detail layout
- show linked interview/document state when present
- expose action buttons for:
  - `Add Quick Note`
  - `Open Interview`
  - `Request Signature`

#### 3. Keep the timeline readable

The list view should show more than date plus notes snippet. Add badges or metadata chips for:

- interaction purpose
- status
- manager approval required
- linked interview
- action required

This will make the case review screen useful even before the detail panel is opened.

## Track 2: Mobile Signing Request Flow

### Target outcome

From an interaction or interview detail view, staff can issue or confirm a signing assignment. The authenticated signer then opens the request on their own device, reviews the context, attests they control the device, signs in-app, and the system persists:

- who requested the signature
- who the assigned signer is
- what record is being signed
- what related review context was shown to the signer
- when the request was opened and completed
- the attestation state
- the uploaded signature artifact
- the audit record tied to the same request id / UUID

### First-scope signing rules

The initial PWA signing flow should support only authenticated internal users:

- Clinician
- Case Manager
- Peer Support
- Manager approver / co-signer

The first pass should not attempt to solve participant/client signing for unhoused youth without reliable phone/email identity or validation channels.

### Compliance rule for staff signatures

The current "Peer Support present" or "Case Manager present" sign-now pattern is not a sufficient compliance posture for the PWA.

For parity and compliance, when Treatment Plan goal modality or note workflow requires a Clinician, Case Manager, or Peer Support signature, the PWA should:

1. assign the signature to the authenticated user who must sign
2. allow that assignment to continue driving the existing Salesforce notification path
3. surface the same pending request inside the PWA
4. let that assigned user open the request on their own device
5. require them to review the full note or interview context before signing
6. require explicit device-control attestation before signature completion

This keeps the assignment model you already use, including Salesforce notifications, while replacing an inline author-held-device "sign now" shortcut with an assignee-owned review-and-sign flow.

### Why the current flow is insufficient

The current PWA signature flow only does this:

1. capture a PNG
2. queue it offline
3. upload it as `ContentVersion`

It does not establish:

- a request lifecycle
- signer intent
- device-control attestation
- audit coupling to the upload
- authoritative linkage back to an interaction/interview/document workflow
- proof that the authenticated assignee, rather than the author holding the device, controlled the device at the time of signature

### Recommended implementation shape

#### 1. Introduce a signing request contract

Add a dedicated shared contract in `shared/contracts`, for example:

- `SigningRequestContract.ts`

Core fields:

- `requestId`
- `targetRecordId`
- `targetRecordType`
- `caseId`
- `interactionId`
- `interviewId`
- `requestedByUserId`
- `requestedForUserId`
- `requestedForRole`
- `status` with values like `Pending`, `Opened`, `Signed`, `Cancelled`, `Expired`
- `requestedAt`
- `openedAt`
- `signedAt`
- `deviceAttestationAccepted`
- `signatureContentVersionId`
- `auditEntityId`

Optional later field:

- `requestedForParticipantId`

Do not make participant signing the first design center for this contract.

This contract should be server-owned. The browser should not invent the lifecycle on its own.

#### 2. Add server endpoints for request lifecycle

Add endpoints under `server/app/api`, for example:

- `POST /api/signing-requests`
- `GET /api/signing-requests/{requestId}`
- `POST /api/signing-requests/{requestId}/open`
- `POST /api/signing-requests/{requestId}/complete`

Lifecycle rules:

- `create` issues the request and writes an initial audit record.
- `open` records that the signer reached the request.
- `complete` validates attestation, uploads the signature artifact, writes the final audit entry, and updates the underlying Salesforce record linkage.

For the first pass, `create` should be invokable from these surfaces:

- manager/co-sign review action at the bottom of a note or interview
- treatment-plan-related signature requests created for Clinician, Case Manager, or Peer Support assignees based on goal modality

The existing `/api/signatures/upload` route can remain as an internal helper or low-level utility, but it should no longer be the business workflow entry point.

#### 3. Couple upload and audit on the server

On request completion, the server should perform these steps as one authoritative flow:

1. validate the signing request is still pending
2. validate attestation checkbox / statement was accepted
3. create `ContentVersion`
4. update the signing request state
5. write `Audit_Log__c` with request id, target record id, signer identity, and timestamps

Even if full transactionality across every downstream record is not available, the authoritative event sequence should be server-side instead of client-side.

#### 4. Add a signer-facing mobile page

Create a focused mobile component such as:

- `web/src/components/SigningRequestPage.tsx`

Responsibilities:

- load request context
- display what the user is signing
- display the full note or interview review context, including related goals, benefits, diagnoses, and CPT codes when present
- show the attestation statement
- collect the signature via the existing `SignaturePad` component
- submit completion through the signing-request API

The attestation text should be explicit, for example that the signer is the assigned authenticated user and currently has control of the device being used to sign.

### PWA parity note

When interviews are completed in the PWA, the same signing-request model should be used for deferred Clinician, Case Manager, and Peer Support signatures. Do not build a separate PWA-only "present, sign now" shortcut that diverges from the compliance model above.

If a durable Salesforce object becomes necessary later, the PWA contract can stay stable while the server changes its backing store.

## Implementation Map

This is the smallest practical file-by-file map to turn the plan into working code.

### Slice 1: Make case review open a real detail view

Backend files:

- `server/app/salesforce/interaction_summary_service.py`
  - widen the case-timeline query
  - add a detail fetch method by interaction id
  - hydrate linked interview and related-record context where possible
- `server/app/api/interaction_summary.py`
  - add explicit timeline response models
  - add `GET /api/interaction-summary/{interactionId}`
- `shared/contracts/index.ts`
  - export the new timeline/detail contracts
- `shared/contracts/InteractionTimelineContract.ts`
  - new file
- `shared/contracts/InteractionDetailContract.ts`
  - new file

Frontend files:

- `web/src/services/interactionSummaryService.ts`
  - split list and detail DTOs
  - add `getInteractionDetail(interactionId)`
- `web/src/components/InteractionHistory.tsx`
  - make rows clickable
  - add selected-interaction state
  - open a detail surface instead of only showing passive notes
- `web/src/components/InteractionDetailPanel.tsx`
  - new file
  - fetch and render the detail payload
- `web/src/components/MyCasesPage.tsx`
  - only if needed for parent-level state or navigation cleanup

Acceptance criteria:

- tapping an interaction row opens a detail surface
- the detail surface shows full note/interview review data
- the detail surface shows related records when available
- the detail surface does not break if some related records are absent

### Slice 2: Add related review context for parity

Backend files:

- `server/app/salesforce/interaction_summary_service.py`
  - hydrate goals, benefits, diagnoses, CPT codes, and linked documents
- any existing Salesforce helper services already used by cases, assessments, or doc fetches

Frontend files:

- `web/src/components/InteractionDetailPanel.tsx`
  - add sections for:
    - goals
    - benefits
    - diagnoses
    - CPT codes
    - linked documents

Acceptance criteria:

- a reviewer can open one screen in the PWA and understand the note/interview plus its related artifacts
- the detail view is useful for both manager/co-sign review and assignee signature review

### Slice 3: Introduce signing requests for authenticated staff users

Backend files:

- `shared/contracts/SigningRequestContract.ts`
  - new file
- `shared/contracts/index.ts`
  - export the new contract
- `server/app/api/signing_requests.py`
  - new file
  - request creation, open, and complete endpoints
- `server/app/main.py`
  - mount the signing-request router
- `server/app/salesforce/audit_log_service.py`
  - add structured signing-request audit helpers if needed
- `server/app/api/signatures.py`
  - keep as low-level helper or call from the signing-request completion flow

Frontend files:

- `web/src/components/InteractionDetailPanel.tsx`
  - add `Request Signature` / `Open Assigned Signature` actions
- `web/src/components/SigningRequestPage.tsx`
  - new file
- `web/src/services/signingRequestService.ts`
  - new file

Acceptance criteria:

- a note/interview can assign a signature to CM, Peer, Clinician, or Manager approver
- the request can be opened by the assignee in the PWA
- the assignee can review context and complete the request
- the server writes the audit trail and links the uploaded signature artifact

### Slice 4: Make signature capture actually live in the running app shell

Current blockers:

- `web/src/components/SignaturePad.tsx` exists but is not mounted in the active user flow
- `web/src/services/signatureService.ts` exists but is not wired into the real review/signing UI
- `web/src/lib/syncService.ts` is the sync path App actually starts, but it does not process `SignatureRecord`

Required files:

- `web/src/components/SignaturePad.tsx`
  - reuse inside `SigningRequestPage`
- `web/src/services/signatureService.ts`
  - keep or simplify around the signing-request flow
- `web/src/lib/syncService.ts`
  - add `SignatureRecord` handling if offline queueing remains part of the design
- `web/src/App.tsx`
  - confirm the active shell still starts the correct sync path after the change

Acceptance criteria:

- captured signatures are actually flushed by the running app shell
- failed uploads remain retryable
- the live path no longer depends on dead or duplicate sync plumbing

## Week-One Execution

If you want to start immediately, do the first week in this order:

1. Create `InteractionTimelineContract.ts` and `InteractionDetailContract.ts`.
2. Widen `interaction_summary_service.py` and `interaction_summary.py` for richer timeline data.
3. Add `InteractionDetailPanel.tsx` and make `InteractionHistory.tsx` open it.
4. Add related-record sections to the detail panel for goals, benefits, diagnoses, CPT codes, and documents.
5. Create `SigningRequestContract.ts`, `signing_requests.py`, and a minimal `signingRequestService.ts`.
6. Mount `SigningRequestPage.tsx` from the interaction detail panel.
7. Move signature flushing into `syncService.ts` or remove duplicate sync logic so there is one live path.

## Ticket Breakdown

If you want to turn this into actionable tickets, use this breakdown:

1. `PWA-1`: Widen interaction timeline API and shared contracts.
2. `PWA-2`: Add interaction detail panel with full note/interview display.
3. `PWA-3`: Hydrate related review context: goals, benefits, diagnoses, CPT codes, linked docs.
4. `PWA-4`: Add authenticated staff signing-request contract and API.
5. `PWA-5`: Add signer review/signature page with device-control attestation.
6. `PWA-6`: Unify active sync path so signature uploads are actually live.

## How To Execute The Work

Use this operating rhythm so the planning does not stall out:

1. Treat Slice 1 as the first shippable milestone. It gives visible product value before signing is finished.
2. For each slice, define the backend contract first, then the frontend service, then the UI.
3. Keep each slice behind one narrow acceptance test: open detail, load related records, create request, complete request.
4. Do not start participant/client signing until authenticated staff signing is complete and stable.
5. Keep assignment and Salesforce notifications as existing workflow inputs, and let the PWA become the assignee review-and-sign surface.
## Recommended Execution Order

### Phase 1

Widen the case timeline contract and UI only.

Deliverables:

- widened interaction list API
- shared timeline contract
- interaction detail panel

This is the fastest route to making case review feel alive.

### Phase 2

- detail DTO
- linked interview/document actions
- related-record hydration for goals, benefits, diagnoses, and CPT codes

This turns the timeline into a usable review workspace instead of a note dump.

### Phase 3

Introduce the server-owned signing request lifecycle for authenticated staff users.

Deliverables:

- detail DTO
- signing request contract
- signing request API endpoints
- server-side audit coupling
- signer-facing mobile page

This phase should include moving signature syncing into the active `syncService` path so captured signatures are actually flushed by the running app shell.

### Phase 4

Connect signing requests from the interaction detail panel.

Deliverables:

- `Request Signature` action from case review
- deep link or in-app navigation to signer flow
- request status reflected back on the interaction/interview detail panel

## Risks And Guardrails

- Do not keep expanding the current `InteractionSummaryRequest` into a mixed create/list/detail contract. Separate DTOs now.
- Do not let the browser be the source of truth for signing lifecycle state.
- Do not treat `ContentVersion` creation as proof of compliant signing by itself.
- Do not make the interaction detail endpoint fail hard when linked interview/document hydration is missing.
- Do not force the initial detail UX into a large routing rewrite; a focused panel or full-screen sheet is enough for the first pass.

## Immediate Next Changes

If implementation starts now, the first concrete code changes should be:

1. widen `InteractionSummary` query + API response in the backend
2. add timeline/detail shared contracts in `shared/contracts`
3. make `InteractionHistory` cards clickable and add an `InteractionDetailPanel`
4. add a server-side `SigningRequestContract` and request lifecycle endpoints before changing the mobile signature UX

This order gets visible value into case review quickly while preventing the signing flow from hardening around the current thin upload-only path.