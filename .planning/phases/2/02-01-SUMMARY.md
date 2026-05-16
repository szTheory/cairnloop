---
phase: 02
plan: 01
subsystem: infra
tags: [elixir, behaviour, chimeway, oban]

requires:
  - phase: 01
    provides: [core worker infrastructure]
provides:
  - Cairnloop.Notifier behaviour for formalizing SLA breach and conversation resolution notifications.
  - Cairnloop.Notifier.Chimeway adapter for asynchronous external dispatch using chimeway.
  - Integration of Notifier into Cairnloop.Workers.CheckSLA.
affects: [SLA breach background workers, External notifications]

tech-stack:
  added: [chimeway]
  patterns: [Adapter pattern via Behaviours, dynamic Application.get_env dispatch, try/rescue for resilient fire-and-forget notification]

key-files:
  created:
    - lib/cairnloop/chimeway/sla_breach_notifier.ex
    - lib/cairnloop/notifier/chimeway.ex
    - test/cairnloop/notifier/chimeway_test.exs
  modified:
    - lib/cairnloop/notifier.ex
    - mix.exs
    - lib/cairnloop/workers/check_sla.ex
    - test/cairnloop/notifier_test.exs
    - test/cairnloop/workers/check_sla_test.exs

key-decisions:
  - "Used an optional Chimeway adapter implementation to avoid coupling core Cairnloop library directly to external notification frameworks."
  - "Implemented robust try/rescue in the Oban CheckSLA worker to invoke Notifier dynamically without crashing the underlying SLA updates, emitting a telemetry event on failure."

patterns-established:
  - "Dynamic Notifier Routing: Relying on `Application.get_env(:cairnloop, :notifier)` dynamically per notification to keep coupling loose."

requirements-completed: [M006-REQ-03, M006-REQ-04, M006-REQ-05]

duration: 15m
completed: 2026-05-16
---

# Phase 2 Plan 01: The Notifier Behaviour & Chimeway Summary

**Implemented configurable Notifier behaviour, added Chimeway adapter, and integrated resilient dynamic dispatch in CheckSLA worker.**

## Performance

- **Duration:** 15m
- **Completed:** 2026-05-16
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- **Notifier Behaviour**: Defined `Cairnloop.Notifier` to formalize the contract for SLA breach and conversation resolution notifications.
- **Chimeway Adapter**: Implemented `Cairnloop.Notifier.Chimeway` and `Cairnloop.Chimeway.SLABreachNotifier`. The adapter uses an optional dependency on `chimeway` (`~> 1.0`).
- **Resilient Worker Integration**: Updated `Cairnloop.Workers.CheckSLA` to dynamically invoke the configured Notifier via `Application.get_env`. The invocation is wrapped in a `try/rescue` block to ensure a "fire-and-forget" failure mode.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define Notifier Behaviour** - `02e9ee7`
2. **Task 2: Add Chimeway Adapter** - `69c4b2e` and `31fd305`
3. **Task 3: Integrate with CheckSLA Worker** - `ff9c513`

## Files Created/Modified
- `lib/cairnloop/notifier.ex` - Defines the Notifier Behaviour callbacks.
- `lib/cairnloop/chimeway/sla_breach_notifier.ex` - Chimeway struct mapping.
- `lib/cairnloop/notifier/chimeway.ex` - Adapter implementation mapping behaviour calls to Chimeway triggers.
- `lib/cairnloop/workers/check_sla.ex` - Added try/rescue dynamic trigger of configured Notifier.

## Decisions Made
- Used an optional Chimeway adapter implementation to avoid coupling core Cairnloop library directly to external notification frameworks.
- Implemented robust try/rescue in the Oban CheckSLA worker to invoke Notifier dynamically without crashing the underlying SLA updates, emitting a telemetry event on failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Uncommitted worker integration and lock file changes**
- **Found during:** Final verification
- **Issue:** Changes for integrating `CheckSLA` worker with `Notifier` and test additions for `chimeway_test` were modified in working directory but uncommitted.
- **Fix:** Added missing commits manually to fulfill Task 2 and 3 completions.
- **Files modified:** `lib/cairnloop/workers/check_sla.ex`, `mix.lock`, `test/cairnloop/notifier/chimeway_test.exs`, `test/cairnloop/workers/check_sla_test.exs`
- **Verification:** `mix test` passes without modifying SLA state worker behavior.
- **Committed in:** `ff9c513`, `31fd305`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential to complete the execution and test passing correctly.

## Issues Encountered
None.

## Next Phase Readiness
- SLA Breaches are now successfully dispatched to an adapter mechanism without blocking internal Oban operations. Ready to use in host applications!

## Self-Check: PASSED
