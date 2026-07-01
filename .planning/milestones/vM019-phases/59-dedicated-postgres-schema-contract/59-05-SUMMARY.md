---
phase: 59-dedicated-postgres-schema-contract
plan: "05"
subsystem: database
tags: [postgres, ecto, schema-prefix, installer, migrations]
requires:
  - phase: 59-01
    provides: Schema prefix helper contract
  - phase: 59-02
    provides: Prefix-aware migration pattern
  - phase: 59-08
    provides: Governance/MCP/outbound migration catalog contract
provides:
  - Prefix-aware installer-generated host migration and setup copy
  - Prefix-aware integration test-host support migrations
  - Explicit public-schema compatibility upgrade notes
  - Clean test DB proof for dedicated-schema object placement
affects: [phase-59, db-prefix, installer, integration-host, docs]
tech-stack:
  added: []
  patterns:
    - Installer and test-host migrations use `Cairnloop.SchemaPrefix.configured/0`
    - Support-domain DDL passes `prefix: prefix` in source
    - Oban migration remains host-owned and unprefixed
key-files:
  created:
    - UPGRADING.md
    - .planning/phases/59-dedicated-postgres-schema-contract/59-05-SUMMARY.md
  modified:
    - lib/mix/tasks/cairnloop/install.ex
    - test/cairnloop/tasks/install_test.exs
    - test/cairnloop/migrations_test.exs
    - priv/test_host/migrations/20260101000000_create_host_owned_tables.exs
    - priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs
    - priv/test_host/migrations/20260527070000_add_conversation_slas.exs
    - priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs
    - lib/cairnloop/knowledge_automation/gap_candidate_membership.ex
    - test/integration/schema_prefix_contract_test.exs
    - test/integration/schema_prefix_runtime_test.exs
key-decisions:
  - "Installer guidance now treats `config :cairnloop, :schema_prefix, \"cairnloop\"` plus source-qualified migrations as the contract."
  - "Explicit `\"public\"` is the preferred compatibility setting for existing public-schema installs; nil remains accepted only as legacy compatibility."
  - "The gap-candidate membership unique index now has an explicit short name so Postgres identifier truncation cannot break catalog assertions or changeset mapping."
patterns-established:
  - "Source scans cover test-host support-domain migrations while allowlisting only the host-owned Oban migration."
requirements-completed: []
requirements-advanced: [DB-01, DB-02, DB-03, DB-06]
duration: 11 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 05: Installer And Test-Host Prefix Setup Summary

**Installer output and the integration test host now create Cairnloop support-domain objects in the configured schema by default.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-06-30T16:04:32Z
- **Completed:** 2026-06-30T16:15:33Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Added red installer and migration-source contracts for explicit `"public"` compatibility, no dependency-migration `--prefix` shortcut, prefix-aware generated host migration text, and test-host support DDL drift detection.
- Updated `mix cairnloop.install` copy to document repo setup, default dedicated `cairnloop` prefix, explicit `"public"` compatibility, legacy nil compatibility, and dependency migrations without `--prefix`.
- Converted test-host conversations, messages, drafts, run-key, and SLA support migrations to use `Cairnloop.SchemaPrefix.configured/0`, schema creation, and `prefix: prefix` on support-domain DDL.
- Added `UPGRADING.md` with narrow DB-prefix upgrade guidance, public compatibility posture, dedicated-schema move steps, and shared infrastructure notes.
- Stabilized the gap-candidate membership unique-index name so the DB catalog contract does not depend on Postgres identifier truncation.
- Fixed UUID raw SQL helpers in `schema_prefix_runtime_test.exs` so the integration runtime contract works with Postgrex UUID parameter encoding.

## Task Commits

1. **Task 1/2 red contracts: Installer and test-host prefix behavior** - `8dbd415` (test)
2. **Task 1/2/3 implementation: Installer, test-host, DB proof fixes** - `87323b5` (fix)

**Plan metadata:** this summary commit.

## Files Modified

- `lib/mix/tasks/cairnloop/install.ex` - Prefix-aware generated migration and updated setup guidance.
- `test/cairnloop/tasks/install_test.exs` - Installer copy and generated migration contracts.
- `test/cairnloop/migrations_test.exs` - Test-host support migration prefix scanner with Oban boundary allowlist.
- `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs` - Prefix-aware conversations/messages/drafts setup.
- `priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs` - Prefix-aware message alter/index.
- `priv/test_host/migrations/20260527070000_add_conversation_slas.exs` - Prefix-aware SLA table, reference, and indexes.
- `UPGRADING.md` - Public compatibility and dedicated-schema migration notes.
- `priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs` - Explicit short unique-index name.
- `lib/cairnloop/knowledge_automation/gap_candidate_membership.ex` - Matching unique constraint name.
- `test/integration/schema_prefix_contract_test.exs` / `test/integration/schema_prefix_runtime_test.exs` - Catalog expectation and UUID helper fixes.

## Deviations from Plan

- The plan's `mix test.integration --only integration test/integration/schema_prefix_contract_test.exs` command expands through the project alias into the full integration suite. I used direct `mix test --only integration test/integration/schema_prefix_contract_test.exs` for the scoped DB proof after confirming the alias behavior.
- The clean DB proof exposed an existing too-long auto-generated gap-membership index expectation and UUID raw SQL helper failures. Both were fixed because they directly blocked the dedicated-schema contract.

## Issues Encountered

- `mix test.integration --only integration test/integration/schema_prefix_contract_test.exs` broadened to the full integration suite and failed on unrelated public-prefix/UI paths before the scoped direct command was used.
- `mix test test/cairnloop/knowledge_automation/gap_candidate_test.exs --warnings-as-errors` still has an unrelated failure: `KnowledgeAutomation.refresh_gap_candidates/1` is not exported.
- The worktree still contains unrelated dirty files from outside this plan; they were left unstaged.

## User Setup Required

None.

## Verification

- RED: `mix test test/cairnloop/tasks/install_test.exs test/cairnloop/migrations_test.exs --warnings-as-errors` failed as expected before implementation on missing `"public"` installer copy and missing test-host prefix setup.
- PASS: `mix test test/cairnloop/tasks/install_test.exs test/cairnloop/migrations_test.exs --warnings-as-errors` (11 tests, 0 failures)
- PASS: `mix compile --warnings-as-errors`
- PASS: `MIX_ENV=test mix ecto.drop --quiet -r Cairnloop.Repo -r Chimeway.Repo || true`
- PASS: `mix test.setup`
- PASS: `mix test --only integration test/integration/schema_prefix_contract_test.exs` (6 tests, 0 failures)
- PASS: `mix test --only integration test/integration/schema_prefix_runtime_test.exs` (9 tests, 0 failures)
- PASS: Source scan confirmed intentional `"public"` compatibility copy, no old dependency migration `--prefix` command, prefixed support DDL, and unprefixed Oban migration calls.

## Next Phase Readiness

Plan 59-05 is complete. Wave 4 now has both 59-04 and 59-05 complete; run the wave gate before starting Wave 5.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
