# Interview Template Governance: Executive Summary

**Date**: November 11, 2025  
**Status**: Strategy Complete; Ready for Phase 1 Implementation  
**Audience**: Product Owners, Case Manager Supervisors, Platform Team

---

## The Problem You Identified

You have a rich interview template system (InterviewTemplate, InterviewTemplateVersion, InterviewQuestion, Interview, InterviewAnswer), but without governance, it's becoming unwieldy:

- ❌ **Question Sprawl**: Duplicate questions across templates; no reuse tracking
- ❌ **In-Progress Chaos**: Draft templates accumulate; no clear archival policy
- ❌ **Mobile Uncertainty**: No central way to track which templates are safe for offline
- ❌ **Change Blindness**: Templates evolve but no change history or diff visibility
- ❌ **Compliance Risk**: Protected questions (e.g., suicide risk, substance use) editable by any CM
- ❌ **No Analytics**: Can't identify zombie questions or templates causing abandonment

---

## The Solution: "Question Library as Single Source of Truth"

### Core Idea (3 Pillars)

#### 1. **InterviewQuestionsLibrary as Canonical Registry**
- Extend existing object with metadata (Question_Key__c, Data_Type__c, Maps_To_Object/Field__c, etc.)
- Each definition has a stable, immutable Question_Key__c (e.g., `DEMOG.DOB`, `RISK.SUICIDALITY`)
- Link to `Latest_Approved_Version__c` (an InterviewQuestion record)
- Non-Steward users cannot edit Protected__c questions

#### 2. **InterviewQuestion as Versioned Renderable**
- Questions are versioned: `(Question_Key + Version_Number) = unique`
- Statuses: Draft → In Review → Approved → Deprecated
- Each version is immutable once published
- Historical interviews always reference exact question version used

#### 3. **Template Lifecycle with State Machine + Linter**
- Status: Draft → In Review → Published → Retired → Archived
- Independent `Is_Active__c` toggle: can deactivate without retiring
- **Pre-publish Linter gate**: templates can't publish if they have:
  - Orphan questions (not linked to library)
  - Field binding errors
  - Missing compliance flags
  - Performance issues
- **Auto-archive stale drafts**: old drafts auto-hidden after 14 days (user can opt-out)

#### 4. **Mobile Manifests**
- On publish, generate Active_Manifest__c (JSON payload)
- Includes all questions + value sets + backward-compat rules
- Mobile clients cache by content hash; no sync if unchanged

#### 5. **"Propose New Question" Intake**
- Nudge CMs toward library reuse, not custom one-offs
- Fuzzy-match against existing definitions (if >75% similar, suggest reuse)
- Route proposals to Stewards queue for approval
- On approval, auto-create library definition + v1

#### 6. **Enhanced Management Home**
- Show: Status, Family, Program, Mobile pill, Lint status, Last Used, Draft age
- Saved Views: My Drafts, Needs Review, Mobile Ready, Stale Drafts, Recently Used
- Inline actions: Clone, Deactivate, Retire, Submit for Review, Run Linter, View Change Summary

#### 7. **Analytics Dashboards**
- Leaderboards: Most reused questions, Zombie questions, Templates causing abandonment
- Roll-up metrics: Times_Used_In_Published_Templates, Times_Answered_Last_90_Days, Avg_Completion_Time

---

## Why This Works

### ✅ Prevents Question Sprawl
- Question_Key__c + fuzzy-match de-dupe blocks duplicates
- Steward approval process ensures intentional creation
- Analytics show unused questions (zombie cleanup)

### ✅ Keeps In-Progress Clean
- 14-day stale draft auto-archive (with opt-out)
- Do_Not_Archive__c field for long-term work
- One-click restore if needed

### ✅ Mobile-Ready by Design
- Manifest is immutable snapshot at publish time
- Content hash enables deterministic sync
- Backward-compat rules keep old clients working

### ✅ Clear Change History
- Each question version immutable; Change_Summary__c JSON captures what changed
- Templates track Previous_Version_Id__c; diffing shows added/removed/modified questions
- Change Summary modal shows diff on publish

### ✅ Compliance Guardrails Built-In
- Protected__c questions only editable by Stewards
- Validation rules enforce this at database level
- Compliance_Flags__c (PHI, PII, Regulated, Suicide, Substance) trigger consent checks

### ✅ Reuse-First Culture
- Propose New Question wizard makes library reuse obvious
- "Prefer Library" banner when free-text alternatives exist
- Leaderboards celebrate reused questions (social proof)

### ✅ Steward-Light Operations
- Linter automates quality checks (not humans)
- Scheduled flows auto-archive old drafts (not humans)
- Permission Sets gate approvals (clear responsibility)

---

## What's Documented

We've created **5 comprehensive guides** in `docs/`:

### 1. **ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md** (15 KB)
- Full architecture (10 sections)
- Object schemas with fields, types, validation rules
- State machines and linter checks
- Mobile manifests and backward-compat rules
- 8-week phased implementation roadmap
- Success metrics and risk mitigation

### 2. **ADR-0002-DESIGN-TRADE-OFFS.md** (12 KB)
- **10 key design decisions**, each with:
  - Options evaluated (alternative approaches)
  - Decision rationale (why chosen)
  - Related decisions (cross-references)
- Examples: Why extend InterviewQuestionsLibrary vs. new object? Why status + is_active toggle? Why JSON manifest vs. dynamic queries?

### 3. **INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md** (8 KB)
- **Cheat sheet**: Field specs, validation rules, permission sets
- Linter service skeleton (Apex pseudo-code)
- Flow diagrams (status transitions, proposal intake)
- Manifest JSON schema
- Testing checklist
- Deployment sequence

### 4. **INTERVIEW-GOVERNANCE-MIGRATION.md** (10 KB)
- **Step-by-step data prep** for Phase 1
- Backfill InterviewQuestionsLibrary from existing questions
- Assign stable Question_Key__c values
- Validate data integrity
- Rollback plan (if needed)

### 5. **INTERVIEW-GOVERNANCE-QUICK-START.md** (6 KB)
- **Ready-to-go checklist** for Phase 1 (Week 1–2)
- 6 tactical steps:
  1. Validate current schema
  2. Create new fields
  3. Deploy validation rules
  4. Create permission sets
  5. Data migration (backfill)
  6. Deploy triggers
- Phase 2 preview (Linter + Flow)
- Success criteria

---

## Implementation Timeline

### Phase 1: Schema & Governance (Week 1–2) ← **START HERE**
- Add fields to existing objects
- Create validation rules, permission sets
- Backfill InterviewQuestionsLibrary with existing questions
- Deploy triggers for Last_Used tracking

### Phase 2: Linter & Pre-Publish Flow (Week 3)
- Build TemplateLinterService.cls (7 validation checks)
- Create Template_Publish_Gate Flow
- Create Archive_Stale_Drafts Scheduled Flow

### Phase 3: Question Intake & De-Dupe (Week 4)
- Build "Propose New Question" wizard LWC
- Fuzzy-match logic + steward queue routing

### Phase 4: Mobile Manifest (Week 5)
- Manifest generation + contentHash
- Mobile pill UI component

### Phase 5: Stale Draft Auto-Archive (Week 6)
- Scheduled flow + notifications

### Phase 6: Enhanced Management Home (Week 7–8)
- Columns, saved views, inline actions, change summary modal
- Refactor interviewTemplateManager LWC

### Phase 7: Analytics Dashboard (Week 9)
- Leaderboards, zombie detection, abandonment warnings

### Phase 8: Training & Docs (Week 10)
- Runbooks, demo videos, steward training

---

## Key Numbers

| Metric | Target | Rationale |
|--------|--------|-----------|
| Question Reuse Rate | ≥ 70% | Reused questions = less sprawl |
| Stale Draft % | < 10% | Auto-archive keeps in-progress clean |
| Question Duplication | < 5% | De-dupe logic + library single source of truth |
| Steward Approval SLA | < 24 hours | Keeps template publish velocity high |
| Mobile Template Availability | ≥ 80% | Most templates safe for offline use |
| Linter FAIL Rate | ≤ 5% | Shows linter is appropriately scoped (not too strict) |

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|-----------|
| Stewards overwhelmed by proposals | Medium | Auto-reject >90% similar; steward SLA of 24h |
| Linter too strict; blocks valid templates | Medium | FAIL vs WARN categorization; stakeholder training |
| Mobile clients out-of-sync | Low | Content hash + backward-compat rules + client fallback |
| Users frustrated with new workflow | Medium | Phased rollout (Phase 1 already has most value) + training per phase |
| Schema too complex | Low | Documentation + guided checklists; support channel for questions |

---

## Next Steps

### For You (Platform Team Lead)
1. ✅ Review all 5 docs (they're ready)
2. ✅ Pick a **Phase 1 start date** (e.g., next Monday)
3. ✅ Follow **INTERVIEW-GOVERNANCE-QUICK-START.md** checklist
4. ✅ Create sandbox for testing; avoid touching production yet
5. ✅ Share docs with Stewards + CMs (gather feedback)

### For Stewards (Case Manager Supervisors)
1. 📖 Read **ADR-0002 sections 1–3** (understand the "why")
2. 📋 Skim **INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md** (know what's changing)
3. ❓ Ask questions in #engineering or direct to Platform Team
4. 🎓 Attend Phase 1 kickoff training (we'll walk through changes)

### For Case Managers
1. ⏳ No action yet; Phase 1 is mostly backend
2. 🎓 In Phase 3 (Week 4), you'll use "Propose New Question" wizard
3. 👀 In Phase 6 (Week 7–8), you'll see improved management home UX

---

## Success Looks Like (30 Days Post-Launch)

- ✅ Zero "duplicate question" complaints
- ✅ All new templates use library questions
- ✅ Stewards approve proposals within 24 hours
- ✅ Stale drafts auto-archive without user complaints
- ✅ Mobile manifest deployments smooth + no sync errors
- ✅ Team morale high ("finally, a clean way to manage questions!")
- ✅ Leaderboard shows that top 5 questions account for >60% of template usage

---

## Questions?

1. **Architecture questions**: See **ADR-0002** (full rationale)
2. **Design trade-offs**: See **ADR-0002-DESIGN-TRADE-OFFS** (10 decisions explained)
3. **How do I start?**: See **INTERVIEW-GOVERNANCE-QUICK-START** (Phase 1 checklist)
4. **What about my existing data?**: See **INTERVIEW-GOVERNANCE-MIGRATION** (backfill guide)
5. **Real-time help**: Reach out to Platform Team in Slack (#engineering)

---

## Congratulations 🎉

You've built a solid strategy for scalable, maintainable interview templates. This architecture will support your program management vision without requiring constant admin oversight. The governance model is light-touch but prevents chaos, and the analytics give you visibility into what's actually being used.

**Time to implement?** Start with **Phase 1** → it's mostly schema + data prep (low risk, high foundation value). You'll have a solid base for Phases 2–8 to layer on top.

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-11  
**Approvers**: [Pending stakeholder sign-off]
