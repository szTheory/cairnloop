---
milestone: M009
audited: 2026-05-21T19:20:00Z
status: tech_debt
scores:
  requirements: 9/9
  phases: 8/8
  integration: 9/9
  flows: 4/4
gaps:
  requirements: []
  integration: []
  flows: []
tech_debt:
  - phase: "M009 milestone"
    items:
      - "Several closure artifacts still record residual verification risk because the repo-backed realism lanes are environment-blocked in this workspace by an unavailable `Cairnloop.Repo`."
      - "Scope enforcement for operator search is correct on current surfaces, but the fail-closed guard still depends on hard-coded surface lists in both `SearchModalComponent` and `Cairnloop.Retrieval`."
nyquist:
  compliant_phases: ["M009-S01", "M009-S02", "M009-S03", "M009-S04", "M009-S05", "M009-S06", "M009-S07", "M009-S08"]
  partial_phases: []
  missing_phases: []
  overall: "compliant"
---

# M009 Milestone Audit

## Outcome

**Status: `tech_debt`**

M009 is product-complete and audit-complete enough to archive. All milestone requirements are now
satisfied through the 3-source closure matrix:

1. `REQUIREMENTS.md` marks `M009-REQ-01` through `M009-REQ-09` verified.
2. The relevant verification artifacts exist for the original implementation phases:
   `M009-S01`, `M009-S02`, `M009-S03`, and `M009-S04`.
3. The closure summaries for `M009-S05`, `M009-S06`, `M009-S07`, and `M009-S08` now carry
   `requirements-completed` frontmatter, and each of those closure phases now has a phase-local
   `VERIFICATION.md` and `VALIDATION.md` surface.

This milestone does **not** remain in `gaps_found`, because no unsatisfied requirement, broken
cross-phase integration, or incomplete end-to-end flow remains. It also does **not** cleanly reach
`passed`, because two non-blocking debt items remain:

1. The repo-backed realism lanes recorded in the retrieval, grounded-drafting, and gap-semantics
   closure artifacts are still environment-blocked in this workspace by an unavailable
   `Cairnloop.Repo`.
2. Operator-search fail-closed behavior still depends on duplicated surface-list guards in
   `SearchModalComponent` and `Cairnloop.Retrieval`.

## Requirements Coverage

| Requirement | Assigned Phase | REQUIREMENTS.md | VERIFICATION.md | SUMMARY Frontmatter | Final Status | Notes |
|-------------|----------------|-----------------|-----------------|---------------------|--------------|-------|
| M009-REQ-01 | Phase 6 (M009) | `[x]` Verified | passed via `M009-S01-VERIFICATION.md` | listed via `M009-S06-01-SUMMARY.md` | satisfied | Retrieval corpus closure is documented and traceable |
| M009-REQ-02 | Phase 6 (M009) | `[x]` Verified | passed via `M009-S01-VERIFICATION.md` | listed via `M009-S06-01-SUMMARY.md` | satisfied | Assistive-vs-canonical split is documented and traceable |
| M009-REQ-03 | Phase 6 (M009) | `[x]` Verified | passed via `M009-S01-VERIFICATION.md` | listed via `M009-S06-01-SUMMARY.md` | satisfied | Async indexing and recovery closure is documented and traceable |
| M009-REQ-04 | Phase 5 (M009) | `[x]` Verified | passed via `M009-S02-VERIFICATION.md` | listed via `M009-S05-02-SUMMARY.md` | satisfied | Operator search is scoped and verified on supported surfaces |
| M009-REQ-05 | Phase 5 (M009) | `[x]` Verified | passed via `M009-S02-VERIFICATION.md` | listed via `M009-S05-02-SUMMARY.md` | satisfied | Filtering-before-ranking and trust cues are verified |
| M009-REQ-06 | Phase 7 (M009) | `[x]` Verified | passed via `M009-S03-VERIFICATION.md` | listed via `M009-S07-01-SUMMARY.md` | satisfied | Grounded drafting closure is documented and traceable |
| M009-REQ-07 | Phase 7 (M009) | `[x]` Verified | passed via `M009-S03-VERIFICATION.md` | listed via `M009-S07-01-SUMMARY.md` | satisfied | Evidence-rail and escalation behavior are documented and traceable |
| M009-REQ-08 | Phase 8 (M009) | `[x]` Verified | passed via `M009-S04-VERIFICATION.md` | listed via `M009-S08-01-SUMMARY.md` | satisfied | Telemetry contract closure is documented and traceable |
| M009-REQ-09 | Phase 8 (M009) | `[x]` Verified | passed via `M009-S04-VERIFICATION.md` | listed via `M009-S08-01-SUMMARY.md` | satisfied | Durable gap-event closure is documented and traceable |

## Phase Evidence

| Phase | Validation State | Verification State | Audit Result | Notes |
|-------|------------------|--------------------|--------------|-------|
| M009-S01 | `verified_with_residual_risk`, Nyquist compliant | Present | Verified | Original retrieval-corpus implementation phase has durable closure evidence |
| M009-S02 | `verified`, Nyquist compliant | Present | Verified | Original operator-search phase has durable closure evidence |
| M009-S03 | `verified_with_residual_risk`, Nyquist compliant | Present | Verified | Original grounded-drafting phase has durable closure evidence |
| M009-S04 | `verified_with_residual_risk`, Nyquist compliant | Present | Verified | Original telemetry/gap-signal phase has durable closure evidence |
| M009-S05 | `verified`, Nyquist compliant | Present | Verified | Phase-local verification gap is now closed |
| M009-S06 | `verified_with_residual_risk`, Nyquist compliant | Present | Verified | Phase-local validation and verification now exist |
| M009-S07 | `verified_with_residual_risk`, Nyquist compliant | Present | Verified | Phase-local validation and verification now exist |
| M009-S08 | `verified_with_residual_risk`, Nyquist compliant | Present | Verified | Phase-local validation and verification now exist |

## Integration Check

### Confirmed cross-phase wiring

- **KB publish -> async indexing -> retrieval corpus** is wired through
  `KnowledgeBase.publish_revision/1`, chunk-revision indexing, and the retrieval facade/provider
  path.
- **Conversation resolve -> resolved-case indexing -> operator search** is wired through
  `Chat.resolve_conversation/2`, `IndexResolvedConversation`, and the shared search modal.
- **Draft worker -> retrieval grounding -> structured proposal -> evidence rail** is wired through
  `DraftWorker`, `ScoriaEngine`, durable draft persistence, and `ConversationLive`.
- **Retrieval telemetry and durable gap recording** are wired from both search and draft
  boundaries.

### Current blocker status

- **No current integration blocker found.**
- No broken end-to-end flow was identified in the current milestone surface.

## Verification Evidence Used

- Phase verification artifacts:
  - `.planning/milestones/M009-phases/M009-S01/M009-S01-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S02/M009-S02-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S03/M009-S03-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S04/M009-S04-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S05/M009-S05-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S06/M009-S06-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S07/M009-S07-VERIFICATION.md`
  - `.planning/milestones/M009-phases/M009-S08/M009-S08-VERIFICATION.md`
- Phase validation artifacts:
  - `.planning/milestones/M009-phases/M009-S01/M009-S01-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S02/M009-S02-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S03/M009-S03-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S05/M009-S05-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S06/M009-S06-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S07/M009-S07-VALIDATION.md`
  - `.planning/milestones/M009-phases/M009-S08/M009-S08-VALIDATION.md`
- Current milestone traceability:
  - `.planning/REQUIREMENTS.md`
  - `.planning/ROADMAP.md`

## Nyquist Discovery

Nyquist evidence is now complete across the full milestone:

- `M009-S01`: compliant
- `M009-S02`: compliant
- `M009-S03`: compliant
- `M009-S04`: compliant
- `M009-S05`: compliant
- `M009-S06`: compliant
- `M009-S07`: compliant
- `M009-S08`: compliant

Overall Nyquist status: **compliant**

## Closure Recommendation

M009 is ready for milestone archival if you accept the remaining non-blocking debt:

1. Environment-blocked realism lanes that prevent fully live repo-backed proof in this workspace.
2. Duplicated search-surface guard lists that should eventually be centralized.

Operationally, this is now an **archiveable `tech_debt` milestone**, not a blocked one.
