---
phase: 53-demo-runtime-contract
plan: "04"
subsystem: database
tags: [seeds, postgres, oban, exunit, trailmark]

requires:
  - phase: 53-01
    provides: setup alias runs priv/repo/seeds.exs
  - phase: 53-02
    provides: quiet example runtime config for DB-backed seed checks
provides:
  - Verified deterministic Trailmark seed data contract
  - Verified DB-backed seed idempotency tests
  - Verified synchronous Oban drain readiness
affects: [demo-runtime-contract, example-app, docker-demo]

tech-stack:
  added: []
  patterns:
    - Facade-backed deterministic seed script
    - DB-backed ExUnit suite tagged :requires_postgres
    - In-process Code.eval_file seed verification

key-files:
  created: []
  modified:
    - examples/cairnloop_example/priv/repo/seeds.exs
    - examples/cairnloop_example/test/cairnloop_example/seeds_test.exs

key-decisions:
  - "Keep seed data behind setup and DB-backed :requires_postgres tests rather than adding a separate fixture command."

patterns-established:
  - "Seed validation evaluates priv/repo/seeds.exs inside the sandboxed test process and asserts row counts/idempotency."
  - "Seed script drains Oban with with_recursion before returning so chunks are ready immediately."

requirements-completed:
  - RUNT-01
  - RUNT-05

duration: 5 min
completed: 2026-06-28
status: complete
---

# Phase 53 Plan 04: Seed Readiness Contract Summary

**Trailmark seed data was verified through the DB-backed example test suite, proving immediate chunks, review tasks, showcase states, MCP token data, and idempotent reruns.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-28T16:09:00Z
- **Completed:** 2026-06-28T16:13:51Z
- **Tasks:** 2 completed
- **Files modified:** 0

## Accomplishments

- Verified `priv/repo/seeds.exs` keeps facade calls, natural-key guards, and `Oban.drain_queue(queue: :default, with_recursion: true)`.
- Verified `CairnloopExample.SeedsTest` is DB-backed, `:requires_postgres`, sandboxed, and evaluates the seed script from the test process.
- Ran the focused seed suite against the root Docker Postgres service: 6 tests, 0 failures.

## Task Commits

No production source commit was needed; the planned seed and seed-test contract was already present.

1. **Task 1: Preserve deterministic seed builders and Oban drain** - verified existing seed source contract.
2. **Task 2: Lock DB-backed seed contract tests** - verified with focused `:requires_postgres` test suite.

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `examples/cairnloop_example/priv/repo/seeds.exs` - Verified deterministic Trailmark seed builders, facade calls, natural-key guards, and Oban drain.
- `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` - Verified DB-backed seed suite, sandboxed `Code.eval_file/1`, row-count/idempotency assertions, and `:requires_postgres` marker.

## Decisions Made

- Keep seed validation behind the DB-backed `:requires_postgres` example lane so DB-free headless suites remain fast.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

The seed tests emit expected module redefinition warnings because `Code.eval_file/1` evaluates `CairnloopExample.SeedRun` multiple times for idempotency checks. The suite passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 53-05 final runtime documentation and verification. Trailmark data availability is DB-backed and proven.

## Verification

- `rg -n -F 'Oban.drain_queue(queue: :default, with_recursion: true)' examples/cairnloop_example/priv/repo/seeds.exs` - passed.
- `rg -n -F 'KnowledgeAutomation.ensure_review_task_for_suggestion' examples/cairnloop_example/priv/repo/seeds.exs` - passed.
- `rg -n -F '@moduletag :requires_postgres' examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` - passed.
- `rg -n -F 'Code.eval_file' examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` - passed.
- `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix test --only requires_postgres test/cairnloop_example/seeds_test.exs` - passed; 6 tests, 0 failures.

## Self-Check: PASSED

- Required source patterns exist.
- DB-backed focused seed suite passed.
- Plan acceptance criteria passed.

---
*Phase: 53-demo-runtime-contract*
*Completed: 2026-06-28*
