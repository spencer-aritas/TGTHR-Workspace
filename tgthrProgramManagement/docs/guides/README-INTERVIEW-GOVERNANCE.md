# Interview Template Governance Documentation

**Status**: ✅ Strategy Complete | Ready for Phase 1 Implementation  
**Last Updated**: November 11, 2025

---

## Quick Navigation

### 🚀 **Want to get started?**
→ Start here: **[INTERVIEW-GOVERNANCE-QUICK-START.md](INTERVIEW-GOVERNANCE-QUICK-START.md)** (Phase 1 checklist, Week 1–2)

### 📖 **Want the full picture?**
→ Read: **[INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md](INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md)** (7-minute overview of all 7 pillars)

### 🏗️ **Want the architecture?**
→ See: **[../decisions/ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md](../decisions/ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md)** (10 sections, full design)

### 🤔 **Want to understand the trade-offs?**
→ Review: **[../decisions/ADR-0002-DESIGN-TRADE-OFFS.md](../decisions/ADR-0002-DESIGN-TRADE-OFFS.md)** (10 design decisions, why each chosen)

### 🔧 **Want field specs, rules, & schema?**
→ Reference: **[INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md](INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md)** (cheat sheet, linter schema, tests)

### 🗄️ **Want to migrate existing data?**
→ Follow: **[INTERVIEW-GOVERNANCE-MIGRATION.md](INTERVIEW-GOVERNANCE-MIGRATION.md)** (step-by-step, Phase 1, Step 5)

---

## The 7-Minute Story

### The Problem
Your interview template system is powerful but unruly:
- Questions duplicate across templates (no single source of truth)
- Draft templates accumulate with no archival policy
- No visibility into which templates are safe for mobile use
- Case managers can't reuse or consolidate questions easily
- Compliance-sensitive questions can be edited by anyone

### The Solution: "Question Library Single Source of Truth"

**7 Pillars**:

1. **InterviewQuestionsLibrary**: Extend existing object with stable `Question_Key__c` (never changes); links to latest approved version
2. **InterviewQuestion Versioning**: Questions are versioned (v1, v2, etc.); immutable once published
3. **Template Lifecycle State Machine**: Draft → In Review → Published → Retired, plus independent `Is_Active` toggle
4. **Pre-Publish Linter Gate**: Blocks templates with orphan questions, field binding errors, or compliance issues
5. **Mobile Manifests**: JSON snapshots published with content hash; immutable; backward-compat rules built-in
6. **"Propose New Question" Intake**: Fuzzy-match de-dupe + steward approval → auto-create library definitions
7. **Enhanced Management Home**: Status, Family, Mobile pill, Lint status, saved views, inline actions, change diffs

### The Impact
- ✅ Question reuse rate > 70% (vs. sprawl today)
- ✅ Stale drafts auto-archived (keeps in-progress clean)
- ✅ Mobile readiness tracked centrally
- ✅ Change history preserved (can diff versions)
- ✅ Compliance guardrails enforced (Protected questions, consent checks)
- ✅ Steward-light operations (linter automates, flows auto-archive)

### The Timeline
- **Phase 1** (Week 1–2): Schema + Governance ← **START HERE**
- **Phase 2** (Week 3): Linter + Pre-Publish Flow
- **Phase 3** (Week 4): Proposal Intake
- **Phase 4** (Week 5): Mobile Manifests
- **Phase 5–7** (Week 6–9): Stale Draft Archival, Management Home UX, Analytics
- **Phase 8** (Week 10): Training & Docs

---

## Document Index

| Document | Length | Best For | Key Content |
|----------|--------|----------|-------------|
| **INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md** | 7 min | Non-technical stakeholders, PMs | 7 pillars, timeline, metrics, next steps |
| **INTERVIEW-GOVERNANCE-QUICK-START.md** | 15 min | Platform engineers ready to code | Phase 1 checklist (6 steps), Phase 2 preview, success criteria |
| **INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md** | 20 min | Implementation teams, QA | Field specs, validation rules, permission sets, tests, linter schema |
| **INTERVIEW-GOVERNANCE-MIGRATION.md** | 20 min | Data engineers, DBAs | Step-by-step data backfill, mapping, validation, rollback |
| **ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md** | 45 min | Architects, long-term maintainers | Full design, object schemas, 10 implementation details, 8-week roadmap |
| **ADR-0002-DESIGN-TRADE-OFFS.md** | 30 min | Product owners, future reviewers | 10 design decisions, alternatives evaluated, rationales |

---

## How to Use These Documents

### Scenario: "I'm a Platform Engineer. I want to start Phase 1 now."

1. Read: **INTERVIEW-GOVERNANCE-QUICK-START.md** (understand the 6 steps)
2. Reference: **INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md** (field specs, validation rules)
3. Use: **INTERVIEW-GOVERNANCE-MIGRATION.md** (Step 5: data backfill)
4. Execute: Follow the checklist (2 weeks)
5. When stuck: Jump to ADR-0002 for full rationale

### Scenario: "I'm a Steward/Supervisor. What's changing for me?"

1. Read: **INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md** (5 min)
2. Skim: **INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md** (section 3: permission sets, your role)
3. Attend: Training in Phase 1 (we'll walk you through it)
4. When curious: Read ADR-0002 sections 1–3

### Scenario: "I'm a Product Owner. Is this the right direction?"

1. Read: **INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md** (7 min)
2. Review: **ADR-0002-DESIGN-TRADE-OFFS.md** (understand trade-offs)
3. Discuss: ADR-0002 sections 5–6 (permission model, sprawl prevention)
4. Validate: Success metrics in ADR-0002 section 11

### Scenario: "I'm maintaining this 6 months from now. How do I extend it?"

1. Read: **ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md** (full context)
2. Reference: **ADR-0002-DESIGN-TRADE-OFFS.md** (understand why decisions were made)
3. Check: INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md (current state schema)
4. When adding features: Update ADR-0002 decision matrix

---

## Key Takeaways

### ✅ What This Governance Model Does

| Goal | How | Benefit |
|------|-----|---------|
| Prevent question sprawl | Question_Key__c + fuzzy-match de-dupe + steward approval | > 70% reuse; < 5% duplication |
| Keep in-progress clean | 14-day stale draft auto-archive + opt-out field | < 10% stale drafts in view |
| Enable mobile safety | Immutable manifests + content hash + backward-compat rules | ≥ 80% templates mobile-ready |
| Track change history | Question versioning + Change_Summary__c JSON + diff modal | Can compare any two versions |
| Enforce compliance | Protected__c field + validation rules + Steward gate | No accidental edits to sensitive Qs |
| Light-touch operations | Linter automation + scheduled flows + permission sets | Stewards < 24h approval SLA |

### ⚠️ What This Does NOT Do

- ❌ Prevent all data entry errors (users can still create bad questions; linter catches most)
- ❌ Automatically migrate existing templates (Phase 1 backfill handles this)
- ❌ Support unlimited customization (design prioritizes governance > flexibility)
- ❌ Replace human stewardship (linter automates checks, not decisions)

### 🎯 Success Metrics

**30 days post-launch**:
- Zero "why is this question duplicated?" complaints
- All new templates use library questions
- Stewards average < 24h approval time
- Stale drafts auto-archive without user complaints
- Mobile manifest deployments smooth (no sync errors)
- Leaderboard shows top 5 questions account for > 60% of templates

---

## Frequently Asked Questions

### Q: When should we start? / What's the risk if we delay?

**A**: Start Phase 1 **immediately** (Week 1–2). No risk of delay, but each week of growth increases migration effort and question sprawl. Phase 1 is mostly schema + data prep (low risk, high foundation value).

### Q: Can we skip phases?

**A**: No. Phases build on each other:
- Phase 1 is foundation (schema, data)
- Phase 2 adds quality gates (linter)
- Phases 3–7 add UX & analytics
- Skipping Phase 2 means bad templates go live

### Q: What if we already have 500+ questions?

**A**: Migration scales. See INTERVIEW-GOVERNANCE-MIGRATION.md for batch processing. Takes ~2–3 hours for mapping + backfill.

### Q: What if Stewards disagree with a design?

**A**: Document in ADR-0002-DESIGN-TRADE-OFFS.md. Most decisions have trade-offs; we chose what works for your workflow. If a stakeholder prefers alternative, update ADR with their rationale.

### Q: How much does this cost?

**A**: Roughly:
- **Schema** (10–15 fields per object): 1 hour
- **Validation rules** (5 rules): 0.5 hours
- **Permission sets** (5 sets): 1 hour
- **Data migration** (backfill): 2–3 hours
- **Code** (linter, flows, triggers): 8–10 hours (Phases 2–3)
- **UX** (management home, analytics): 10–15 hours (Phases 6–7)
- **Training**: 2–3 hours
- **Total**: ~35–45 hours over 10 weeks (~4 hours/week)

### Q: Can we do this in production or do we need a sandbox?

**A**: **Always sandbox first**. Test for 24–48 hours. Then migrate to production with rollback plan. See INTERVIEW-GOVERNANCE-MIGRATION.md section 8 for prod deployment checklist.

---

## Getting Help

| Question | Who | Channel |
|----------|-----|---------|
| "How do I implement Phase 1?" | Platform Team | Slack #engineering |
| "Why was decision X made?" | ADR authors | ADR-0002-DESIGN-TRADE-OFFS.md |
| "What fields do I need?" | Quick Reference | INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md, section 1 |
| "How do I migrate my data?" | Data team | INTERVIEW-GOVERNANCE-MIGRATION.md |
| "Is this the right direction?" | Product Owner | INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md + ADR-0002 |
| "I'm stuck on step 3" | Platform Team | Slack + office hours |

---

## Next Steps

### For Platform Team (Do This Today)
1. ✅ Read **INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md** (understand scope)
2. ✅ Assign **Phase 1 lead** (probably you!)
3. ✅ Pick **Phase 1 start date** (next Monday?)
4. 📅 Schedule **Phase 1 kickoff** (2-hour walkthrough with stakeholders)

### For Stakeholders (Do This By Friday)
1. ✅ Read **INTERVIEW-GOVERNANCE-EXECUTIVE-SUMMARY.md** (7 min)
2. ✅ Share feedback in comments or Slack (any concerns?)
3. ✅ Confirm **Phase 1 dates** with Platform Team

### By Next Week
1. 🏗️ Platform Team: Create sandbox for Phase 1
2. 🧪 Platform Team: Execute Quick-Start checklist (steps 1–2)
3. 📚 Stakeholders: Join Phase 1 kickoff

---

## Document Maintenance

**Who**: Platform Team  
**When**: After each phase completion + quarterly review  
**What to Update**:
- ADR-0002: Add completion notes, lessons learned, metrics
- QUICK-REFERENCE: Add any new fields/rules discovered during implementation
- MIGRATION: Add any gotchas or rollback actions taken
- EXECUTIVE-SUMMARY: Update timeline if phases slip

**Version History**:
- v1.0 (2025-11-11): Initial strategy complete; ready for Phase 1

---

## Summary

You've identified a real problem (question sprawl, governance gaps) and have now designed a **comprehensive, phased solution**. The governance model is:

- ✅ **Opinionated** (clear rules prevent chaos)
- ✅ **Light-touch** (linter & flows automate; humans approve)
- ✅ **Scalable** (grows with your program library)
- ✅ **Compliant** (enforces protected questions, consent, retention)
- ✅ **Well-documented** (6 guides, 10 design decisions)
- ✅ **Phased** (8 weeks, starting immediately)

**Ready? Start with Phase 1.** You've got this. 🚀

---

**Questions?** See documents above or reach out to Platform Team.  
**Ready to implement?** Follow [INTERVIEW-GOVERNANCE-QUICK-START.md](INTERVIEW-GOVERNANCE-QUICK-START.md).
