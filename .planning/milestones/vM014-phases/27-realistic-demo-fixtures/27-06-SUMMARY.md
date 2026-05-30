---
phase: 27-realistic-demo-fixtures
plan: "06"
subsystem: example-app-seeds
tags:
  - seeds
  - elixir
  - knowledge-automation
  - article-suggestion
  - review-task
dependency_graph:
  requires:
    - 27-03 (build_articles/0 returning %{api_key: %Article{}} with published revision)
    - 27-04 (build_conversations/1; _conversations arg unused in this plan)
    - 27-05 (build_gaps/1 returning [%GapCandidate{stable_key: "demo_gap_billing_export", ...}])
  provides:
    - build_suggestion/2 body: 1 ArticleSuggestion :ready + 2 KB-chunk evidence rows + 1 ReviewTask + 1 task_created event
    - compute_evidence_digest/1 private helper (mirrors production evidence_digest_for/1 field order)
    - "@demo_suggestion_stable_key" module attribute: "demo:article_suggestion:billing_export:v1"
  affects:
    - examples/cairnloop_example/priv/repo/seeds.exs
tech_stack:
  added: []
  patterns:
    - Direct ArticleSuggestion.changeset/2 + Repo.insert! (D-15 — no LLM worker enqueue)
    - Manual Repo.get_by idempotency guard on :stable_key (embeds_many incompatible with get_or_insert!/3)
    - KnowledgeAutomation.ensure_review_task_for_suggestion/2 (Critical Finding 2 / Pitfall 1)
    - :crypto.hash(:sha256, Jason.encode!(evidence_projection)) |> Base.encode16(case: :lower)
    - host_user_id "demo_operator" on ArticleSuggestion + ReviewTask (Pitfall 3 — operator-scope)
key_files:
  created: []
  modified:
    - examples/cairnloop_example/priv/repo/seeds.exs
decisions:
  - "2 KB-chunk-grounded evidence rows (not conversation-grounded) — schema's validate_citation_target requires article_id/revision_id/chunk_index; conversation-only rows are fundamentally incompatible"
  - "_conversations arg underscore-prefixed because evidence is exclusively KB-chunk-grounded; conversation context surfaces via plan 27-04's seeded conversations, not via suggestion evidence"
  - "Idempotency uses manual Repo.get_by on stable_key (not get_or_insert!/3) because embeds_many :evidence_snapshot is cast at insert time"
  - "ensure_review_task_for_suggestion called with ONLY actor_id: 'system' — tenant_scope and host_user_id sourced from loaded suggestion automatically"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-27T17:00:00Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase 27 Plan 06: build_suggestion/2 Implementation Summary

Implement `build_suggestion/2` in seeds.exs: 1 ArticleSuggestion with status `:ready` (sealed enum), 2 KB-chunk-grounded ArticleSuggestionEvidence rows pointing at the api_key article's published revision (chunk_index 0 and 1), a deterministic `evidence_digest`, and a companion ReviewTask via `KnowledgeAutomation.ensure_review_task_for_suggestion/2`. Without the ReviewTask, SuggestionReview LiveView reads an empty queue (FIX-04 silently fails).

## What Was Built

**File modified:** `examples/cairnloop_example/priv/repo/seeds.exs`

Replaced the `# TODO` stub body of `build_suggestion/2` (`{nil, nil}`) with:

1. `@demo_suggestion_stable_key "demo:article_suggestion:billing_export:v1"` — module attribute for idempotency key.
2. `build_suggestion/2` body:
   - Loads `demo_gap_billing_export` gap via `Repo.get_by!`
   - Loads `api_key_article` from the articles map and its `:published` revision
   - Constructs 2 KB-chunk evidence rows (chunk_index 0 and 1)
   - Builds `suggestion_attrs` with sealed enums `:ready` and `:article`
   - Idempotent insert via `Repo.get_by(ArticleSuggestion, stable_key: ...)`
   - Calls `KnowledgeAutomation.ensure_review_task_for_suggestion(suggestion.id, actor_id: "system")`
   - Returns `{suggestion, review_task}`
3. `compute_evidence_digest/1` private helper — mirrors `evidence_digest_for/1` at `lib/cairnloop/knowledge_automation.ex:961-976`.

## Sealed-Enum Reconciliation (Verbatim)

| Spec language (CONTEXT.md / roadmap) | Actual schema enum | Schema location |
|--------------------------------------|-------------------|----------------|
| `:ready_for_review` | `status: :ready` | `lib/cairnloop/knowledge_automation/article_suggestion.ex:7` |
| `:new_article` | `suggestion_type: :article` | `lib/cairnloop/knowledge_automation/article_suggestion.ex:8` |

## Stable Key (Verbatim)

```
"demo:article_suggestion:billing_export:v1"
```

## Evidence Rows — Source and Trust Confirmation

Both evidence rows use `source_type: :knowledge_base` and `trust_level: :canonical` (sealed enums verified at `ArticleSuggestionEvidence` lines 7-8: `@source_types [:knowledge_base, :resolved_case, :unknown]`, `@trust_levels [:canonical, :assistive, :unknown]`).

## Evidence Citation Confirmation

Both evidence rows reference `api_key_article`'s published revision:

| Row | chunk_index | citation_target keys present | metadata.destination keys present |
|-----|-------------|------------------------------|-----------------------------------|
| 1 | 0 | article_id, revision_id, chunk_index | article_id, revision_id |
| 2 | 1 | article_id, revision_id, chunk_index | article_id, revision_id |

The `article_id:` and `revision_id:` keys appear **only** in evidence rows' `citation_target` and `metadata.destination` maps — they are NOT set on the suggestion attrs itself. The suggestion's `article_id` and `base_revision_id` fields are intentionally left unset because `validate_anchor_rules` at `ArticleSuggestion` lines 144-148 rejects them for `{:article, :gap_candidate}` pairs.

## Suggestion-Level Anchor Fields (UNSET — validate_anchor_rules)

`article_id` and `base_revision_id` are **not present** in `suggestion_attrs`. For `{:article, :gap_candidate}`, `validate_anchor_rules/1` calls `reject_anchor/3` on both fields and returns a changeset error if they are set. The article reference surfaces only through the evidence rows' `citation_target.article_id` + `metadata.destination.article_id`.

## ensure_review_task_for_suggestion Call (opts confirmation)

```elixir
KnowledgeAutomation.ensure_review_task_for_suggestion(
  suggestion.id,
  actor_id: "system"
)
```

Only `:actor_id` is passed. `:tenant_scope` and `:host_user_id` are NOT in opts — they are sourced from the loaded suggestion automatically at `lib/cairnloop/knowledge_automation.ex:137-138`. This matches the function's spec (`@spec ensure_review_task_for_suggestion(id :: integer, opts :: keyword) :: {:ok, ReviewTask.t}`).

## Conversation-Grounded Evidence Row: Why It Was Dropped

A prior plan iteration considered a third evidence row sourced from a seeded conversation. This was dropped because:
- `validate_citation_target` (ArticleSuggestionEvidence lines 47-63) **requires** `article_id`, `revision_id`, and `chunk_index` on **every** evidence row.
- Conversation-only citation targets lack these keys → changeset would reject the insert.
- Conversation context is already present in the demo via plan 27-04's 16 seeded conversations.
- The schema has no direct `ArticleSuggestion → Conversation` anchor field.

Staying KB-only (2 rows at chunk_index 0 and 1) is the strongest single-axis fix that satisfies all validators.

## Acceptance Criteria Verification

| Criterion | Result |
|-----------|--------|
| `grep -E 'status:\s*:ready_for_review\|suggestion_type:\s*:new_article'` = 0 | **0** (sealed-enum honored) |
| `grep -c 'status:.*:ready'` >= 1 | **3** (code + comment lines) |
| `grep -c 'suggestion_type:.*:article'` >= 1 | **3** |
| `grep -c 'Workers\.GenerateArticleSuggestion'` = 0 | **0** |
| `grep -c 'KnowledgeAutomation\.suggest_article'` = 0 | **0** |
| `grep -c 'ensure_review_task_for_suggestion'` >= 1 | **3** (1 call + 2 comment/doc lines) |
| `grep -c 'defp compute_evidence_digest'` = 1 | **1** |
| `grep -c 'destination:'` >= 2 | **2** |
| `grep -c 'chunk_index:'` >= 2 | **4** (2 in citation_target rows, 2 in comments) |
| `grep -E 'ensure_review_task_for_suggestion\([^)]*(tenant_scope\|host_user_id)'` = 0 | **0** |
| stable_key = "demo:article_suggestion:billing_export:v1" | **1** |
| `mix compile --warnings-as-errors` exits 0 | **PASS** |
| `mix test` (baseline DraftTest excluded) | **PASS — 682 tests, 1 known pre-existing failure** |

## Deviations from Plan

None — plan executed exactly as written.

The conversation-grounded evidence row was never present in this plan's implementation; the plan itself directed 2 KB-chunk-grounded rows from the start (citing the prior iteration's blockers as already resolved).

## Threat Model Mitigations

| Threat | Status |
|--------|--------|
| T-27-16 Tampering (sealed-enum spec-language drift) | Mitigated — grep gate confirmed 0 occurrences of `:ready_for_review` / `:new_article` in code lines |
| T-27-17 Information Disclosure (wrong tenant scope hides suggestion) | Mitigated — `host_user_id: "demo_operator"` on suggestion attrs; `ensure_review_task_for_suggestion` inherits from loaded suggestion |
| T-27-18 Tampering (LLM call enqueued from seed) | Mitigated — 0 `Workers.GenerateArticleSuggestion` calls; 0 `KnowledgeAutomation.suggest_article` calls |
| T-27-19 Repudiation (non-deterministic evidence_digest) | Mitigated — `compute_evidence_digest/1` mirrors production field order verbatim (metadata excluded) |
| T-27-20 Tampering (evidence row missing required keys) | Mitigated — both rows have article_id/revision_id/chunk_index in citation_target and destination map in metadata; grep gate chunk_index >= 2, destination >= 2 both pass |

## Known Stubs

None — `build_suggestion/2` stub is fully replaced. The stub return value `{nil, nil}` is gone; the real body returns `{%ArticleSuggestion{}, %ReviewTask{}}`.

## Threat Flags

No new threat surface. `build_suggestion/2` is an additive function in a dev-only seed script. No library code modified. No new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- File exists: `examples/cairnloop_example/priv/repo/seeds.exs` — FOUND
- Commit df111ea exists — FOUND
- `grep -E 'status:\s*:ready_for_review\|suggestion_type:\s*:new_article'` = 0 — CONFIRMED
- `grep -c 'ensure_review_task_for_suggestion'` = 3 (>= 1) — CONFIRMED
- `grep -c 'defp compute_evidence_digest'` = 1 — CONFIRMED
- `grep -c 'destination:'` = 2 (>= 2) — CONFIRMED
- `grep -c 'chunk_index:'` = 4 (>= 2) — CONFIRMED
- `grep -E 'ensure_review_task_for_suggestion\([^)]*(tenant_scope\|host_user_id)'` = 0 — CONFIRMED
- `mix compile --warnings-as-errors` exits 0 — CONFIRMED
- `mix test` passes (1 known pre-existing DraftTest failure only) — CONFIRMED
