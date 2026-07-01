---
phase: 54-demo-wrapper-experience
plan: 02
subsystem: infra
tags: [bash, docker-compose, demo-wrapper, readiness, diagnostics]
requires:
  - phase: 54-demo-wrapper-experience
    provides: Plan 54-01 DB-free wrapper contract test
provides:
  - Hardened bin/demo wrapper with delayed endpoint readiness and bounded diagnostics
  - Green Phase 54 wrapper contract test
  - Post-review wrapper fixes for port fallback, host-curl removal, concurrent smoke isolation, and printed URL test precision
affects: [demo-wrapper, docker-demo, phase-54, phase-55, phase-56]
tech-stack:
  added: []
  patterns:
    - Retry Compose port discovery before health checks in start and smoke paths
    - Shared web-log diagnostics for compose-up, health timeout, and smoke route failures
    - Retry occupied localhost ports across configured Compose port ranges
    - Use container-backed curl checks so Docker Compose remains the only local runtime prerequisite
key-files:
  created:
    - bin/demo
  modified:
    - bin/demo
key-decisions:
  - "Committed the hardened wrapper as one source change because bin/demo was untracked at phase start; staging an artificial baseline would have obscured the actual final contract."
  - "Addressed code-review findings before phase close: automatic port fallback, container-backed curl, unique smoke project IDs, and precise printed URL contract assertions."
patterns-established:
  - "Use wait_for_web_endpoint for start/smoke and keep base_url fail-closed for urls."
  - "Use fail_with_web_logs for bounded failure diagnostics without dumping env, inspect JSON, or unrelated logs."
  - "Use compose_up_with_port_fallback for range-valued CAIRNLOOP_WEB_PORT so an occupied first port does not fail the demo."
  - "Use web_get via docker compose exec instead of host curl for readiness and route smoke."
requirements-completed:
  - BOOT-03
  - BOOT-04
  - VER-02
duration: 16 min
completed: 2026-06-28
status: complete
---

# Phase 54 Plan 02: Demo Wrapper Hardening Summary

**Hardened Bash demo wrapper with delayed Compose port discovery, visible status help, and shared recent-web-log diagnostics**

## Performance

- **Duration:** 16 min
- **Started:** 2026-06-28T17:31:00Z
- **Completed:** 2026-06-28T17:49:43Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

- Added `url_from_endpoint` and `wait_for_web_endpoint` so `start` and `smoke` tolerate delayed `docker compose port web 4000` output before polling `/health`.
- Kept `base_url` as the fail-closed path for `./bin/demo urls` when the web service is absent.
- Added `recent_web_logs`, `fail_with_web_logs`, and `run_compose_or_explain` for bounded compose-up, health timeout, and smoke route diagnostics.
- Updated help copy to advertise both `ps` and `status`.
- Turned the Plan 54-01 contract test green and preserved `./bin/demo logs` as `compose logs -f web db`.
- Addressed code-review findings with automatic fallback across occupied port ranges, container-backed curl checks, per-process smoke project names, and stronger printed-URL assertions.

## Task Commits

1. **Task 1: Harden URL discovery, health wait, and help copy** - `f01e707` (fix)
2. **Task 2: Add calm Compose and smoke failure diagnostics** - `f01e707` (fix)
3. **Task 3: Run the fast wrapper and Compose contract gate** - verification only; no additional source changes
4. **Post-review fixes** - `8559a95` (fix)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `bin/demo` - Canonical adopter-facing Docker demo wrapper with hardened readiness, diagnostics, port fallback, container-backed route checks, and unique smoke projects.
- `test/cairnloop/demo_wrapper_contract_test.exs` - Strengthened source contract for printed URL adjacency, port fallback, container-backed curl, and smoke project isolation.

## Decisions Made

- Used a separate retry path for `start`/`smoke` instead of changing `base_url`, preserving `urls` fail-closed behavior.
- Wrapped only important Compose start boundaries with diagnostic helpers; cleanup and status/log commands keep direct Compose semantics.
- Decided to keep host `curl` out of wrapper readiness/smoke checks; the wrapper now executes curl inside the already-required Docker web service.

## Deviations from Plan

None - plan behavior was implemented as specified.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope expansion; changes stayed in `bin/demo`.

## Issues Encountered

- `bin/demo` was untracked when Phase 54 began, so the source commit records it as a new executable file. The file was already present in the working tree and was hardened in place; no unrelated dirty files were staged.
- Code review found four valid issues after the first validation run; all were fixed in `8559a95` and the re-review is clean.

## Verification

- `bash -n bin/demo && ./bin/demo help && mix test test/cairnloop/demo_wrapper_contract_test.exs` passed.
- `bash -n bin/demo && mix test test/cairnloop/demo_wrapper_contract_test.exs && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` passed.
- Full Wave 1 post-merge gate passed: `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`.
- `mix ci.fast` result: 1 doctest, 1066 tests, 0 failures, 57 excluded.
- Post-review focused gate passed: `bash -n bin/demo && ./bin/demo help && mix test test/cairnloop/demo_wrapper_contract_test.exs`.
- Post-review full gate passed without a smoke port override: `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo smoke`.
- Re-review report `.planning/phases/54-demo-wrapper-experience/54-REVIEW.md` is `status: clean`.

## Self-Check: PASSED

- Key file exists: `bin/demo`.
- `git log --oneline --grep="54-02"` returns `f01e707`.
- `test/cairnloop/demo_wrapper_contract_test.exs` passes against the hardened wrapper.
- `git log --oneline --grep="54"` includes the post-review fix commit `8559a95`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 54-03 can run the full final gate, including `./bin/demo smoke`, against the hardened wrapper and validated Compose config.

---
*Phase: 54-demo-wrapper-experience*
*Completed: 2026-06-28*
