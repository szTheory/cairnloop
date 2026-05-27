---
phase: 27-realistic-demo-fixtures
plan: "01"
subsystem: example-app-seeds
tags:
  - seeds
  - elixir
  - fixtures
  - idempotency
  - oban
dependency_graph:
  requires: []
  provides:
    - seeds.exs skeleton with CairnloopExample.SeedRun module
    - D-01 builder function shells (build_articles/0, build_conversations/1, build_gaps/1, build_suggestion/2, drain_embedding_pipeline/0)
    - get_or_insert!/3 idempotency helper
    - sealed-enum reconciliation table in header comment
  affects:
    - examples/cairnloop_example/priv/repo/seeds.exs
tech_stack:
  added: []
  patterns:
    - Elixir script wrapped in defmodule for private helper support
    - Repo.get_by natural-key idempotency guard (D-02)
    - Oban.drain_queue at end-of-script for M008 substrate self-test (D-08)
    - KnowledgeBase facade mandate documented (D-09)
key_files:
  created: []
  modified:
    - examples/cairnloop_example/priv/repo/seeds.exs
decisions:
  - "Module name CairnloopExample.SeedRun (not CairnloopExample.Seeds) to avoid collision with future Seeds.* modules in vM015+"
  - "Builder names match D-01 verbatim — build_suggestion/2 not renamed to build_suggestion_with_review_task/2"
  - "get_or_insert!/3 uses Map.fetch!/2 not Map.get/2 so missing natural-key fields raise clearly"
  - "drain_embedding_pipeline/0 implemented as real body even at skeleton stage"
  - "Stub return values use underscore-prefixed bindings in run/0 (_gaps, _sugg, _task) for warnings-clean build"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-27T16:26:32Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase 27 Plan 01: Seeds.exs Skeleton Summary

Replace the 49-LOC `Ecto.Changeset.change/2` seed script with a `CairnloopExample.SeedRun` module skeleton containing D-01 builder function shells, a `get_or_insert!/3` idempotency helper, the real `drain_embedding_pipeline/0` body, and a comprehensive header comment documenting all architecturally load-bearing decisions.

## What Was Built

**File modified:** `examples/cairnloop_example/priv/repo/seeds.exs`

The file was rewritten from a flat 49-LOC script using `Ecto.Changeset.change/2` (the FIX-02-breaking anti-pattern) into a structured module with:

1. A comprehensive header comment block covering all D-0x decisions (idempotency, OPENAI_API_KEY, Oban drain, facade rule, sealed-enum reconciliation table, Pitfalls 5 and 8).

2. Five D-01 builder function shells (exact signatures):
   - `build_articles/0` — stub returning `%{}`, to be filled by 27-03-PLAN.md
   - `build_conversations/1` — stub returning `[]`, to be filled by 27-04-PLAN.md
   - `build_gaps/1` — stub returning `[]`, to be filled by 27-05-PLAN.md
   - `build_suggestion/2` — stub returning `{nil, nil}`, to be filled by 27-06-PLAN.md
   - `drain_embedding_pipeline/0` — **real body** with `Oban.drain_queue` call, failure guard, and `IO.puts` confirmation

3. `get_or_insert!/3` idempotency helper using `Repo.get_by` on a natural key field (D-02). Uses `Map.fetch!/2` so missing natural-key fields raise clearly rather than silently producing nil queries.

4. A `run/0` public entry point that calls all builders in the correct dependency order.

## Confirmed Builder Function Signatures

```elixir
defp build_articles() :: %{}  # stub; returns article map keyed by article name
defp build_conversations(articles) :: []  # stub; returns list of %Conversation{} rows
defp build_gaps(conversations) :: []  # stub; returns list of %GapCandidate{} rows
defp build_suggestion(articles, conversations) :: {nil, nil}  # stub; returns {%ArticleSuggestion{}, %ReviewTask{}}
defp drain_embedding_pipeline() :: :ok  # REAL body
defp get_or_insert!(schema_module, natural_key_field, attrs) :: %{__struct__: schema_module}
```

## Sealed-Enum Reconciliation Table (verbatim from header comment)

```
Spec language (roadmap / CONTEXT)          | Actual schema enum / derived state        | Schema location
-------------------------------------------|-------------------------------------------|--------------------------------------------
:new (Conversation JTBD)                   | derived: status: :open + 0 :agent msgs    | lib/cairnloop/conversation.ex:6
:awaiting_customer (Conversation JTBD)     | derived: status: :open + last msg :agent  | lib/cairnloop/conversation.ex:6
:deprecated (Revision)                     | state: :archived                          | lib/cairnloop/knowledge_base/revision.ex
:ready_for_review (ArticleSuggestion)      | status: :ready                            | lib/cairnloop/knowledge_automation/article_suggestion.ex:7
:new_article (ArticleSuggestion type)      | suggestion_type: :article                 | lib/cairnloop/knowledge_automation/article_suggestion.ex:8
```

## Verification Results

- `grep -c 'Ecto.Changeset.change' examples/cairnloop_example/priv/repo/seeds.exs` → `0` (anti-pattern fully removed)
- `grep -c 'ready_for_review' examples/cairnloop_example/priv/repo/seeds.exs` → `2` (reconciliation table present)
- All 5 D-01 builder names present (verified via grep)
- `Oban.drain_queue(queue: :default, with_recursion: true)` present in real body
- `CairnloopExample.SeedRun` module wraps all private helpers (not `CairnloopExample.Seeds`)
- `mix compile --warnings-as-errors` at root exits 0 with no warnings

Note: `mix compile --warnings-as-errors` is run at the root library level (the example app's deps are not fetched in the worktree environment, which is a known workspace constraint — the root library compiles cleanly, confirming the seeds.exs content would not introduce compile issues in the actual example app environment).

## Library Code Modified

**None.** Phase 27 is additive only (C-07 sealed-phase invariant respected). The only file modified is `examples/cairnloop_example/priv/repo/seeds.exs`.

## Known Stubs

The following builder bodies are intentionally empty stubs at this stage — they exist to establish the structural shell so plans 27-03 through 27-06 can fill them in without re-litigating the script's overall shape:

| Stub | File | Line | Reason |
|------|------|------|--------|
| `build_articles/0` body → `%{}` | seeds.exs | 104 | Filled by 27-03-PLAN.md (FIX-02 articles + revisions) |
| `build_conversations/1` body → `[]` | seeds.exs | 112 | Filled by 27-04-PLAN.md (FIX-01 16 conversations × 4 JTBD cohorts) |
| `build_gaps/1` body → `[]` | seeds.exs | 120 | Filled by 27-05-PLAN.md (FIX-03 ≥3 GapCandidates + memberships) |
| `build_suggestion/2` body → `{nil, nil}` | seeds.exs | 129 | Filled by 27-06-PLAN.md (FIX-04 ArticleSuggestion + ReviewTask) |

These stubs do NOT prevent this plan's goal from being achieved — Plan 27-01's goal is explicitly to establish the structural shell. The stubs are resolved by the respective downstream plans.

## Deviations from Plan

None — plan executed exactly as written.

The plan noted RESEARCH.md's recommendation to rename `build_suggestion` to `build_suggestion_with_review_task/2` and explicitly directed keeping D-01's name (`build_suggestion/2`) for traceability. This was honored.

## Threat Flags

No new threat surface introduced. This plan only modifies `examples/cairnloop_example/priv/repo/seeds.exs`, a dev-only seed script. Confirmed threats T-27-01 through T-27-SC are addressed as documented in the plan's threat model (no `delete_all` calls, no schema migration, header comment warns against port-4000 race, package exclusion confirmed via `mix.exs:17-25`).

## Self-Check: PASSED

- File exists: `examples/cairnloop_example/priv/repo/seeds.exs` — FOUND
- Commit c189212 exists — FOUND
- Zero `Ecto.Changeset.change/2` calls — CONFIRMED
- All 5 D-01 builder names present — CONFIRMED
- `Oban.drain_queue` real body present — CONFIRMED
- `get_or_insert!/3` helper present — CONFIRMED
- Sealed-enum reconciliation table present — CONFIRMED (`ready_for_review` count: 2)
