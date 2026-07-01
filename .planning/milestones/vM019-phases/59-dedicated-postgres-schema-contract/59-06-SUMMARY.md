---
phase: 59-dedicated-postgres-schema-contract
plan: "06"
subsystem: database
tags: [postgres, ecto, schema-prefix, example-app]
requires:
  - phase: 59-05
    provides: Installer/test-host prefix substrate
provides:
  - Example app dedicated-schema default config
  - Prefix-aware example support migrations
  - Example catalog proof for support tables and Oban placement
  - Host-safe example vector rollback
affects: [phase-59, example-app, db-prefix, migrations]
tech-stack:
  added: []
  patterns:
    - Example support migrations use `Cairnloop.SchemaPrefix.configured/0`
    - Example setup keeps Oban in public while Cairnloop support tables live in `cairnloop`
key-files:
  created:
    - examples/cairnloop_example/test/cairnloop_example/schema_prefix_contract_test.exs
    - .planning/phases/59-dedicated-postgres-schema-contract/59-06-SUMMARY.md
  modified:
    - examples/cairnloop_example/config/config.exs
    - examples/cairnloop_example/README.md
    - examples/cairnloop_example/priv/repo/migrations/20240101000000_add_vector_extension.exs
    - examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs
    - examples/cairnloop_example/priv/repo/migrations/20260525201623_create_cairnloop_drafts.exs
    - examples/cairnloop_example/priv/repo/migrations/20260525201624_add_run_key_to_messages.exs
    - examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs
    - test/cairnloop/migrations_test.exs
key-decisions:
  - "The example app now dogfoods `schema_prefix: \"cairnloop\"` as the new-install default."
  - "The example vector extension migration creates `vector` but does not drop it on rollback because the extension is shared database infrastructure."
  - "Example public compatibility docs are narrow and limited to intentional `schema_prefix: \"public\"` compatibility."
patterns-established:
  - "Example app tests include a catalog contract for support table placement and Oban host ownership."
requirements-completed: []
requirements-advanced: [DB-01, DB-04, DB-06, DB-07]
duration: 8 min
completed: 2026-06-30
status: complete
---

# Phase 59 Plan 06: Example Dedicated Schema Summary

**The example app now proves the dedicated `cairnloop` schema default instead of silently using public support tables.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-30T16:14:44Z
- **Completed:** 2026-06-30T16:22:44Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added red shared migration/config scans for example schema prefix, support-domain DDL prefixing, Oban host ownership, and no `DROP EXTENSION vector`.
- Added an example app catalog test that asserts support tables and the `run_key` column live in `cairnloop`, with `oban_jobs` remaining in `public`.
- Set the example app Cairnloop config to `schema_prefix: "cairnloop"`.
- Converted example conversations/messages/drafts/run-key migrations to create the configured schema and pass `prefix: prefix` through support-domain DDL.
- Changed example vector rollback to a no-op so the demo does not drop shared `vector`.
- Added a narrow example README note for dedicated-schema default and intentional `"public"` compatibility.
- Updated the example ChatLive test mock to accept repo opts, matching prefix-aware runtime reads.

## Task Commits

1. **Task 1/2 red contracts: Example source and catalog proof** - `a6b4fb6` (test)
2. **Task 1/2 implementation: Example config, migrations, docs, mock opts** - `8d43cd3` (fix)

**Plan metadata:** this summary commit.

## Files Modified

- `test/cairnloop/migrations_test.exs` - Example config/migration/vector/Oban source scans.
- `examples/cairnloop_example/test/cairnloop_example/schema_prefix_contract_test.exs` - Example DB catalog proof.
- `examples/cairnloop_example/config/config.exs` - Dedicated schema default.
- `examples/cairnloop_example/priv/repo/migrations/*.exs` - Prefix-aware support DDL and no-op vector rollback.
- `examples/cairnloop_example/README.md` - Narrow DB-prefix compatibility note.
- `examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs` - MockRepo `get/3` support for prefix opts.

## Deviations from Plan

- Local Postgres was listening on `5432`, while the example app defaults to `5433`; verification used `PGPORT=5432`.
- The default example test endpoint port `4002` was already in use; verification used `PHX_TEST_PORT=4102`.
- I ran the full example non-E2E test lane after the direct contract test. It exposed a prefix-opts mock arity issue in `ChatLiveTest`, which was fixed in the implementation commit.

## Issues Encountered

- The first example `mix ecto.setup` attempt failed only because `4002` was already bound locally; rerun with `PHX_TEST_PORT=4102` passed.
- The worktree had a pre-existing README Elixir/OTP version edit; it was deliberately left unstaged.

## User Setup Required

None.

## Verification

- RED: `mix test test/cairnloop/migrations_test.exs --warnings-as-errors` failed as expected on missing example `schema_prefix`, unprefixed support migrations, and vector rollback dropping `vector`.
- PASS: `mix test test/cairnloop/migrations_test.exs --warnings-as-errors` (9 tests, 0 failures)
- PASS: `mix compile --warnings-as-errors`
- PASS: `PGPORT=5432 MIX_ENV=test mix ecto.drop --quiet || true`
- PASS: `PGPORT=5432 PHX_TEST_PORT=4102 MIX_ENV=test mix ecto.setup`
- PASS: `PGPORT=5432 PHX_TEST_PORT=4102 mix test test/cairnloop_example/schema_prefix_contract_test.exs` (3 tests, 0 failures)
- PASS: `PGPORT=5432 PHX_TEST_PORT=4102 mix test` in `examples/cairnloop_example` (34 tests, 0 failures, 14 excluded)
- PASS: Source scan confirmed dedicated example config, no example `DROP EXTENSION vector`, prefixed example support DDL, and unprefixed example Oban migration.

## Next Phase Readiness

Plan 59-06 is complete. Wave 5 can continue with 59-10 worker and automation runtime prefix coverage.

## Self-Check: PASSED

---
*Phase: 59-dedicated-postgres-schema-contract*
*Completed: 2026-06-30*
