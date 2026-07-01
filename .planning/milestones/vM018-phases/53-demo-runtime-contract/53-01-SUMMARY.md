---
phase: 53-demo-runtime-contract
plan: "01"
subsystem: infra
tags: [mix, ecto, migrations, seeds, example-app]

requires: []
provides:
  - Verified host-before-library migration setup alias
  - Verified local path dependency dogfooding contract
  - Verified setup-owned Trailmark seed execution
affects: [demo-runtime-contract, example-app, docker-demo]

tech-stack:
  added: []
  patterns:
    - Two-phase Ecto migration alias with Mix.Task.reenable/1
    - Local path dependency for repo dogfooding
    - Seed execution inside ecto.setup

key-files:
  created: []
  modified:
    - examples/cairnloop_example/mix.exs

key-decisions:
  - "Preserve the existing two-phase migration alias rather than merging host and library migration paths."

patterns-established:
  - "Run host migrations first, re-enable ecto.migrate, then run Cairnloop library migrations."
  - "Keep Trailmark seed loading in ecto.setup; do not add a separate fixture command."

requirements-completed:
  - RUNT-01
  - RUNT-02
  - RUNT-05

duration: 4 min
completed: 2026-06-28
status: complete
---

# Phase 53 Plan 01: Setup Alias Contract Summary

**The example app setup alias was verified to dogfood the local Cairnloop path dependency, run host migrations before library migrations, and load Trailmark seeds during setup.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-28T16:07:00Z
- **Completed:** 2026-06-28T16:11:15Z
- **Tasks:** 2 completed
- **Files modified:** 0

## Accomplishments

- Verified `examples/cairnloop_example/mix.exs` keeps `{:cairnloop, path: "../.."}` for local dogfooding.
- Verified `ecto.setup`, `test`, and `test.e2e` run two ordered migration phases with `Mix.Task.reenable("ecto.migrate")` between them.
- Ran `mix ecto.reset` against the root Docker Postgres service, proving migrations and `priv/repo/seeds.exs` execute in the intended order.

## Task Commits

No production source commit was needed; the planned source contract was already present in `examples/cairnloop_example/mix.exs`.

1. **Task 1: Preserve path dependency dogfooding and ordered setup aliases** - verified existing source contract.
2. **Task 2: Prove setup ordering with DB-backed commands** - verified with `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix ecto.reset`.

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `examples/cairnloop_example/mix.exs` - Verified existing setup alias, migration ordering, seed execution, and path dependency.

## Decisions Made

- Preserve the existing two-phase alias shape; one merged `ecto.migrate` call would let Ecto globally sort host and library migration paths.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 53-03 Docker readiness. The manual setup path has DB-backed evidence for migration order and seed loading.

## Verification

- `cd examples/cairnloop_example && mix compile --warnings-as-errors` - passed.
- `rg -n -F 'Mix.Task.reenable("ecto.migrate")' examples/cairnloop_example/mix.exs` - passed.
- `rg -n -F 'run priv/repo/seeds.exs' examples/cairnloop_example/mix.exs` - passed.
- `rg -n -F '{:cairnloop, path: "../.."}' examples/cairnloop_example/mix.exs` - passed.
- `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix ecto.reset` - passed; output showed example host migrations before Cairnloop library migrations and seed completion with 20 conversations, 5 articles, 3 gap candidates, 1 article suggestion, and 1 drained embedding job.

## Self-Check: PASSED

- Required source patterns exist in `examples/cairnloop_example/mix.exs`.
- DB-backed reset path completed successfully.
- Plan acceptance criteria passed.

---
*Phase: 53-demo-runtime-contract*
*Completed: 2026-06-28*
