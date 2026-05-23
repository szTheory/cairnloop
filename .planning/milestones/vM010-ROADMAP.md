# Milestone vM010: KB AI Maintenance

**Status:** ✅ SHIPPED 2026-05-23
**Phases:** 9-12
**Total Plans:** 15

## Overview

vM010 turned retrieval misses, weak grounding, and repeated manual handling into a bounded,
operator-reviewed Knowledge Base maintenance workflow. The shipped lane now starts from durable gap
signals, produces citation-backed draft or revision suggestions, keeps publish behind the canonical
review flow, and lets operators start maintenance directly from live support work.

## Phases

### Phase 9: Gap Candidate Discovery

**Goal**: Operators can work from a ranked queue of durable KB gap candidates instead of raw
retrieval telemetry.
**Depends on**: Phase 8
**Plans**: 3 plans

Plans:

- [x] M010-S01-01: Create the durable gap-candidate read model, memberships, and public query facade.
- [x] M010-S01-02: Build deterministic clustering, manual-handling projection, and refresh or rebuild workers.
- [x] M010-S01-03: Add the ranked KB gaps dashboard and inspectable evidence detail surface.

**Details:**
- Added first-class gap candidate and membership storage with stable identity, freshness, score,
  and evidence-link fields.
- Implemented deterministic clustering, repeated manual-handling projection, and refresh or
  backfill workers driven from durable retrieval signals.
- Shipped `/knowledge-base/gaps` with inspectable “why raised” detail backed by the host-owned
  `KnowledgeAutomation` read model.

### Phase 10: Citation-Backed Draft Suggestions

**Goal**: Operators can safely turn a gap candidate or stale article signal into a grounded KB
draft suggestion.
**Depends on**: Phase 9
**Plans**: 4 plans

Plans:

- [x] M010-S02-01: Establish durable article suggestion storage and the scoped suggestion facade.
- [x] M010-S02-02: Add stale gating, fail-closed evidence bundling, and async suggestion generation.
- [x] M010-S02-03: Build the suggestion review lane and wire gap/article entrypoints into it.
- [x] M010-S02-04: Add explicit manual-edit handoff into the existing editor without side-effect publish.

**Details:**
- Added durable article suggestion storage, bounded evidence validation, and scoped suggestion
  list/get/suggest/dismiss/regenerate seams.
- Implemented stale-revision gating plus async grounded suggestion generation that refuses to
  advance without valid citations or adequate grounding.
- Added `/knowledge-base/suggestions` as the inspectable review surface for article and revision
  suggestions, then wired both gap and KB entrypoints into that shared lane.
- Completed manual-edit handoff so reviewed suggestions preload the editor without creating drafts
  or publishing as a side effect.

### Phase 11: Review-Gated KB Updates

**Goal**: AI-prepared KB drafts and revisions move through an inspectable review task without
weakening the canonical publish boundary.
**Depends on**: Phase 10
**Plans**: 4 plans

Plans:

- [x] M010-S03-01: Establish the durable review-task storage contract and public query APIs.
- [x] M010-S03-02: Implement structured review-task decisions plus separate publish and freshness guards.
- [x] M010-S03-03: Build the task-centric review inbox, action wiring, and shared-lane deep links.
- [x] M010-S03-04: Make the editor review-aware and reflect publish or reindex follow-through back onto review tasks.

**Details:**
- Added `ReviewTask` plus append-only task events so review workflow truth remains distinct from
  suggestion evidence truth.
- Enforced explicit approve, reject, defer, and publish semantics with separate publish-only
  transitions and stale-base guards.
- Replaced the raw suggestion list/detail lane with a task-centric review inbox that keeps evidence,
  workflow state, and follow-through visible together.
- Made the editor review-aware and pushed chunking or reindex follow-through back onto durable
  review-task state.

### Phase 12: In-Thread Quick Fix & Ops Closure

**Goal**: Operators can launch KB maintenance from conversation context, and the maintenance lane
fails closed with bounded operational visibility.
**Depends on**: Phase 11
**Plans**: 4 plans

Plans:

- [x] 12-01: Add conversation-scoped quick-fix identity, typed package preparation, and review-task reuse seams.
- [x] 12-02: Persist shell vs blocked/manual-required fallback and keep blocked quick fixes in the shared lane.
- [x] 12-03: Render durable quick-fix state in the conversation evidence rail and wire thread-side actions.
- [x] 12-04: Emit bounded maintenance telemetry and align thread follow-through states with review-task truth.

**Details:**
- Added conversation-scoped quick-fix suggestion identity plus typed evidence packaging while
  keeping canonical evidence separate from assistive thread context.
- Preserved one shared maintenance lane by reusing `ArticleSuggestion` and `ReviewTask` rather than
  introducing a second quick-fix workflow model.
- Added a dedicated KB maintenance card in `ConversationLive` with typed layer summaries, shell or
  blocked callouts, and manual-draft follow-through.
- Emitted bounded telemetry for gap creation, suggestion outcomes, review decisions, publish, and
  reindex while keeping low-cardinality metadata only.

---

## Milestone Summary

**Decimal Phases:**

- None

**Key Decisions:**

- Keep the maintenance lane fully host-owned inside Phoenix, Ecto, and Oban; Scoria remains optional.
- Preserve the canonical publish boundary: AI can prepare KB work, but never publish it directly.
- Use one shared maintenance lane (`Gap -> Suggest -> Review -> Publish -> Reindex`) rather than
  fragmenting quick fixes or review into separate workflow surfaces.
- Keep telemetry bounded and emit it only from durable workflow seams, never presenter-only state.

**Issues Resolved:**

- Retrieval misses and weak-grounding evidence now converge into stable, inspectable gap candidates.
- Suggested KB work now fails closed when citations or grounding are insufficient.
- Review decisions, publish guards, and follow-through are now explicit and durable instead of
  suggestion-only.
- Operators can now launch KB maintenance directly from a conversation thread without bypassing the
  shared review lane.

**Issues Deferred:**

- Phase 10 and Phase 12 closure artifacts still live partly under the legacy `.planning/phases/...`
  tree instead of one fully normalized milestone-local layout.
- Focused test runs in this workspace still emit unrelated `Chimeway.Repo` missing-database boot noise.

**Technical Debt Incurred:**

- Milestone-local traceability is split across `.planning/milestones/M010-phases/...` and
  `.planning/phases/...` for parts of Phase 10 and Phase 12.
- Repo-backed realism lanes remain environment-blocked in this workspace, so some verification
  remains focused and hermetic rather than full-stack.

---

_For current project status, see `.planning/ROADMAP.md`_
