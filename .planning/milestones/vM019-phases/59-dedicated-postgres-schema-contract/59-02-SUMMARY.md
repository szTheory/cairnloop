---
phase: 59-dedicated-postgres-schema-contract
plan: "02"
subsystem: database
tags: [postgres, ecto-migrations, schema-prefix, pgvector]
requires:
  - phase: 59-01
    provides: SchemaPrefix helper and red DB contract tests
provides:
  - Prefix-aware KB, retrieval, gap, and article-suggestion library migrations
  - Migration source-scan gate for unqualified DDL/search_path/vector rollback drift
  - KB/retrieval-owned catalog assertions in the shared schema prefix contract test
affects: [phase-59, db-prefix, migrations, retrieval, knowledge-base]
tech-stack:
  added: []
  patterns:
    - Prefix-aware Ecto migration helpers with `prefix: prefix`
    - Validated `Cairnloop.SchemaPrefix.quoted_table/2` raw SQL identifiers
key-files:
  created:
    - test/cairnloop/migrations_test.exs
  modified:
    - priv/repo/migrations/20260516000000_create_knowledge_base.exs
    - priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs
    - priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs
    - priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs
    - priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs
    - priv/repo/migrations/20260521020000_add_article_suggestions.exs
    - test/integration/schema_prefix_contract_test.exs
key-decisions:
  - "Each migration resolves `Cairnloop.SchemaPrefix.configured()` locally and creates the configured schema before support-domain object creation."
  - "Shared `vector` remains database-level infrastructure: migrations create it if missing but never drop it on rollback."
  - "59-02 owns KB/retrieval/gap/article-suggestion catalog assertions; host, governance, MCP, and outbound catalog checks remain with later owner plans."
patterns-established:
  - "Migration DDL helpers for Cairnloop-owned objects include `prefix: prefix`; raw SQL uses validated quoted identifiers."
requirements-completed: [DB-01, DB-03, DB-04, DB-06]
duration: 6 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 02: KB and Retrieval Migration Prefixing Summary

**KB, retrieval, gap, and article-suggestion migrations now qualify Cairnloop-owned database objects through the configured support prefix.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-30T15:14:50Z
- **Completed:** 2026-06-30T15:20:46Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added configured-prefix handling to the first library migration family, including tables, alters, drops, indexes, FKs, trigger functions, and raw SQL table/function references.
- Kept `vector` rollback host-safe by preserving create-only extension behavior and adding a source-scan guard against `DROP EXTENSION vector`.
- Narrowed the shared integration contract to the 59-02-owned KB/retrieval/gap objects so later plans can add their owned catalog checks without ambiguity.

## Task Commits

1. **Task 1: Qualify KB, retrieval, gap, and article-suggestion migrations** - `1d942b5` (fix)
2. **Task 2: Update dedicated-schema catalog assertions for KB and retrieval objects** - `ffe4d06` (test)

**Plan metadata:** this summary commit.

## Files Created/Modified

- `priv/repo/migrations/20260516000000_create_knowledge_base.exs` - Prefix-aware KB tables, FKs, indexes, and drops.
- `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` - Prefix-aware retrieval DDL, raw SQL, trigger functions, and drops.
- `priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs` - Prefix-aware gap event table and indexes.
- `priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs` - Prefix-aware alters, indexes, and raw SQL update paths.
- `priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs` - Prefix-aware gap candidate/member tables, FKs, and indexes.
- `priv/repo/migrations/20260521020000_add_article_suggestions.exs` - Prefix-aware article suggestion table, FKs, and indexes.
- `test/cairnloop/migrations_test.exs` - Source scans for prefix drift, `SET search_path`, raw public-style SQL, and vector rollback.
- `test/integration/schema_prefix_contract_test.exs` - KB/retrieval/gap catalog assertions owned by this plan.

## Decisions Made

- Used small local `ensure_schema/1` helpers in migration modules instead of introducing another prefix abstraction.
- Did not add Oban/governance/outbound catalog expectations here; those files are owned by later Phase 59 plans.

## Deviations from Plan

None - plan executed as scoped.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Verification

- PASS: `mix test test/cairnloop/migrations_test.exs --warnings-as-errors`
- PASS: `mix compile --warnings-as-errors`

DB-backed migration setup proof remains intentionally deferred until Plan 59-05/59-08/59-07, after host-support and remaining library migration families are converted.

## Next Phase Readiness

Ready for Plan 59-03. Core runtime facades can now target the same configured schema that the first migration family creates.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
