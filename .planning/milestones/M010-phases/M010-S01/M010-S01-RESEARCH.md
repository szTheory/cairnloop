# Phase M010-S01: Gap Candidate Discovery - Research

**Researched:** 2026-05-21 [VERIFIED: local system date]  
**Domain:** Phoenix/Ecto/Oban gap-candidate discovery over existing retrieval gap events and support workflow evidence [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/M010-KB-AI-MAINTENANCE-SPEC.md]  
**Confidence:** HIGH [VERIFIED: repo code review]  

<phase_requirements>
## Phase Requirements [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `.planning/REQUIREMENTS.md`]

| ID | Description | Planning Implication |
|----|-------------|----------------------|
| GAP-01 | Operator can view ranked KB gap candidates generated from retrieval no-hit, weak-grounding, and repeated manual-handling evidence. [VERIFIED: `.planning/REQUIREMENTS.md`] | Phase 9 needs a durable candidate read model and a dashboard route, not ad hoc queries over raw `cairnloop_retrieval_gap_events`. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/router.ex`] |
| GAP-02 | System clusters related gap evidence into a single candidate with stable identity, freshness metadata, and supporting evidence counts. [VERIFIED: `.planning/REQUIREMENTS.md`] | Phase 9 needs a stable candidate table plus explicit membership links back to source evidence so clustering is durable, inspectable, and refreshable. [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] |
| GAP-03 | Operator can inspect the evidence behind a gap candidate, including retrieval events, similar cases, and why the candidate was raised. [VERIFIED: `.planning/REQUIREMENTS.md`] | The candidate UI must join raw retrieval gap events with existing resolved-case and conversation evidence rails instead of summarizing away the underlying signals. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`] [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] |
</phase_requirements>

## Summary

Phase 9 should be built as a Cairnloop-owned maintenance read model, not as a new search stack and not as a raw analytics dashboard. The repo already has the durable evidence ledger needed to seed this phase: `cairnloop_retrieval_gap_events` stores append-only no-hit, retrieval-error, weak-grounding, and policy-limit events with sanitized query excerpts, hit counts, scope metadata, and bounded evidence snapshots; `SearchModalComponent` records no-hit and assistive-only search gaps; `DraftWorker` records weak-grounding and policy-limit drafting gaps; and resolved conversations already become structured assistive evidence through `ResolvedCaseEvidence`. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `lib/cairnloop/web/search_modal_component.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`]

The missing product layer is the candidate read model. Raw `GapEvent` rows are intentionally append-only and evidence-shaped; they are not ranked, clustered, or operator-friendly enough to satisfy GAP-01 through GAP-03. The clean Phase 9 move is to keep `RetrievalGapEvent` immutable, then add a `KnowledgeAutomation` context with a materialized `GapCandidate` plus explicit membership records that point back to gap events and manual-handling evidence. That preserves M009’s evidence-vs-telemetry discipline while matching the M010 spec’s recommendation for a Cairnloop-owned KB maintenance context. [VERIFIED: `.planning/milestones/M009-phases/M009-S04/M009-S04-RESEARCH.md`] [VERIFIED: `.planning/milestones/M009-phases/M009-S04/M009-S04-VERIFICATION.md`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

Repeated manual handling should be derived from existing durable support workflow state instead of inventing a second freeform analytics lane. The repo already persists operator intervention signals through `cairnloop_drafts` status changes such as `:edited`, `:approved`, and `:discarded`, proposal types such as `:clarification` and `:escalation`, and resolved-case evidence summaries tied to resolved conversations. Phase 9 can project those durable support outcomes into candidate memberships during background refresh, then surface them beside retrieval gap events as “similar cases” and “manual handling count” evidence. [VERIFIED: `lib/cairnloop/automation/draft.ex`] [VERIFIED: `lib/cairnloop/automation.ex`] [VERIFIED: `lib/cairnloop/chat.ex`] [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

**Primary recommendation:** Add `Cairnloop.KnowledgeAutomation` with a materialized `GapCandidate` read model, background clustering via Oban, explicit membership links to `RetrievalGapEvent` and manual-handling cases, and a new `/knowledge-base/gaps` LiveView that shows ranked candidates plus inspectable evidence detail. [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/router.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/index.ex`] [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Gap evidence capture | API / Backend | Database / Storage | M009 already writes durable retrieval-gap evidence from `SearchModalComponent` and `DraftWorker` through `GapRecorder`; Phase 9 should consume that store rather than re-capturing events in the UI. [VERIFIED: `lib/cairnloop/web/search_modal_component.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] |
| Candidate clustering and ranking | API / Backend | Database / Storage | Clustering depends on durable scope, reason, query excerpts, and support evidence joins, so it belongs in an Ecto/Oban domain layer rather than LiveView handlers. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/prune_gap_events.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] |
| Candidate persistence | Database / Storage | API / Backend | GAP-02 requires stable identities, counts, and freshness metadata, which implies a persistent read model rather than recalculation per request. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/ROADMAP.md`] |
| Operator dashboard and evidence inspection | Frontend Server (LiveView) | API / Backend | Existing operator surfaces are server-rendered LiveViews, and the KB index/editor already live under the dashboard router. [VERIFIED: `lib/cairnloop/router.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/index.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`] |
| Similar-case enrichment | API / Backend | Database / Storage | Similar-case evidence already comes from `ResolvedCaseEvidence` and `ResolvedCases.search/2`, so the candidate detail seam should reuse those domain models instead of duplicating evidence blobs. [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`] |

## Existing Code Realities

### What Phase 9 can reuse

- `Cairnloop.Retrieval.GapEvent` already preserves the envelope Phase 9 needs: `surface`, `outcome_class`, `reason`, `tenant_scope`, `ui_surface`, `query_fingerprint`, `sanitized_query_excerpt`, hit counts, clarification attempts, and bounded evidence snapshots. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`]
- `Cairnloop.Retrieval.GapRecorder` already normalizes redacted query excerpts, dedupes assistive-only search gaps within 24 hours, and exposes `list_recent/1`, which makes it the right immutable source ledger for candidate building. [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `test/cairnloop/retrieval/gap_recorder_test.exs`]
- `SearchModalComponent` already distinguishes three search branches that matter to Phase 9: no-hit, assistive-only weak grounding, and retrieval error; mixed and canonical-backed searches intentionally stay out of durable gap storage. [VERIFIED: `lib/cairnloop/web/search_modal_component.ex`] [VERIFIED: `test/cairnloop/web/search_modal_component_test.exs`] [VERIFIED: `.planning/milestones/M009-phases/M009-S04/M009-S04-VERIFICATION.md`]
- `DraftWorker` already records weak-grounding and policy-limit gaps from the drafting boundary and carries `host_user_id`, `host_surface`, clarification attempts, and evidence snapshots into the gap recorder. [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `test/cairnloop/automation/workers/draft_worker_test.exs`]
- `ResolvedCaseEvidence` plus `IndexResolvedConversation` already produce structured issue summaries, resolution notes, action lists, outcomes, and citation backreferences for similar-case inspection. [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`]
- `ConversationLive` already has the operator evidence rail and is the strongest existing reference for the tone and trust posture Phase 9 detail views should preserve. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [VERIFIED: `.planning/milestones/M009-phases/M009-S03/M009-S03-RESEARCH.md`]

### What is still missing

- No candidate table or candidate context exists yet; the repo has only raw gap-event storage and no clustered read model. [VERIFIED: repo code review]
- No KB dashboard route exists for gap review; the router currently exposes only inbox, conversation, knowledge-base index, knowledge-base editor, and settings. [VERIFIED: `lib/cairnloop/router.ex`]
- No current module joins retrieval gap events to draft lifecycle outcomes or resolved-case summaries for “repeated manual handling.” [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `lib/cairnloop/automation.ex`] [VERIFIED: `lib/cairnloop/chat.ex`]
- The current KB index is a plain article list, so overloading it with candidate logic would mix published-corpus management with pre-publication maintenance review too early. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/index.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

## Recommended Phase 9 Shape

### Context and module seams

Recommended new context and modules: [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: repo module layout under `lib/cairnloop/`]

```text
lib/cairnloop/
├── knowledge_automation.ex                              # public Phase 9 API
├── knowledge_automation/
│   ├── gap_candidate.ex                                 # materialized candidate schema
│   ├── gap_candidate_membership.ex                      # links candidate -> source evidence
│   ├── candidate_builder.ex                             # clustering + ranking rules
│   ├── manual_handling_signal.ex                        # derived support-case projection helper
│   └── workers/
│       ├── refresh_gap_candidates.ex                    # refresh open candidate set
│       └── backfill_gap_candidates.ex                   # rebuild from existing events
└── web/knowledge_base_live/
    └── gaps.ex                                          # dashboard + evidence detail
```

Recommended public API surface: [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: existing context APIs in `lib/cairnloop/knowledge_base.ex` and `lib/cairnloop/automation.ex`]

- `list_gap_candidates/1` for ranked dashboard queries. [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]
- `get_gap_candidate!/2` for detail inspection with memberships and evidence joins. [VERIFIED: `.planning/REQUIREMENTS.md`]
- `refresh_gap_candidates/1` for synchronous admin-triggered rebuilds in tests and jobs. [VERIFIED: existing rebuild/reindex patterns in `lib/cairnloop/retrieval.ex`]
- `schedule_gap_candidate_refresh/1` for background refresh after new gap evidence lands. [VERIFIED: existing Oban usage in `lib/cairnloop/retrieval/workers/prune_gap_events.ex`] [VERIFIED: `lib/cairnloop/chat.ex`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`]

### Data model

Recommended durable tables: [VERIFIED: append-only evidence discipline in `.planning/milestones/M009-phases/M009-S04/M009-S04-RESEARCH.md`] [VERIFIED: existing Ecto schema conventions in `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

1. `cairnloop_gap_candidates`
   - Purpose: stable candidate identity, ranking inputs, freshness metadata, and operator state. [VERIFIED: `.planning/REQUIREMENTS.md`]
   - Minimum fields:
     - `status` enum such as `:open | :accepted | :dismissed`. [ASSUMED]
     - `candidate_type` enum such as `:missing_kb_topic | :weak_grounding | :manual_handling`. [ASSUMED]
     - `tenant_scope`, `host_user_id`, and optional `ui_surface` rollups to preserve the existing access model. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`]
     - `title`, `seed_excerpt`, and `stable_key` derived from clustered sanitized text. [ASSUMED]
     - `first_seen_at`, `last_seen_at`, `evidence_count`, `manual_case_count`, `weak_grounding_count`, `no_hit_count`. [VERIFIED: `.planning/REQUIREMENTS.md`] [ASSUMED]
     - `score` and `score_components` map for explicit ranking, not hidden sort logic. [VERIFIED: explicit ranking posture in `lib/cairnloop/retrieval/ranker.ex`] [ASSUMED]
2. `cairnloop_gap_candidate_memberships`
   - Purpose: preserve why a candidate exists by linking it back to source evidence rows. [VERIFIED: `.planning/REQUIREMENTS.md`]
   - Minimum fields:
     - `gap_candidate_id`
     - `source_type` enum such as `:retrieval_gap_event | :manual_case`
     - `source_id`
     - `inserted_at` only; treat as append-only membership history unless the candidate is rebuilt. [ASSUMED]

This two-table shape is preferable to mutating `cairnloop_retrieval_gap_events` directly because M009 intentionally made gap events an immutable evidence ledger with retention and dedupe rules of their own. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/prune_gap_events.ex`]

### Candidate identity and clustering

Recommended clustering rules: [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`]

1. First bucket by trust-relevant envelope:
   - `tenant_scope`
   - `host_user_id` when scope is user-scoped
   - broad failure family derived from `outcome_class` and `reason`
   - candidate lane (`retrieval_gap` vs `manual_handling`) [ASSUMED]
2. Then cluster by normalized topic seed:
   - retrieval gaps use `sanitized_query_excerpt` and snapshot titles. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_event_snapshot.ex`]
   - manual-handling cases use `ResolvedCaseEvidence.issue_summary`, conversation subject, and latest draft proposal signals. [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `lib/cairnloop/chat.ex`] [VERIFIED: `lib/cairnloop/automation/draft.ex`]
3. Keep the stable key deterministic and inspectable.
   - Do not use database IDs alone because GAP-02 requires related evidence to merge under one durable candidate identity. [VERIFIED: `.planning/REQUIREMENTS.md`]
   - Do not use raw query fingerprints alone because M009 intentionally dedupes only exact assistive-only search repeats, while Phase 9 must merge broader related evidence. [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `.planning/milestones/M009-phases/M009-S08/M009-S08-RESEARCH.md`]

The safest Phase 9 clustering strategy is a boring two-stage pass: deterministic lexical bucketing first, then bounded semantic merge only inside compatible buckets if the implementation needs paraphrase grouping beyond exact excerpts. That matches Cairnloop’s existing explicit-ranking posture better than opaque global clustering. [VERIFIED: `lib/cairnloop/retrieval/ranker.ex`] [VERIFIED: `.planning/MILESTONE-ARC.md`] [ASSUMED]

### Repeated manual-handling projection

Recommended Phase 9 heuristic for “manual handling”: [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/automation/draft.ex`] [VERIFIED: `lib/cairnloop/automation.ex`] [VERIFIED: `lib/cairnloop/chat.ex`]

- Count a resolved support case as manual-handling evidence when the conversation has a latest durable draft that ended in `:edited`, or when the latest draft proposal type was `:clarification` or `:escalation` before the conversation was later resolved. [VERIFIED: `lib/cairnloop/automation/draft.ex`] [VERIFIED: `lib/cairnloop/automation.ex`] [VERIFIED: `lib/cairnloop/chat.ex`] [ASSUMED]
- Project those cases into candidate memberships by joining the conversation’s `ResolvedCaseEvidence` row and using its `issue_summary` as the clustering seed plus its `citation_backreferences` for operator inspection. [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`] [ASSUMED]
- Do not treat every approved draft as a gap by itself; Phase 9 is about repeated manual handling, not normal successful operator review. [VERIFIED: `.planning/REQUIREMENTS.md`] [ASSUMED]

This recommendation is narrower and safer than mining arbitrary message history because the repo already treats `Draft` and `ResolvedCaseEvidence` as the durable, bounded support-outcome artifacts. [VERIFIED: `lib/cairnloop/automation/draft.ex`] [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [VERIFIED: `.planning/PROJECT.md`]

### Ranking

Recommended candidate score inputs: [VERIFIED: GAP-01 wording in `.planning/REQUIREMENTS.md`] [VERIFIED: current explicit scoring posture in `lib/cairnloop/retrieval/ranker.ex`] [ASSUMED]

- `evidence_count` with diminishing returns so one noisy day does not dominate forever.
- `last_seen_at` recency boost so fresh gaps outrank stale historical clusters.
- `manual_case_count` boost because repeated operator intervention is the highest-cost signal in this milestone. [VERIFIED: `.planning/PROJECT.md`] [ASSUMED]
- `weak_grounding_count` above pure no-hit count when assistive evidence exists but canonical guidance is absent, because that more strongly suggests a KB maintenance opportunity than an unanswerable typo search. [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [ASSUMED]
- Optional de-boost for candidates whose evidence is entirely older than the 90-day gap-event retention window. [VERIFIED: `lib/cairnloop/retrieval/workers/prune_gap_events.ex`] [ASSUMED]

The score should stay transparent and persisted as explicit components because the repo’s established posture favors explainable ranking and calm operator trust cues over opaque AI prioritization. [VERIFIED: `lib/cairnloop/retrieval/ranker.ex`] [VERIFIED: `.planning/MILESTONE-ARC.md`]

## UI Seams

Recommended dashboard route and LiveView shape: [VERIFIED: `lib/cairnloop/router.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/index.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

- Add `live("/knowledge-base/gaps", Cairnloop.Web.KnowledgeBaseLive.Gaps, :index)` under the existing `cairnloop_dashboard` session. [ASSUMED]
- Keep the candidate list and evidence detail in the same LiveView, with a selected-candidate detail pane rather than a separate admin namespace. That matches the current small LiveView dashboard shape and keeps KB maintenance visually adjacent to KB authoring. [VERIFIED: `lib/cairnloop/router.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/index.ex`] [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [ASSUMED]
- Reuse Phase 2 and Phase 3 trust language:
  - “Knowledge Base” vs “Similar resolved cases” labels from search. [VERIFIED: `lib/cairnloop/web/search_modal_component.ex`] [VERIFIED: `lib/cairnloop/web/search_result_presenter.ex`]
  - explicit clarification/escalation/manual-review phrasing from conversation evidence rails. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] [VERIFIED: `.planning/milestones/M009-phases/M009-S03/M009-S03-RESEARCH.md`]

Minimum operator-visible fields for the list view: [VERIFIED: GAP-01 and GAP-02 in `.planning/REQUIREMENTS.md`] [ASSUMED]

- candidate title
- why raised (`no hit`, `weak grounding`, `manual handling`, or mixed)
- evidence count
- last seen / first seen
- manual-case count
- dominant source mix

Minimum operator-visible fields for the detail view: [VERIFIED: GAP-03 in `.planning/REQUIREMENTS.md`] [ASSUMED]

- grouped retrieval gap events with surface, reason, counts, and timestamps
- linked similar resolved cases with issue summary, resolution note, actions taken, and outcome
- top evidence snapshots from underlying `attempted_evidence_snapshots`
- one-click navigation back to the cited conversation or KB article when available

## Job Graph

Recommended Oban workflow: [VERIFIED: existing Oban usage in `lib/cairnloop/chat.ex`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/prune_gap_events.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

1. `RefreshGapCandidates`
   - runs on a schedule and can be enqueued after new gap-event writes or conversation resolution. [ASSUMED]
   - scans recent `RetrievalGapEvent` rows plus candidate-worthy manual-handling cases. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/retrieval/resolved_case_evidence.ex`] [ASSUMED]
   - updates or creates `GapCandidate` rows and membership links in one transaction per candidate bucket. [ASSUMED]
2. `BackfillGapCandidates`
   - rebuilds the candidate read model from historical events after deployment or major clustering-rule changes. [ASSUMED]
   - mirrors existing rebuild/replay posture already present in `Cairnloop.Retrieval`. [VERIFIED: `lib/cairnloop/retrieval.ex`]

Do not enqueue candidate refresh directly from telemetry handlers. M009 already established that durable evidence belongs at the application boundary, not inside observability callbacks. [VERIFIED: `.planning/milestones/M009-phases/M009-S04/M009-S04-RESEARCH.md`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`]

## Anti-Patterns

- **Do not query raw `cairnloop_retrieval_gap_events` directly from the dashboard and cluster in memory per request.** That would satisfy neither stable identity nor ranked durability, and it would turn LiveView into the clustering engine. [VERIFIED: GAP-01 and GAP-02 in `.planning/REQUIREMENTS.md`] [VERIFIED: `lib/cairnloop/web/search_modal_component.ex`]
- **Do not mutate or repurpose `cairnloop_retrieval_gap_events` into candidate rows.** M009 deliberately made gap events append-only evidence with redaction, dedupe, and retention semantics. [VERIFIED: `lib/cairnloop/retrieval/gap_event.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `lib/cairnloop/retrieval/workers/prune_gap_events.ex`]
- **Do not overload `KnowledgeBaseLive.Index` with candidate state.** Published article management and pre-publication maintenance review are adjacent but distinct responsibilities in the current product shape. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/index.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]
- **Do not treat every resolved conversation or approved draft as a KB gap.** The milestone requirement is repeated manual handling, not total support volume. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/PROJECT.md`]
- **Do not hide ranking rationale behind an opaque semantic score only.** The repo’s retrieval layer already favors explicit ranking outcomes and match reasons, and Phase 9 should keep that explainable posture. [VERIFIED: `lib/cairnloop/retrieval/ranker.ex`] [VERIFIED: `.planning/MILESTONE-ARC.md`]

## Validation Architecture

Phase 9 should verify four layers: [VERIFIED: proof posture in `.planning/REQUIREMENTS.md`] [VERIFIED: existing focused validation style in `.planning/milestones/M009-phases/M009-S04/M009-S04-VALIDATION.md`]

1. Candidate builder contract
   - related retrieval gap events collapse into one stable candidate identity
   - manual-handling projections join correctly
   - score ordering is deterministic
2. Persistence contract
   - candidate rows and memberships are transactionally updated
   - rebuilds are idempotent
3. Dashboard contract
   - ranked list renders expected fields
   - detail pane exposes underlying retrieval and similar-case evidence
4. Integration contract
   - new search gaps or weak-grounding draft gaps eventually appear in the dashboard
   - a resolved manually handled case can raise or strengthen a candidate

Recommended focused test files: [VERIFIED: current test layout under `test/cairnloop/`] [ASSUMED]

- `test/cairnloop/knowledge_automation/gap_candidate_test.exs`
- `test/cairnloop/knowledge_automation/candidate_builder_test.exs`
- `test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs`
- `test/cairnloop/web/knowledge_base_live/gaps_test.exs`

Recommended quick run command: [VERIFIED: repo uses focused mix test runs in prior M009 validation artifacts]

```bash
mix test test/cairnloop/knowledge_automation/candidate_builder_test.exs \
  test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs \
  test/cairnloop/web/knowledge_base_live/gaps_test.exs
```

Recommended realism lane after implementation: [VERIFIED: repo-backed realism lanes are explicitly called out as useful but currently environment-sensitive in `.planning/STATE.md`] [ASSUMED]

- seed a small set of retrieval gap events
- mark one or two conversations as manually handled through existing draft lifecycle
- run the refresh worker
- verify ranked candidates and detail links in the mounted LiveView

## Resolved Planning Defaults

1. **Clustering depth:** Phase 9 stops at deterministic lexical-first clustering. Do not add semantic merge, embeddings, or LLM topic naming in this phase. If lexical grouping later proves too noisy, that becomes a follow-on planning input rather than an implementation-time deviation. [VERIFIED: `lib/cairnloop/retrieval/ranker.ex`] [VERIFIED: `.planning/MILESTONE-ARC.md`]
2. **Manual-handling threshold:** only raise or strengthen a manual-handling candidate when at least two durable manual-handling cases land in the same stable bucket inside the active 90-day evidence window. One-off manual interventions may enrich an existing retrieval-gap candidate, but they do not create a standalone candidate by themselves. [VERIFIED: `lib/cairnloop/automation/draft.ex`] [VERIFIED: `lib/cairnloop/automation.ex`] [VERIFIED: `.planning/REQUIREMENTS.md`]
3. **Retention behavior:** candidate refresh must recompute counts from currently retained evidence on every rebuild. If a candidate loses all memberships after evidence pruning, remove it from the open queue instead of preserving stale counts. If evidence remains but `last_seen_at` ages beyond 90 days, keep the candidate only if its memberships still exist and mark its freshness through persisted recency fields rather than hidden heuristics. [VERIFIED: `lib/cairnloop/retrieval/workers/prune_gap_events.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `cairnloop_gap_candidates` should carry `status` values such as `:open | :accepted | :dismissed` and `candidate_type` values such as `:missing_kb_topic | :weak_grounding | :manual_handling`. [ASSUMED] | Recommended Phase 9 Shape | Low. The exact enum names can change without altering the architecture. |
| A2 | Candidate memberships should use a separate `cairnloop_gap_candidate_memberships` table rather than embedded JSON only. [ASSUMED] | Data model | Medium. A JSON-only design would reduce joins, but it would weaken inspectability and rebuild safety. |
| A3 | Manual-handling evidence should treat edited drafts or clarification/escalation drafts on later-resolved conversations as the initial projection heuristic. [ASSUMED] | Repeated manual-handling projection | Medium. Product may want a stricter or broader heuristic. |
| A4 | Phase 9 should add `live("/knowledge-base/gaps", Cairnloop.Web.KnowledgeBaseLive.Gaps, :index)` and keep list/detail in one LiveView. [ASSUMED] | UI Seams | Low. The exact route/action split can change without changing the domain model. |
| A5 | Candidate refresh should be scheduled through dedicated Oban workers named `RefreshGapCandidates` and `BackfillGapCandidates`. [ASSUMED] | Job Graph | Low. Naming is flexible; the need for a background refresh seam is not. |

## RESEARCH COMPLETE
