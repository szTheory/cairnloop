---
phase: 27-realistic-demo-fixtures
plan: "07"
subsystem: example-app-seeds
tags:
  - seeds
  - elixir
  - oban
  - pgvector
  - m008-substrate
dependency_graph:
  requires:
    - 27-01 (skeleton + drain_embedding_pipeline body)
    - 27-03 (build_articles body)
    - 27-04 (build_conversations body)
    - 27-05 (build_gaps body)
    - 27-06 (build_suggestion body)
  provides:
    - SeedRun.run/0 wired main flow with dependency-ordered builder calls
    - emit_seed_summary/5 adopter-facing IO summary
    - drain_embedding_pipeline/0 returns result map (was :ok)
  affects:
    - examples/cairnloop_example/priv/repo/seeds.exs
tech_stack:
  added: []
  patterns:
    - return-value threading from drain_embedding_pipeline/0 to emit_seed_summary/5
    - Oban.drain_queue with_recursion: true as end-of-script synchronous drain
    - IO.puts adopter-facing summary line (T-27-22 mitigation)
key_files:
  created: []
  modified:
    - examples/cairnloop_example/priv/repo/seeds.exs
decisions:
  - "drain_embedding_pipeline/0 returns result map using '= result' capture; IO output preserved"
  - "run/0 uses named bindings (gaps, suggestion) not underscored — needed for emit_seed_summary/5"
  - "emit_seed_summary/5 placed after drain_embedding_pipeline/0 in file order (logical grouping)"
  - "suggestion_count uses 'if suggestion, do: 1, else: 0' truthiness — safe because build_suggestion/2 uses {:ok, s} = ... (never nil in normal flow)"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-27T17:02:08Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase 27 Plan 07: SeedRun.run/0 Main Flow Wiring Summary

Wire the `SeedRun.run/0` main flow with return-value threading, add the `emit_seed_summary/5` adopter-facing IO helper, and make `drain_embedding_pipeline/0` return its drain result map — completing the end-to-end seed + drain orchestration so `mix setup` produces a visible self-test signal.

## What Was Built

**File modified:** `examples/cairnloop_example/priv/repo/seeds.exs`

### Changes

1. **`run/0` main flow** — Added an opening `IO.puts` banner, promoted `_gaps`/`{_sugg, _task}` stubs to named bindings (`gaps`, `{suggestion, _review_task}`), captured the drain result as `drain_summary`, called `emit_seed_summary/5`, and added an explicit `return :ok`.

2. **`drain_embedding_pipeline/0` return value** — Added `= result` capture to the destructuring pattern so the drain map is returned. Also added a progress `IO.puts` line at the start. The existing IO output (failure warn + success count) is preserved.

3. **`emit_seed_summary/5` new helper** — Prints a single concise count line for the adopter running `mix setup`. Reads `.success` and `.failure` directly from the drain result map.

### Final `run/0`:

```elixir
def run do
  IO.puts("Seeding Cairnloop example app demo data...")

  articles      = build_articles()
  conversations = build_conversations(articles)
  gaps          = build_gaps(conversations)
  {suggestion, _review_task} = build_suggestion(articles, conversations)

  drain_summary = drain_embedding_pipeline()

  emit_seed_summary(articles, conversations, gaps, suggestion, drain_summary)
  :ok
end
```

### Adopter-Facing Summary IO Line (verbatim from `emit_seed_summary/5`):

```
"Seeded #{conversation_count} conversation(s), #{article_count} article(s), " <>
  "#{gap_count} gap candidate(s), #{suggestion_count} article suggestion(s); " <>
  "drained #{drained} embedding job(s) (#{failures} failure(s))."
```

For a fresh DB this produces (with expected counts):

```
Seeded 16 conversation(s), 5 article(s), 3 gap candidate(s), 1 article suggestion(s); drained 6 embedding job(s) (0 failure(s)).
```

### Verbatim Final Line of seeds.exs

```
CairnloopExample.SeedRun.run()
```

### Expected Drain Success Count

**6 jobs** on a fresh database:
- 5 `publish_revision/1` calls from plan 27-03 (articles 1–4 each get 1; article 5 gets 2 publish calls but the v1 is archived first, so 5 first-publish + 1 v2-publish = 6 total ChunkRevision jobs enqueued).
- All 6 drain to `:success` (zero-vector fallback if no `OPENAI_API_KEY`).

## Verification Results

- `grep -cE 'def run do' seeds.exs` → `1` (note: `def run do` is identical to `def run() do` in Elixir)
- `Oban.drain_queue(queue: :default, with_recursion: true)` — 1 code call (line 1223; line 27 is in a header comment)
- `grep -c 'defp emit_seed_summary' seeds.exs` → `1`
- Final non-blank non-comment line: `CairnloopExample.SeedRun.run()`
- Builder call order in `run/0`: `build_articles` → `build_conversations` → `build_gaps` → `build_suggestion` → `drain_embedding_pipeline` → `emit_seed_summary` (T-27-20 mitigated)
- `mix compile --warnings-as-errors` at root → exit 0 (root library compiles clean; example app deps not fetched in this workspace — known baseline constraint per 27-01 SUMMARY and CLAUDE.md)

## Threat Mitigations

| Threat | Status |
|--------|--------|
| T-27-20: drain called before revisions published | Mitigated — run/0 enforces: articles → conversations → gaps → suggestion → drain |
| T-27-21: drain raises if Oban supervisor down | Accepted (documented in header comment) |
| T-27-22: adopter cannot see what was seeded | Mitigated — emit_seed_summary/5 prints concrete counts |

## Deviations from Plan

None — plan executed exactly as written.

The plan showed `drain_embedding_pipeline/0` with a slightly different pattern (`%{success: success, failure: failure} = result = ...`). The implementation follows this exactly. One minor note: the existing `drain_embedding_pipeline/0` in plan 27-01 used a destructuring pattern with `snoozed: _, cancelled: _, discard: _` wildcard bindings. The updated version uses the shorter `%{success: success, failure: failure} = result` pattern (with `result` capturing the full map including snoozed/cancelled/discard), which avoids the wildcard noise while still providing access to all fields via `result`.

## Known Stubs

None — all 5 builders were filled in by plans 27-03 through 27-06. This plan completes the wiring.

## Threat Flags

No new threat surface introduced. Only `examples/cairnloop_example/priv/repo/seeds.exs` modified.

## Self-Check: PASSED

- File exists: `examples/cairnloop_example/priv/repo/seeds.exs` — FOUND
- Commit c207398 exists — FOUND
- `run/0` contains all 5 builder calls in dependency order — CONFIRMED
- `drain_embedding_pipeline/0` returns `result` map — CONFIRMED
- `emit_seed_summary/5` defined — CONFIRMED
- Final line is `CairnloopExample.SeedRun.run()` — CONFIRMED
- Root library compiles warnings-clean — CONFIRMED
