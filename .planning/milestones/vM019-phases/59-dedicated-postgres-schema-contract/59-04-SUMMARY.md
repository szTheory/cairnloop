---
phase: 59-dedicated-postgres-schema-contract
plan: "04"
subsystem: database
tags: [postgres, ecto, schema-prefix, governance, outbound, doctor]
requires:
  - phase: 59-09
    provides: Retrieval runtime prefix patterns and Oban boundary evidence
provides:
  - Prefix-aware governance proposal, approval, action-event, and audit read/write paths
  - Prefix-aware outbound message and bulk-envelope persistence without redirecting Oban jobs
  - Doctor configured-prefix diagnostics with public compatibility and invalid-config copy
  - DB-backed runtime collision contract for governance/outbound paths
affects: [phase-59, db-prefix, governance, outbound, doctor, diagnostics]
tech-stack:
  added: []
  patterns:
    - Runtime facades use `Cairnloop.SchemaPrefix.repo_opts/0` for support-domain Repo writes and reads
    - Query facades compose local prefixed sources with `put_query_prefix/2`
    - Outbound `Ecto.Multi` support-domain inserts carry prefix opts while Oban job inserts stay host-owned
key-files:
  created:
    - .planning/phases/59-dedicated-postgres-schema-contract/59-04-SUMMARY.md
  modified:
    - lib/cairnloop/governance.ex
    - lib/cairnloop/outbound.ex
    - lib/cairnloop/doctor.ex
    - lib/mix/tasks/cairnloop.doctor.ex
    - test/cairnloop/governance_test.exs
    - test/cairnloop/outbound_test.exs
    - test/cairnloop/doctor_test.exs
    - test/integration/schema_prefix_runtime_test.exs
key-decisions:
  - "Governance stays on its sequential co-commit style; no Ecto.Multi was introduced."
  - "Doctor reports prefix configuration but explicitly does not claim DB catalog proof."
  - "Outbound prefixes Message/BulkEnvelope operations and leaves Oban.Job inserts unprefixed."
patterns-established:
  - "Headless MockRepo tests record Repo/Multi opts to prove prefix propagation without a live DB."
requirements-completed: []
requirements-advanced: [DB-05, DB-06]
duration: 28 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 04: Governance, Outbound, And Doctor Prefixing Summary

**Governance and outbound runtime persistence now carries Cairnloop's configured support prefix, and doctor reports prefix posture honestly.**

## Performance

- **Duration:** 28 min
- **Started:** 2026-06-30T15:36:00Z
- **Completed:** 2026-06-30T16:04:32Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added red headless contracts for governance proposal/event/approval Repo opts, outbound Message/BulkEnvelope Multi opts, and doctor prefix copy.
- Added `SchemaPrefix.repo_opts/0` and prefixed query-source handling to governance reads/writes while preserving the no-`Ecto.Multi` invariant.
- Added prefix opts to outbound support-domain inserts while leaving Oban job inserts host-owned and unprefixed.
- Added doctor findings for dedicated prefix, explicit `"public"` compatibility, nil legacy compatibility, and invalid prefix failures without raw exception output.
- Extended `schema_prefix_runtime_test.exs` with DB-backed public-collision coverage for governance/outbound writes and the Oban boundary.

## Task Commits

1. **Task 1/2 red contracts: Governance, outbound, and doctor prefix behavior** - `23487ac` (test)
2. **Task 1: Prefix governance and outbound persistence / Task 2: Add doctor diagnostics** - `d560839` (fix)

**Plan metadata:** this summary commit.

## Files Modified

- `lib/cairnloop/governance.ex` - Prefix-aware proposal, approval, event, conversation, and bulk-envelope facade reads/writes.
- `lib/cairnloop/outbound.ex` - Prefix-aware Message and BulkEnvelope inserts with Oban job inserts left unprefixed.
- `lib/cairnloop/doctor.ex` - Configured-prefix diagnostic with public compatibility and invalid-config handling.
- `lib/mix/tasks/cairnloop.doctor.ex` - Doctor task documentation now names prefix diagnostics.
- `test/cairnloop/governance_test.exs` - MockRepo prefix-opt assertions for governance persistence and reads.
- `test/cairnloop/outbound_test.exs` - Multi/direct insert prefix assertions and Oban host-owned assertions.
- `test/cairnloop/doctor_test.exs` - Dedicated/public/nil/invalid prefix diagnostic assertions.
- `test/integration/schema_prefix_runtime_test.exs` - Governance/outbound public-collision integration contract.

## Deviations from Plan

None - plan executed as scoped.

## Issues Encountered

- The worktree already had unrelated auditor `@behaviour` cleanup hunks in `test/cairnloop/outbound_test.exs`. Those hunks were deliberately left unstaged and are not part of the 59-04 commits.

## User Setup Required

None.

## Verification

- PASS: `mix test test/cairnloop/governance_test.exs test/cairnloop/outbound_test.exs test/cairnloop/doctor_test.exs --warnings-as-errors` (125 tests, 0 failures, 1 excluded)
- PASS: `mix compile --warnings-as-errors`
- PASS: `mix test --exclude integration test/integration/schema_prefix_runtime_test.exs --warnings-as-errors` compiled the integration contract file with 9 integration tests excluded
- PASS: `rg -n "SchemaPrefix.*Oban|Oban.*SchemaPrefix|oban_jobs.*SchemaPrefix|SchemaPrefix.*oban_jobs|prefix:.*Oban|Oban.*prefix:" lib/cairnloop test/cairnloop test/integration priv/repo priv/test_host` found no production Oban prefixing

## Next Phase Readiness

Plan 59-04 is complete. Wave 4 can continue with 59-05 installer/test-host dedicated-schema setup, then Wave 5 runtime worker/example coverage.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
