---
phase: 53-demo-runtime-contract
plan: "03"
subsystem: infra
tags: [docker, compose, phoenix, healthcheck, routing]

requires:
  - phase: 53-02
    provides: Quiet dev/Docker runtime config consumed by the web container
provides:
  - Docker demo Compose stack with private pgvector database
  - Web healthcheck against /health
  - Docker runtime command that runs setup before Phoenix serves
affects: [demo-runtime-contract, docker-demo, phase-54-wrapper]

tech-stack:
  added: []
  patterns:
    - Compose service_healthy DB dependency before web boot
    - Private DB service with dynamic loopback web publication
    - Operations routes outside Phoenix browser pipeline

key-files:
  created:
    - examples/cairnloop_example/compose.demo.yml
    - examples/cairnloop_example/Dockerfile.demo
  modified:
    - examples/cairnloop_example/lib/cairnloop_example_web/router.ex

key-decisions:
  - "Keep /health mounted through Cairnloop.Router.cairnloop_operations/1 outside the browser pipeline; no example-specific health controller."
  - "Do not publish Postgres from the demo Compose stack; publish only Phoenix on loopback."

patterns-established:
  - "Docker demo web service waits for db service_healthy and then checks http://127.0.0.1:4000/health."
  - "Dockerfile.demo runs mix setup before mix phx.server so migrations and seeds finish before readiness."

requirements-completed:
  - RUNT-03
  - RUNT-04

duration: 3 min
completed: 2026-06-28
status: complete
---

# Phase 53 Plan 03: Docker Readiness Contract Summary

**The demo Docker stack now has a private pgvector database, a web container that runs setup before serving, and Compose readiness tied to Cairnloop's `/health` operations route.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-28T16:09:00Z
- **Completed:** 2026-06-28T16:12:09Z
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments

- Verified `/health` and `/metrics` are mounted through `Cairnloop.Router.cairnloop_operations()` outside the browser pipeline.
- Added `examples/cairnloop_example/compose.demo.yml` with private `pgvector/pgvector:pg16`, DB health gating, loopback/dynamic web port publication, and `/health` web healthcheck.
- Added `examples/cairnloop_example/Dockerfile.demo` with curl/Postgres client tooling and `mix setup && exec mix phx.server`.

## Task Commits

1. **Task 1: Keep operations health route outside browser pipeline** - verified existing router source contract.
2. **Task 2: Lock Compose readiness and setup-before-server Docker command** - `cf0592e` (`feat`)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` - Verified operations endpoints remain outside the browser pipeline.
- `examples/cairnloop_example/compose.demo.yml` - Docker demo stack, private DB, web dependency, and healthcheck contract.
- `examples/cairnloop_example/Dockerfile.demo` - Demo image and setup-before-server command.

## Decisions Made

- Reuse the sealed `Cairnloop.Router.cairnloop_operations()` health route instead of adding an example-specific health controller.
- Keep the demo database private to Compose and expose only Phoenix via a loopback host port.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

The compile and route commands briefly waited on the Mix build directory lock from concurrent verification commands, then completed successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 53-04 seed validation and final Plan 53-05 Docker smoke; Compose now has the readiness contract those checks rely on.

## Verification

- `cd examples/cairnloop_example && mix compile --warnings-as-errors` - passed.
- `cd examples/cairnloop_example && mix phx.routes | rg '/health|/metrics'` - passed; routes include `/health` and `/metrics`.
- `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` - passed.
- `rg -n -F 'curl -fsS http://127.0.0.1:4000/health' examples/cairnloop_example/compose.demo.yml` - passed.
- `rg -n -F 'mix setup && exec mix phx.server' examples/cairnloop_example/Dockerfile.demo` - passed.

## Self-Check: PASSED

- Key created files exist.
- Docker readiness commit exists in git history.
- Plan acceptance criteria passed.

---
*Phase: 53-demo-runtime-contract*
*Completed: 2026-06-28*
