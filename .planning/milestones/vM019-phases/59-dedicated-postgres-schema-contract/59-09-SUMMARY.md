---
phase: 59-dedicated-postgres-schema-contract
plan: "09"
subsystem: retrieval
tags: [postgres, ecto, schema-prefix, retrieval, workers]
requires:
  - phase: 59-03
    provides: Core runtime prefix helpers/pattern
provides:
  - Prefix-aware retrieval health support-table SQL
  - Prefix-aware KB and resolved-case provider queries/fragments
  - Prefix-aware chunk refresh `delete_all` and `insert_all` worker operations
  - Runtime retrieval collision/Oban-boundary integration contract scaffold
affects: [phase-59, db-prefix, retrieval, knowledge-base-workers, resolved-case-workers]
tech-stack:
  added: []
  patterns:
    - Provider sources use local `prefixed/1` query helpers
    - Worker bulk `Ecto.Multi.delete_all` / `insert_all` calls pass `SchemaPrefix.repo_opts/0`
    - Oban queue reads stay host-owned and unprefixed
key-files:
  created:
    - .planning/phases/59-dedicated-postgres-schema-contract/59-09-SUMMARY.md
  modified:
    - lib/cairnloop/retrieval.ex
    - lib/cairnloop/retrieval/providers/knowledge_base.ex
    - lib/cairnloop/retrieval/providers/resolved_cases.ex
    - lib/cairnloop/knowledge_base/workers/chunk_revision.ex
    - lib/cairnloop/retrieval/workers/index_resolved_conversation.ex
    - test/cairnloop/retrieval_test.exs
    - test/cairnloop/knowledge_base/workers/chunk_revision_test.exs
    - test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs
    - test/integration/schema_prefix_runtime_test.exs
key-decisions:
  - "Support-domain retrieval sources are explicitly prefixed; Oban.Job and raw oban_jobs SQL remain host-owned."
  - "Full-text fragments now reference bound fields instead of bare table names so query source prefixes control table qualification."
patterns-established:
  - "Bulk indexing tests assert both query prefixes and Multi operation prefix opts."
requirements-completed: []
requirements-advanced: [DB-05, DB-06]
duration: 8 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 09: Retrieval Runtime Prefixing Summary

**Retrieval health, providers, and chunk indexing workers now honor the configured Cairnloop support prefix while leaving Oban host-owned.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-30T15:43:00Z
- **Completed:** 2026-06-30T15:50:54Z
- **Tasks:** 1
- **Files modified:** 9

## Accomplishments

- Qualified retrieval health’s `cairnloop_chunks` raw SQL through `Cairnloop.SchemaPrefix.quoted_table/2`.
- Added prefix-aware provider query sources for KB chunks/revisions/articles and resolved-case chunks/evidence.
- Replaced bare full-text fragment table references with bound fields so Ecto source prefixes govern qualification.
- Added prefix opts to chunk worker `get`, evidence upsert, `delete_all`, and `insert_all` paths.
- Added tests for provider query prefixes, worker Multi opts, and the Oban host-owned boundary.
- Extended the runtime integration contract with a public `cairnloop_chunks` collision check for retrieval health.

## Task Commits

1. **Task 1: Prefix retrieval SQL, providers, and bulk indexing workers** - `e36361b` (fix)

**Plan metadata:** this summary commit.

## Files Modified

- `lib/cairnloop/retrieval.ex` - Prefix-aware support-table health SQL and corpus ID queries, with Oban left public.
- `lib/cairnloop/retrieval/providers/knowledge_base.ex` - Prefix-aware KB provider sources and field-bound full-text fragments.
- `lib/cairnloop/retrieval/providers/resolved_cases.ex` - Prefix-aware resolved-case provider sources and field-bound full-text fragments.
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` - Prefix-aware revision read and chunk delete/insert bulk operations.
- `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` - Prefix-aware conversation read, message preload, evidence lookup/upsert, and chunk bulk operations.
- `test/cairnloop/retrieval_test.exs` - Provider prefix assertions and Oban-boundary source lock.
- `test/cairnloop/knowledge_base/workers/chunk_revision_test.exs` - Multi query/opts prefix assertions.
- `test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs` - Preload/evidence/bulk prefix assertions.
- `test/integration/schema_prefix_runtime_test.exs` - Public chunk collision contract for retrieval health.

## Deviations from Plan

None - plan executed as scoped.

## Issues Encountered

- Ecto query macros do not accept local helper calls directly inside join/from source positions. The implementation uses local prefixed query variables for joins and pipeline-composed prefixed queries for worker base sources.
- Some raw SQL/fragment cleanup for retrieval was already present in the dirty worktree at plan start; it was directly required by 59-09 and included in the scoped task commit.
- First Wave 3 `mix ci.fast` run failed on an older review-task migration source assertion that still expected unprefixed DDL. Updated it in `ce9bfda`; the rerun passed.

## User Setup Required

None.

## Verification

- PASS: `mix test test/cairnloop/retrieval_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs --warnings-as-errors`
- PASS: `mix compile --warnings-as-errors`
- PASS: `mix test --exclude integration test/integration/schema_prefix_runtime_test.exs --warnings-as-errors` compiled the integration contract file with 8 integration tests excluded.
- PASS: `mix test test/cairnloop/knowledge_automation/review_task_test.exs --warnings-as-errors`
- PASS: `mix ci.fast` (1154 tests, 0 failures, 80 excluded)

## Next Phase Readiness

Wave 3 is complete. Ready for the Wave 3 fast CI gate, then Wave 4 plans 59-04 and 59-05.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
