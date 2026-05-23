# Roadmap: Cairnloop

## Milestones

- ✅ **vM009 Retrieval-First Support Answers & Search Ops** - Phases 1-8 (shipped 2026-05-21)
- 🚧 **vM010 KB AI Maintenance** - Phases 9-12 (in progress)

## Phases

<details>
<summary>✅ vM009 Retrieval-First Support Answers & Search Ops (Phases 1-8) - SHIPPED 2026-05-21</summary>

Archived at `.planning/milestones/vM009-ROADMAP.md`.

</details>

### 🚧 vM010 KB AI Maintenance (In Progress)

**Milestone Goal:** Turn retrieval misses, weak grounding, and repeated manual handling into a safe,
operator-reviewed KB maintenance workflow that preserves the existing publish boundary.

- [x] **Phase 9: Gap Candidate Discovery** - Turn retrieval misses and weak-grounding evidence into ranked, inspectable KB gap candidates. (completed 2026-05-21)
- [x] **Phase 10: Citation-Backed Draft Suggestions** - Generate draft articles and revision suggestions only from grounded evidence. (completed 2026-05-23)
- [x] **Phase 11: Review-Gated KB Updates** - Route AI-prepared KB work through visible review, decision tracking, and the normal publish/reindex path. (completed 2026-05-22)
- [x] **Phase 12: In-Thread Quick Fix & Ops Closure** - Let operators start KB maintenance from live support work while closing telemetry and fail-closed behavior. (completed 2026-05-22)

## Phase Details

### Phase 9: Gap Candidate Discovery
**Goal**: Operators can work from a ranked queue of durable KB gap candidates instead of raw retrieval telemetry.
**Depends on**: Phase 8
**Requirements**: GAP-01, GAP-02, GAP-03
**Success Criteria** (what must be TRUE):
  1. Operator can open a gap dashboard that lists ranked candidates raised from retrieval no-hits, weak grounding, and repeated manual handling.
  2. Related evidence is clustered into one stable candidate identity with freshness metadata and supporting evidence counts.
  3. Operator can inspect why a candidate exists, including the underlying retrieval events and similar-case evidence.
**Plans**: 3 plans
Plans:
- [x] `M010-S01-01-PLAN.md` — Create the durable gap-candidate read model, memberships, and public query facade.
- [x] `M010-S01-02-PLAN.md` — Build deterministic clustering, manual-handling projection, and refresh or rebuild workers.
- [x] `M010-S01-03-PLAN.md` — Add the ranked KB gaps dashboard and inspectable evidence detail surface.
**UI hint**: yes

### Phase 10: Citation-Backed Draft Suggestions
**Goal**: Operators can safely turn a gap candidate or stale article signal into a grounded KB draft suggestion.
**Depends on**: Phase 9
**Requirements**: DRAFT-01, DRAFT-02, DRAFT-03
**Success Criteria** (what must be TRUE):
  1. Operator can generate a proposed new KB article from a selected gap candidate using citation-backed evidence only.
  2. Operator can generate a suggested revision when published KB content appears stale or incomplete against retrieval evidence.
  3. The system refuses to create or advance suggestions when citation anchors are missing or grounding is below the milestone threshold.
**Plans**: TBD

### Phase 11: Review-Gated KB Updates
**Goal**: AI-prepared KB drafts and revisions move through an inspectable review task without weakening the canonical publish boundary.
**Depends on**: Phase 10
**Requirements**: REVIEW-01, REVIEW-02, REVIEW-03, OPS-02
**Success Criteria** (what must be TRUE):
  1. Operator can review a suggested article or revision with visible evidence, citation anchors, and a proposed draft body or diff.
  2. Operator can approve, reject, or edit-before-publish a review task, and AI suggestions cannot bypass the existing KB review flow.
  3. Approved updates follow the normal revision publish and reindex path so retrieval reflects the new canonical KB content.
  4. Review task state transitions, decision metadata, and reindex follow-up work are durably recorded.
**Plans**: 4/4 plans complete
Plans:
- [x] `M010-S03-01-PLAN.md` — Establish the durable review-task storage contract and public query APIs before approval or UI work begins.
- [x] `M010-S03-02-PLAN.md` — Implement structured review-task decisions plus separate publish and freshness guards.
- [x] `M010-S03-03-PLAN.md` — Build the task-centric review inbox, action wiring, and shared-lane deep links.
- [x] `M010-S03-04-PLAN.md` — Make the editor review-aware and reflect publish or reindex follow-through back onto review tasks.
**UI hint**: yes

### Phase 12: In-Thread Quick Fix & Ops Closure
**Goal**: Operators can launch KB maintenance from conversation context, and the maintenance lane fails closed with bounded operational visibility.
**Depends on**: Phase 11
**Requirements**: OPS-01, OPS-03
**Success Criteria** (what must be TRUE):
  1. Operator can start a KB draft directly from conversation evidence inside the support workflow.
  2. If conversation evidence or grounded support is insufficient, the system falls back to a draft shell or manual path with an explicit operator-visible reason.
  3. The system emits bounded telemetry for gap creation, suggestion outcomes, review decisions, and publish or reindex follow-through.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 9. Gap Candidate Discovery | 3/3 | Complete | 2026-05-21 |
| 10. Citation-Backed Draft Suggestions | 4/4 | Complete   | 2026-05-23 |
| 11. Review-Gated KB Updates | 4/4 | Complete | 2026-05-22 |
| 12. In-Thread Quick Fix & Ops Closure | 4/4 | Complete    | 2026-05-22 |
