---
phase: 59-dedicated-postgres-schema-contract
plan: "08"
subsystem: database
tags: [postgres, ecto-migrations, schema-prefix, governance, mcp, outbound]
requires:
  - phase: 59-02
    provides: Prefix-aware migration source-scan pattern
provides:
  - Prefix-aware governance, review-task, MCP token, and outbound bulk-envelope migrations
  - Repo-wide library migration source-scan gate for Cairnloop-owned DDL helpers
  - Dedicated-schema catalog assertions for governance/MCP/outbound object placement
affects: [phase-59, db-prefix, migrations, governance, mcp, outbound]
tech-stack:
  added: []
  patterns:
    - `prefix = Cairnloop.SchemaPrefix.configured()` in every library migration
    - `prefix: prefix` on support-domain tables, indexes, FKs, and alters
    - Reversible `ensure_schema/1` helpers for change-style table-creation migrations
key-files:
  created:
    - .planning/phases/59-dedicated-postgres-schema-contract/59-08-SUMMARY.md
  modified:
    - priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs
    - priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs
    - priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs
    - priv/repo/migrations/20260524120001_add_tool_approvals.exs
    - priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs
    - priv/repo/migrations/20260524120200_relax_action_event_to_status_null.exs
    - priv/repo/migrations/20260525000000_add_execution_outcome_index.exs
    - priv/repo/migrations/20260526084518_create_cairnloop_mcp_tokens.exs
    - priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs
    - test/cairnloop/migrations_test.exs
    - test/integration/schema_prefix_contract_test.exs
key-decisions:
  - "Conversation references from governance migrations use the Cairnloop support prefix because conversations are support-domain tables."
  - "Oban remains untouched; no library migration introduces Oban tables or Oban.Migration."
patterns-established:
  - "The migration source scan now covers every `priv/repo/migrations/*.exs` library migration."
requirements-completed: []
requirements-advanced: [DB-03, DB-06]
duration: 7 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 08: Governance/MCP/Outbound Migration Prefixing Summary

**Governance, MCP, and outbound library migrations now qualify Cairnloop-owned DDL through the configured support schema.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-30T15:35:00Z
- **Completed:** 2026-06-30T15:41:52Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Added configured-prefix handling to the remaining library migration family: review tasks/events, governance proposals/events/approvals, MCP tokens, and outbound bulk envelopes.
- Added `prefix: prefix` to support-domain tables, indexes, foreign keys, alters, and filtered indexes.
- Expanded `test/cairnloop/migrations_test.exs` so future repo migrations cannot add unprefixed Cairnloop-owned DDL helper calls.
- Extended the shared integration catalog contract with governance, MCP, outbound tables, indexes, and foreign keys.

## Task Commits

1. **Task 1: Qualify governance, MCP, and outbound migrations** - `c35bc36` (fix)
2. **Task 2: Add governance, MCP, and outbound catalog assertions** - `3697eab` (test)

**Plan metadata:** this summary commit.

## Files Modified

- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` - Prefix-aware review task/event tables, FKs, and indexes.
- `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs` - Prefix-aware governance proposal/action-event tables, FKs, and indexes.
- `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs` - Prefix-aware proposal alter, conversation FK, and timeline index.
- `priv/repo/migrations/20260524120001_add_tool_approvals.exs` - Prefix-aware approvals table, indexes, and one-active-lane constraint.
- `priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs` - Prefix-aware proposal alter.
- `priv/repo/migrations/20260524120200_relax_action_event_to_status_null.exs` - Prefix-aware action-event alter.
- `priv/repo/migrations/20260525000000_add_execution_outcome_index.exs` - Prefix-aware filtered execution outcome index.
- `priv/repo/migrations/20260526084518_create_cairnloop_mcp_tokens.exs` - Prefix-aware MCP token table and unique index.
- `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs` - Prefix-aware outbound bulk envelope table and indexes.
- `test/cairnloop/migrations_test.exs` - Source scan broadened to all library migrations.
- `test/integration/schema_prefix_contract_test.exs` - Dedicated-schema catalog expectations for governance/MCP/outbound objects.

## Deviations from Plan

None - plan executed as scoped.

## Issues Encountered

None.

## User Setup Required

None.

## Verification

- PASS: `mix test test/cairnloop/migrations_test.exs --warnings-as-errors`
- PASS: `mix compile --warnings-as-errors`
- PASS: `mix test --exclude integration test/integration/schema_prefix_contract_test.exs --warnings-as-errors` compiled the integration contract file with 6 integration tests excluded.

## Next Phase Readiness

Ready for Plan 59-09. Remaining Wave 3 work is runtime SQL/provider/worker prefixing for retrieval and bulk indexing paths.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
