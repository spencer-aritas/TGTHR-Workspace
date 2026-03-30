# Interview Template Contract Audit

Date: 2026-03-28
Scope: `benefits` sandbox, PWA shared contracts, Salesforce interview/template consumers

## Why this audit exists

A new Interview Template exposed that the PWA and Salesforce have drifted from a contract-first integration model to a compatibility-and-fallback model. The immediate goal of this audit is to identify the highest-risk seams where template metadata, API names, or object names are guessed instead of derived from a live source of truth.

## Product surface priority

The current production shape is narrower than a full mobile intake platform.

1. The only true PWA intake flow today is the quick field-service-style path launched from the New Client Intake button.
2. The primary day-to-day product surface is completing Interviews, reviewing completed documentation, and signing documentation.
3. Compliance-sensitive requirements cut across those flows: signer control of device, end-to-end UUID continuity, and authoritative audit logging.

This means template governance matters, but the highest-value hardening work is the boundary between interview completion, completed-document visibility, and signature/audit enforcement.

## Live org findings

### 1. Program object naming differs from custom-object assumptions
- The org uses `Program`, not `Program__c`.
- Intake template linkage is currently stored on `Program.Intake_Template__c`.
- Verified live rows:
  - `Outreach & Drop-In` -> `Drop-In and Outreach`
  - `Nest 56` -> `Psycho-Social Intake`
  - `1440 Pine` -> `Psycho-Social Intake`

### 2. Template names are not unique and legacy names are still active
- The org currently contains multiple `InterviewTemplate__c` records named `Comprehensive Clinical Assessment`.
- The org also still contains active/legacy records named `Comprehensive Clinical Intake Assessment` and `Comprehensive Intake Assessment`.
- This means display-label normalization hides real metadata duplication instead of removing it.

### 3. UUID fields are not reliable enough to be treated as always present
- Active templates and active versions exist with `UUID__c = null`.
- Example: active `Psycho-Social Intake` template has a null UUID.
- Example: active `Drop-In and Outreach` version `Outreach Intake v2.00.0` has a null UUID.

### 4. Live enum values do not match PWA contract unions
- `InterviewTemplate.Category__c` includes `Psycho-Social`, which is not represented in the current TypeScript category union.
- `InterviewTemplateVersion.Status__c` includes `Retired`, which is not represented in the current TypeScript version-status union.
- Several policy fields are null in live records, which means client code must tolerate absent policy values.

### 5. Mobile availability is metadata-driven, but the integration still mixes metadata and name-based routing
- Live active mobile template example: `Casey Life Skills - Short Form` with active version `Casey Life Skills - Short Form v1`.
- Older intake flows still depend on template-name fallbacks instead of only using `Program.Intake_Template__c` and the active version tied to that template.

## Local contract drift

### PWA contracts are stricter than the live org
- `pwa-sync-starter/shared/contracts/InterviewTemplateContract.ts`
  - `uuid` and `name` are treated as required on the convenience shape.
  - The category union does not include `Psycho-Social`.
- `pwa-sync-starter/shared/contracts/InterviewTemplateVersionContract.ts`
  - `uuid`, `status`, and `variant` are treated as required on the convenience shape.
  - The status union does not include `Retired`.

These contracts are currently acting more like desired-state typings than live-schema typings.

## Brittle Salesforce seams

### 1. Intake template resolution still falls back to hardcoded names
- `CaseManagerHomeController.resolveIntakeTemplate(...)`
- If `Program.Intake_Template__c` is blank, the code falls back to `Drop-In and Outreach` or `Psycho-Social Intake` by program-name logic.
- It then falls back again to `resolveActiveTemplateVersionIdByName(...)`.
- This is still name-based routing and will remain brittle when templates are renamed, duplicated, or cloned.

### 2. Enrollment logic still keys behavior off template names and fallback program names
- `InterviewCompletionService.createProgramEnrollmentIfApplicable(...)`
- Auto-enrollment is triggered when the template name contains `Psycho-Social Intake`.
- If the program cannot be resolved from current enrollment context, the code falls back to hardcoded program names `1440 Pine` and `Nest 56`.
- This is a policy decision implemented as string matching rather than metadata.

### 3. Label normalization masks duplication instead of eliminating it
- `InterviewTemplateLabelService.normalizeDisplayLabel(...)`
- This keeps UI copy stable, but it also makes several distinct template records appear to be the same logical template.
- That is acceptable as a temporary display shim, but dangerous as a long-term contract boundary.

### 4. Assessment writes still accept dynamic field names at runtime
- `AssessmentService.createAssessment(...)`
- The service accepts `values: Map<String, Object>` and then writes fields by API name after runtime coercion.
- This is safer than unrestricted writes because of `ALLOWED_FIELDS`, but it still leaves the PWA dependent on field-name strings instead of a typed Salesforce-facing DTO.

### 5. Template question metadata is live and powerful, but downstream code still assumes field-name conventions
- `InterviewSessionController` and `InterviewTemplateController` correctly load `API_Name__c` and `Maps_To__c` from `InterviewQuestion__c`.
- However, other parts of the system still use template names and legacy assumptions to decide diagnoses, enrollment, rendering, and carry-forward behavior.

## Most important risks

1. A renamed or duplicated template can silently route users into the wrong behavior because consumers still resolve by template name.
2. A new template category or status can break client assumptions because the TypeScript unions do not reflect live org values.
3. Null UUIDs on live templates/versions can break any path that assumes UUID-backed identity is always available.
4. Dynamic field-name payloads make schema drift harder to detect early because failures move to runtime instead of compile time.

## Signature, audit, and UUID findings

### 1. Existing audit infrastructure is real, but not yet a clean end-to-end contract
- Salesforce already has `RecordAccessService` and `AuditLogService` patterns for PHI access and signature-related events.
- The PWA already has backend audit plumbing in `server/app/middleware/audit_integration.py` and `server/app/salesforce/audit_log_service.py`.
- However, the PWA audit write contract still treats `entityId` as a mixed identifier that may become either `Record_Id__c` or `UUID__c` depending on string shape. That is convenient, but not a strong integration contract.

### 2. Current signature logging is necessary but not sufficient to prove signer control of device
- Existing LWC flows require a signature pad before save in note-style flows, and Salesforce audit code can log signature events.
- That proves a signature was captured and an audit event was written.
- It does not, by itself, prove the signer had active control of the device at the moment of signing.

For compliance, signer-control should be treated as an explicit event in the contract, not just inferred from the presence of a saved signature image.

### 3. UUID generation and identity are not yet canonical across systems
- The PWA local UUID helper is an RFC4122-ish random generator and is not cryptographically strong.
- Live Salesforce data already contains null `UUID__c` values on active templates and versions.
- As a result, UUID is currently important, but not yet trustworthy enough to be the only cross-system key.

### 4. Completed-document review should become easier once interview identity and template routing are stabilized
- The main blocker is not rendering complexity.
- The blocker is whether the completed document can be unambiguously tied back to the correct Interview, InteractionSummary, template version, signer state, and audit trail without fallback logic.

## Practical implications by flow

### Quick intake
- Keep this narrow.
- The quick intake path should only depend on `Program.Intake_Template__c`, the active version under that template, and explicit demographic/account save rules.
- Do not let quick intake become the proving ground for every template/runtime edge case.

### Interview completion
- This is the highest-risk operational seam.
- It currently carries template resolution, answer persistence, carry-forward review, diagnoses/goals policy, doc generation hooks, and downstream signature/audit assumptions.
- It should be the first end-to-end hardening target.

### Completed documentation review
- This should be a lower-lift follow-on once Interview identity, template identity, and document ownership are aligned.
- Review surfaces should be consumers of a canonical completed-document payload, not independent interpreters of legacy fallback data.

### Signing
- Signing needs a stricter compliance contract than "signature image exists".
- The contract should explicitly capture at least:
  - signer user id
  - signer role
  - source record id
  - source interview UUID if present
  - source interaction summary id
  - signed timestamp
  - device/session attestation or user-presence confirmation event
  - whether this was direct sign, co-sign request, deferred sign, or suppressed sign

## Recommended implementation order

1. Harden interview identity and template resolution first.
2. Define a canonical signature/audit event contract that both Salesforce and the PWA use.
3. Make completed-document review consume canonical interview/document identity rather than fallback record lookups.
4. Tighten UUID governance only after the contract specifies where UUID is authoritative versus advisory.

## Recommended hardening order

1. Treat Salesforce metadata as the source of truth and reconcile the shared TypeScript contracts to the live org.
2. Remove name-based template version lookup from intake flows; require routing by `Program.Intake_Template__c` and the active version under that template.
3. Replace template-name policy decisions in enrollment logic with explicit metadata flags or template/program relationships.
4. Keep `InterviewTemplateLabelService` as display-only and stop letting normalized labels influence behavior.
5. Introduce one typed Salesforce-facing assessment/interview submission mapping layer instead of passing dynamic field-name maps from the PWA.
6. Add an org-backed validation step for template-related changes before PWA normalization work is merged.

## Proposed next audit pass

1. Inventory all code paths that branch on `InterviewTemplate__r.Name` or normalized labels.
2. Inventory all places where the PWA depends on UUIDs for templates/versions.
3. Define the minimum canonical template DTO that both Salesforce and the PWA can honor without guessing.
4. Convert one end-to-end flow first: intake template launch and completion.
