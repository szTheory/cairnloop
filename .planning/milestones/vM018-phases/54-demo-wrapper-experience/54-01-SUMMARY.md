---
phase: 54-demo-wrapper-experience
plan: 01
subsystem: testing
tags: [exunit, bash, docker-compose, demo-wrapper, source-contract]
requires:
  - phase: 53-demo-runtime-contract
    provides: Docker demo runtime, health route, wrapper, Compose contract, and passing smoke baseline
provides:
  - DB-free wrapper source contract test for Phase 54 requirements
  - RED proof for missing wrapper hardening hooks consumed by Plan 54-02
affects: [demo-wrapper, docker-demo, phase-54]
tech-stack:
  added: []
  patterns:
    - DB-free ExUnit source contract over bin/demo and compose.demo.yml
    - Intentional RED TDD plan summary where failing output is the acceptance evidence
key-files:
  created:
    - test/cairnloop/demo_wrapper_contract_test.exs
  modified: []
key-decisions:
  - "Kept Wave 0 as source-only ExUnit coverage so ordinary unit runs do not require Docker, Postgres, Phoenix boot, Repo, or browser tooling."
patterns-established:
  - "Wrapper contract tests read source with File.read!/1 and use bash -n plus help output only for executable proof."
requirements-completed:
  - BOOT-01
  - BOOT-02
  - BOOT-03
  - BOOT-04
  - VER-01
  - VER-02
duration: 5 min
completed: 2026-06-28
status: complete
---

# Phase 54 Plan 01: Wrapper Contract Test Summary

**DB-free ExUnit source contract for the Docker demo wrapper, intentionally red on the Phase 54 hardening gaps**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-28T17:25:00Z
- **Completed:** 2026-06-28T17:30:02Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `Cairnloop.DemoWrapperContractTest`, a source-only ExUnit module that reads `bin/demo` and `examples/cairnloop_example/compose.demo.yml`.
- Covered shell syntax, command aliases/help, URL route labels, Compose URL discovery, private DB/no host DB ports, dynamic loopback web publishing, isolated smoke cleanup, locked smoke routes, and diagnostic helper expectations.
- Proved the test goes RED on the planned wrapper hardening gap: missing `wait_for_web_endpoint`/diagnostic helper coverage in `bin/demo`.

## Task Commits

1. **Task 1: Create the red Phase 54 wrapper contract test** - `18990d9` (test)
2. **Task 2: Confirm the red coverage is scoped to Phase 54 contracts** - no source changes after verification; covered by `18990d9`

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `test/cairnloop/demo_wrapper_contract_test.exs` - DB-free source contract for `bin/demo` and `compose.demo.yml`.

## Decisions Made

- Kept the Wave 0 gate intentionally RED because Plan 54-01 is the TDD contract plan; `mix ci.fast` is deferred until Plan 54-02 turns the focused test green.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope creep; this is the planned RED coverage for Wave 1.

## Issues Encountered

None. The red output is expected and scoped to Phase 54 wrapper hardening strings, not Docker, Postgres, Phoenix, Repo, or browser availability.

## Verification

- `mix test test/cairnloop/demo_wrapper_contract_test.exs` exited nonzero as expected and `/tmp/phase54-red.log` contained `Expected source to include "wait_for_web_endpoint"`.
- `bash -n bin/demo && mix test test/cairnloop/demo_wrapper_contract_test.exs` exited nonzero as expected and `/tmp/phase54-red-confirm.log` contained the same Phase 54 hardening gap.
- Source scan confirmed the test only runs `System.cmd("bash", ["-n", "bin/demo"])` and `System.cmd("bash", ["bin/demo", "help"])`.

## Self-Check: PASSED

- Key file exists: `test/cairnloop/demo_wrapper_contract_test.exs`.
- `git log --oneline --grep="54-01"` returns `18990d9`.
- Summary documents the intentional RED gate and the downstream green target for Plan 54-02.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 54-02 can harden `bin/demo` against a precise source contract and should make `mix test test/cairnloop/demo_wrapper_contract_test.exs` pass.

---
*Phase: 54-demo-wrapper-experience*
*Completed: 2026-06-28*
