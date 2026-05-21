# Milestone vM009: Retrieval-First Support Answers & Search Ops

**Status:** ✅ SHIPPED 2026-05-21
**Phases:** 1-8
**Total Plans:** 14

## Overview

Turned the Knowledge Base substrate from M008 into product-visible retrieval value through a
host-owned hybrid retrieval layer, trustworthy operator search, grounded drafting with citations,
and bounded telemetry plus durable gap signals for future KB maintenance work.

## Phases

### Phase 1: Hybrid Retrieval Corpus & APIs

**Goal**: Build a host-owned retrieval layer over published Knowledge Base content and resolved
support evidence.
**Depends on**: Nothing
**Plans**: 2 plans

Plans:

- [x] `M009-S01-01` - Add retrieval corpus storage, indexing workers, and resolved-case evidence separation
- [x] `M009-S01-02` - Build the internal retrieval facade, ranking contract, and recovery tasks

**Details:**
- Added retrieval corpus schema support for canonical KB chunks and separate resolved-case
  evidence storage.
- Extended KB chunk indexing and added resolved-conversation indexing through Oban-backed workers.
- Added `Cairnloop.Retrieval`, normalized result contracts, deterministic ranking, and recovery Mix
  tasks for rebuild and replay flows.

### Phase 2: Operator Search Experience

**Goal**: Make grounded retrieval feel fast and trustworthy for operators inside the dashboard.
**Depends on**: Phase 1
**Plans**: 2 plans

Plans:

- [x] `M009-S02-01` - Replace the placeholder palette with retrieval-backed search results and trust cues
- [x] `M009-S02-02` - Add the keyboard-first operator workflow, preview behavior, and scoped mounting

**Details:**
- Rebuilt the search modal around `Cairnloop.Retrieval.search/2` with explicit `Knowledge Base`
  and `Similar resolved cases` sections.
- Added presenter-owned recency, trust, and citation cues.
- Added keyboard navigation, open behavior, and host-surface mounting from Inbox, Conversation,
  and Settings.

### Phase 3: Grounded Drafting & Citations

**Goal**: Improve draft quality by grounding AI responses in retrieved evidence before operator
review.
**Depends on**: Phase 1
**Plans**: 2 plans

Plans:

- [x] `M009-S03-01` - Add the grounded drafting backend contract and structured durable draft state
- [x] `M009-S03-02` - Add the operator-facing evidence rail, draft states, and clarification or escalation presentation

**Details:**
- Added `ground_for_draft/2` with strong, clarification, and escalation assessments.
- Replaced blob-only draft persistence with structured draft artifacts and evidence snapshots.
- Reworked the operator review flow so grounded replies, clarifications, and escalations expose
  inspectable evidence instead of looking like undifferentiated AI output.

### Phase 4: Retrieval Telemetry & Gap Signals

**Goal**: Make retrieval quality inspectable and preserve evidence for the next knowledge-gap
milestone.
**Depends on**: Phase 1, Phase 2, Phase 3
**Plans**: 3 plans

Plans:

- [x] `M009-S04-01` - Add the stable retrieval telemetry contract and bounded diagnostic taxonomy
- [x] `M009-S04-02` - Add durable gap-event storage, retention, and recorder semantics
- [x] `M009-S04-03` - Wire scoped search and draft boundaries to emit gap evidence from real product seams

**Details:**
- Added bounded `[:cairnloop, :retrieval, ...]` telemetry with source-aware ranking summaries.
- Added append-only gap-event persistence and Oban-backed retention.
- Wired search and draft boundaries to record no-hit, retrieval-error, weak-grounding, and
  policy-limit evidence from the owning application seams.

### Phase 5: Search Scope Enforcement & Operator Search Closure

**Goal**: Close the remaining operator-search blocker by enforcing tenant and visibility scope on
every mounted surface and provider path.
**Depends on**: Phase 2, Phase 4
**Plans**: 2 plans

Plans:

- [x] `M009-S05-01` - Enforce fail-closed search mounting and provider-side scope before ranking
- [x] `M009-S05-02` - Backfill Phase 2 verification and traceability closure

**Details:**
- Inbox and Settings now pass `host_user_id` into the shared search component.
- Retrieval fails closed on unsafe unscoped dashboard searches.
- Phase 2 gained explicit requirement-level verification and updated validation state.

### Phase 6: Retrieval Corpus Verification Closure

**Goal**: Convert Phase 1 implementation work into auditable closure evidence.
**Depends on**: Phase 1
**Plans**: 1 plan

Plans:

- [x] `M009-S06-01` - Backfill the Phase 1 verification artifact, rerun focused suites, and repair traceability

**Details:**
- Added `M009-S01-VERIFICATION.md` and rewrote validation state for the retrieval corpus work.
- Recorded the environment-blocked realism lane explicitly instead of overstating proof quality.
- Moved `M009-REQ-01..03` to verified traceability.

### Phase 7: Grounded Drafting Verification Closure

**Goal**: Convert Phase 3 implementation work into auditable closure evidence.
**Depends on**: Phase 3
**Plans**: 1 plan

Plans:

- [x] `M009-S07-01` - Backfill the Phase 3 verification artifact, rerun focused suites, and repair traceability

**Details:**
- Added `M009-S03-VERIFICATION.md` and updated validation state for grounded drafting.
- Recorded manual editorial closure checks and the environment-blocked realism lane.
- Moved `M009-REQ-06` and `M009-REQ-07` to verified traceability.

### Phase 8: Gap Signal Semantics & Telemetry Closure

**Goal**: Align gap-event semantics with the retrieval contract and close the remaining Phase 4
audit findings.
**Depends on**: Phase 4, Phase 5
**Plans**: 1 plan

Plans:

- [x] `M009-S08-01` - Repair durable gap semantics, add assistive-only dedupe, and backfill Phase 4 closure artifacts

**Details:**
- Repaired durable gap-event semantics so access contract and UI context are stored separately.
- Added assistive-only search dedupe and a migration that preserves legacy rows.
- Backfilled `M009-S04-VERIFICATION.md`, refreshed validation, and moved `M009-REQ-08` and
  `M009-REQ-09` to verified traceability.

## Milestone Summary

**Key Accomplishments:**

- Built a host-owned hybrid retrieval corpus over Knowledge Base content and resolved support
  evidence.
- Turned retrieval into a keyboard-first operator search experience with clear trust and source
  cues.
- Grounded AI drafts in citation-backed retrieval evidence with explicit clarification and
  escalation states.
- Added bounded retrieval telemetry and durable gap-event storage for future KB maintenance loops.
- Closed the remaining search-scope safety blocker on non-conversation surfaces.
- Backfilled verification and validation artifacts so all nine milestone requirements are auditable
  and traced as verified.

**Key Decisions:**

- Keep retrieval host-owned with `pgvector`, PostgreSQL full-text search, and Oban.
- Preserve a hard canonical-versus-assistive split between KB content and resolved-case evidence.
- Move trust left: grounded retrieval quality must be inspectable before broader AI tool autonomy.

**Issues Resolved:**

- Replaced placeholder search UI behavior with real retrieval-backed operator flows.
- Closed the non-conversation scope enforcement gap in operator search.
- Closed missing verification artifacts for the original retrieval, drafting, and telemetry phases.

**Issues Deferred:**

- Repo-backed realism lanes remain environment-blocked in this workspace by unavailable
  `Cairnloop.Repo`.
- Search fail-closed protection still depends on duplicated mounted-surface guard lists that should
  later be centralized.

**Technical Debt Incurred:**

- Several closure artifacts carry residual verification risk instead of live DB-backed proof.
- Search-surface scope guards exist in more than one place and should be normalized before the next
  major retrieval surface expansion.

---

_For current project status, see `.planning/ROADMAP.md` and `.planning/PROJECT.md`._
