---
phase: 59-dedicated-postgres-schema-contract
plan: "01"
subsystem: database
tags: [postgres, ecto, schema-prefix, integration-tests]
requires:
  - phase: vM019
    provides: Dedicated schema decision and public compatibility requirement
provides:
  - Canonical schema prefix helper semantics for dedicated and public modes
  - Dedicated-schema default test compilation path
  - Red DB-backed integration contracts for migration/runtime prefix conversion
affects: [phase-59, db-prefix, migrations, runtime-facades, installer, example-app]
tech-stack:
  added: []
  patterns:
    - Central Cairnloop.SchemaPrefix helper converts schema_prefix into Ecto prefix opts
    - Catalog assertions filter by table_schema, schemaname, and namespace
key-files:
  created:
    - lib/cairnloop/schema_prefix.ex
    - test/cairnloop/schema_prefix_test.exs
    - test/integration/schema_prefix_contract_test.exs
    - test/integration/public_schema_compatibility_test.exs
    - test/integration/schema_prefix_runtime_test.exs
  modified:
    - config/test.exs
key-decisions:
  - "CAIRNLOOP_SCHEMA_PREFIX=public is the explicit public compile/test proof path; default test compilation now uses cairnloop."
  - "repo_opts/1 strips helper-only :schema_prefix before returning Ecto options."
  - "Wave 1 integration contracts are intentionally red until later plans convert migrations and runtime access."
patterns-established:
  - "Postgres catalog tests must filter by table_schema/schemaname/namespace so public collisions cannot satisfy dedicated-schema assertions."
requirements-completed: [DB-01, DB-02, DB-06]
duration: 10 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 01: Prefix Helper and Contract Tests Summary

**Schema-prefix helper semantics now default tests to `cairnloop`, prove explicit public compatibility, and define red DB-backed contracts for downstream migration/runtime work.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-30T15:04:00Z
- **Completed:** 2026-06-30T15:14:43Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Locked `Cairnloop.SchemaPrefix` behavior for dedicated default, explicit `"public"`, legacy nil/empty compatibility, and unsafe identifier rejection.
- Changed `config/test.exs` so normal test compilation uses `schema_prefix: "cairnloop"` while `CAIRNLOOP_SCHEMA_PREFIX=public` drives the public compatibility compile path.
- Added three DB-backed integration files that currently fail on missing dedicated-schema placement/runtime behavior and will guide later Phase 59 waves.

## Task Commits

1. **Task 1: Lock prefix helper semantics and test compile default** - `cd31476` (test)
2. **Task 2: Create concrete DB-backed contract tests for downstream waves** - `a214265` (test)

**Plan metadata:** this summary commit.

## Files Created/Modified

- `lib/cairnloop/schema_prefix.ex` - Canonical helper; strips helper-only `:schema_prefix` from repo opts and emits Ecto `:prefix`.
- `test/cairnloop/schema_prefix_test.exs` - Helper/config/source-scan contract coverage.
- `config/test.exs` - Dedicated default with `CAIRNLOOP_SCHEMA_PREFIX` override.
- `test/integration/schema_prefix_contract_test.exs` - Dedicated schema object placement, index, FK, trigger-function, and public-collision assertions.
- `test/integration/public_schema_compatibility_test.exs` - Explicit public compile-mode and public table proof.
- `test/integration/schema_prefix_runtime_test.exs` - Runtime/collision coverage for Chat, KB/Retrieval, Governance/Outbound/MCP, workers, doctor, and Oban boundary.

## Decisions Made

- `CAIRNLOOP_SCHEMA_PREFIX=public` is the preferred explicit public compatibility proof path because it exercises compile-time schema prefixes instead of runtime-only config mutation.
- Empty string and `"nil"` env values map to legacy nil compatibility in `config/test.exs`; ordinary default stays `"cairnloop"`.
- The integration contracts intentionally fail today because downstream migrations/runtime code still target public objects.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `repo_opts/1` leaked helper-only options**
- **Found during:** Task 1 (helper tests)
- **Issue:** `Cairnloop.SchemaPrefix.repo_opts(timeout: 1_000, schema_prefix: "public")` returned the internal `:schema_prefix` key alongside Ecto opts.
- **Fix:** Compute the prefix first, delete `:schema_prefix`, then return ordinary repo opts with `:prefix`.
- **Files modified:** `lib/cairnloop/schema_prefix.ex`, `test/cairnloop/schema_prefix_test.exs`
- **Verification:** `mix test test/cairnloop/schema_prefix_test.exs --warnings-as-errors`
- **Committed in:** `cd31476`

---

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** The fix made the helper safer for downstream Ecto calls without changing public API.

## Issues Encountered

- The exact public-mode command from the plan uses comma separators in `mix do`, which Elixir 1.19 warns are deprecated. The command still passed; later commands can use `+` separators when the plan does not require the exact string.
- After the public-mode compile check, the test build had to be cleaned/recompiled back to default `"cairnloop"` before running dedicated-mode integration tests. That is expected compile-env behavior.

## User Setup Required

None - no external service configuration required.

## Verification

- PASS: `mix test test/cairnloop/schema_prefix_test.exs --warnings-as-errors`
- PASS: `MIX_ENV=test mix compile --force --warnings-as-errors`
- PASS: `CAIRNLOOP_SCHEMA_PREFIX=public MIX_ENV=test mix do clean, compile --force --warnings-as-errors, test test/cairnloop/schema_prefix_test.exs --warnings-as-errors`
- PASS as expected-red contract: `mix test --include integration test/integration/schema_prefix_contract_test.exs test/integration/public_schema_compatibility_test.exs test/integration/schema_prefix_runtime_test.exs --warnings-as-errors` exited nonzero with catalog/runtime assertions and no compilation, syntax, token, or undefined-function failures.

## Next Phase Readiness

Ready for Wave 2. Plans 59-02 and 59-03 can now make the migration and core runtime contracts pass against the red assertions added here.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
