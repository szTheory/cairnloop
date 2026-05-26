# Phase 12: In-Thread Quick Fix & Ops Closure - Research

**Researched:** 2026-05-22
**Domain:** Conversation-launched KB maintenance, typed quick-fix evidence packaging, fail-closed shell or blocked behavior, and bounded host-owned telemetry over the shared review lane.
**Confidence:** HIGH for repo seams and state-machine reuse; MEDIUM for the exact quick-fix package shape because Phase 12 introduces a new typed package over existing suggestion metadata.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- `ConversationLive` evidence rail is the primary quick-fix launch surface. Do not move the primary action into the composer, page header, or generic tool registry.
- Quick-fix creation must create or reuse the existing suggestion-plus-review-task lane and deep-link into `/knowledge-base/suggestions`.
- Review remains the workflow truth. Phase 12 adds a new entrypoint and better closure, not a second maintenance workflow.
- Quick-fix state must be durable and idempotent through host-owned Ecto and Oban seams, not transient LiveView assigns.
- Evidence packaging must preserve three typed layers: `thread_context`, `canonical_retrieval`, and `resolved_case_assists`.
- Only canonical retrieval is citation-eligible. Thread and resolved-case layers may inform drafting and operator context, but they cannot become canonical evidence.
- Fallback is hybrid by failure class: shell when the maintenance need is real but grounding is incomplete; blocked or manual-required when canonical grounding or guardrails fail.
- Telemetry must stay bounded and low-cardinality, and durable workflow truth must stay in `ArticleSuggestion`, `ReviewTask`, and task events rather than telemetry.
- Operator-visible closure belongs inside the existing thread and review-lane surfaces, not in a new dashboard.

### The Agent's Discretion
- Exact module names for quick-fix package builders, query helpers, and telemetry helpers.
- Exact copy and badge labels, as long as shell, blocked, and review-ready states are explicit and calm.
- Exact reason enums, as long as they remain bounded and operator-meaningful.

### Deferred Ideas (OUT OF SCOPE)
- Standalone analytics or operations dashboards.
- One-click publish shortcuts.
- Scoria- or MCP-required governance flows in the critical path.
- A generalized conversation command palette.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| `OPS-01` | Operator can start a KB draft directly from conversation evidence inside the existing support workflow. | Add a durable quick-fix command and query seam in `Cairnloop.KnowledgeAutomation`, keyed by conversation identity, and mount it in `ConversationLive` as a new evidence-rail card. |
| `OPS-03` | System emits bounded telemetry for gap creation, draft suggestion outcomes, review decisions, and publish/reindex follow-through. | Add a narrow `KnowledgeAutomation.Telemetry` helper and emit coarse events from gap-candidate creation, suggestion preparation, review decisions, publish, and chunk follow-through without leaking query text, raw thread text, or citation payloads. |
</phase_requirements>

## Summary

Phase 12 should extend the existing KB maintenance lane rather than inventing new workflow tables. The repo already has the right core pieces:

- `ConversationLive` owns the conversation-side evidence rail where the quick-fix card belongs.
- `KnowledgeAutomation` already owns suggestion persistence, failure fallback, review-task creation, and publish or reindex follow-through.
- Failed suggestions already create `ReviewTask` rows in `review_needed`, which is a strong base for the blocked or shell path.
- `ReviewTaskPresenter` and `SuggestionReview` already distinguish proposal truth from workflow truth and can be extended for quick-fix-specific copy and follow-through.

The main gap is evidence packaging. `ArticleSuggestionEvidence` currently requires `article_id`, `revision_id`, and `chunk_index` on every evidence row, which fits canonical citations but does not fit raw thread context. The cleanest Phase 12 fit is:

1. Keep `evidence_snapshot` citation-eligible and canonical-only.
2. Add a typed quick-fix package to `grounding_metadata` or an adjacent host-owned quick-fix struct with explicit top-level keys for:
   - `thread_context`
   - `canonical_retrieval`
   - `resolved_case_assists`
3. Build suggestion readiness or failure from that typed package without flattening trust levels.

This preserves the existing citation validator and review surface while meeting the new trust boundary.

**Primary recommendation:** split Phase 12 into four plans:

1. Add the durable quick-fix command, conversation-scoped lookup, and typed evidence package.
2. Implement fail-closed shell or blocked behavior and review-lane integration on top of the existing suggestion and task models.
3. Add the in-thread quick-fix card, launch action, and thread-visible follow-through status.
4. Add bounded knowledge-maintenance telemetry plus the remaining presenter or follow-through copy needed for operator-visible closure.

## Locked Decisions

- Preserve `ArticleSuggestion` and `ReviewTask` as the maintenance truth; do not add a parallel quick-fix workflow record.
- Treat quick-fix as a new `entrypoint_type` and conversation-scoped identity, not as a brand-new suggestion domain.
- Keep `evidence_snapshot` canonical-first. The new package should augment it with typed context, not replace it with an untyped blob.
- Reuse `ensure_review_task_for_suggestion/2` for thread-launched work so failed suggestions remain visible in the review lane.
- Keep `ConversationLive` as the operator launch point, but let `/knowledge-base/suggestions` remain the destination for deeper review and publish work.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Quick-fix command + idempotent create or reuse | API / Backend | Database / Storage | `KnowledgeAutomation` already owns suggestion and review-task lifecycle. |
| Conversation-scoped quick-fix card | Frontend Server (SSR) | API / Backend | `ConversationLive` already owns the evidence rail and can query a quick-fix view model. |
| Typed evidence packaging | API / Backend | Retrieval / existing suggestion models | Packaging is trust-sensitive and should stay inside host-owned preparation seams. |
| Shell or blocked fallback | API / Backend | Review lane / editor handoff | The command layer should determine shell vs blocked and persist reason codes before UI rendering. |
| Telemetry emission | API / Backend | Worker follow-through | Existing retrieval telemetry patterns already show how to keep metadata bounded. |

## Standard Stack

### Core

| Library | Purpose | Why Standard |
|---------|---------|--------------|
| Phoenix LiveView | Thread and review-lane UX | The new UI stays inside `ConversationLive` and the existing review lane. |
| Ecto | Suggestion/task state and conversation-scoped lookup | Existing KB maintenance truth is Ecto-backed and tenant-scoped. |
| Oban | Existing generation and publish or reindex work | Quick-fix should reuse the current generation worker and chunk follow-through. |
| `:telemetry` | Bounded ops visibility | The repo already centralizes telemetry and has a bounded retrieval pattern to mirror. |

## Recommended Architecture

### Package Shape

Recommended durable quick-fix package, persisted under `grounding_metadata["quick_fix_package"]` or an equivalent typed host-owned struct:

```elixir
%{
  "thread_context" => %{
    "conversation_id" => 123,
    "subject" => "Billing export fails on weekend",
    "message_excerpt" => "...bounded excerpt...",
    "message_count" => 6
  },
  "canonical_retrieval" => %{
    "evidence_digest" => "...",
    "canonical_evidence_count" => 2,
    "citation_ready" => true
  },
  "resolved_case_assists" => %{
    "case_count" => 1,
    "summary" => ["Similar export timeout case"]
  }
}
```

Rules:

- `evidence_snapshot` remains the canonical citation payload rendered in review.
- `thread_context` and `resolved_case_assists` are bounded summaries only.
- Do not persist raw full-thread transcripts in the package.
- Keep copy-oriented or review-oriented reason fields separate from low-level telemetry fields.

### Existing Seams To Reuse

- `suggest_article/2` and `prepare_request/3` already create or fail suggestions from supplied evidence and grounding metadata.
- `persist_failed/2` plus `ensure_review_task_for_suggestion/2` already support blocked maintenance items that still deserve a durable review lane.
- `create_or_reuse_authoring_article_for_suggestion/2` already gives the manual-authoring fallback a host-owned handoff path.
- `ReviewTaskPresenter.publish_outcome/1` and `history_line/1` already expose publish or reindex follow-through and can be extended with quick-fix copy.

## Key Risks

1. **Current evidence embed is too strict for thread context.**
   `ArticleSuggestionEvidence` requires citation anchors and destination metadata on every row. Do not force thread messages into that schema. Keep thread context in the typed quick-fix package and keep `evidence_snapshot` canonical-only.

2. **Conversation-scoped idempotency does not exist yet.**
   Suggestion identity is currently based on gap or article entrypoints plus `evidence_digest`. Phase 12 needs a conversation-scoped entrypoint and a create-or-reuse seam so repeated button clicks do not fork maintenance lanes.

3. **The thread UI currently only knows about AI reply drafts.**
   `ConversationLive` has no knowledge-maintenance query or presenter today, so the new card needs a dedicated quick-fix read model rather than piggybacking on the existing draft-audit card.

4. **Knowledge-maintenance telemetry is missing.**
   Retrieval emits bounded telemetry, but gap-candidate creation, suggestion outcomes, review decisions, and publish/reindex do not yet emit a consistent bounded maintenance event shape.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Quick run command | `mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements -> Test Map

| Requirement | Test Focus |
|-------------|------------|
| `OPS-01` | conversation quick-fix create or reuse, shell/blocked fallback, review-lane deep link, manual-authoring fallback |
| `OPS-03` | bounded telemetry metadata, low-cardinality reason enums, publish/reindex follow-through events, thread-visible status copy |

### Wave 0 Gaps

- Add conversation quick-fix unit tests and `ConversationLive` rendering tests before implementation deepens.
- Add telemetry helper tests mirroring the existing retrieval telemetry assertions around bounded metadata and absence of raw content.

## Sources

### Primary

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/phases/12-in-thread-quick-fix-ops-closure/12-CONTEXT.md`
- `.planning/phases/12-in-thread-quick-fix-ops-closure/12-UI-SPEC.md`
- `lib/cairnloop/web/conversation_live.ex`
- `lib/cairnloop/knowledge_automation.ex`
- `lib/cairnloop/knowledge_automation/article_suggestion.ex`
- `lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex`
- `lib/cairnloop/knowledge_automation/review_task.ex`
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex`
- `lib/cairnloop/web/review_task_presenter.ex`
- `lib/cairnloop/retrieval/telemetry.ex`

## RESEARCH COMPLETE
