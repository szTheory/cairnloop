---
phase: 58-identity-ingress-and-side-effect-trust
plan: "05"
subsystem: ops
tags: [scrypath, side-effects, oban, req, fail-closed, telemetry]

requires:
  - phase: 57-evidence-and-trust-audit
    provides: Evidence-backed Scrypath side-effect trust gap and vM019 safe-default priorities
provides:
  - Central Scrypath side-effect status helper with disabled, ready, and misconfigured states
  - Ready-only conversation-resolved Scrypath bridge that enqueues conversation_id only
  - Worker-side Scrypath config validation before external HTTP
  - Focused tests for disabled, misconfigured, and ready side-effect behavior
affects: [phase-58, ops, side-effects, doctor-readiness]

tech-stack:
  added: []
  patterns:
    - Fail-closed optional side effects using a centralized status helper
    - Durable-data worker payload construction instead of raw telemetry body forwarding
    - DB-free worker tests with injected MockRepo and Req.Test

key-files:
  created:
    - lib/cairnloop/scrypath_config.ex
    - .planning/phases/58-identity-ingress-and-side-effect-trust/58-05-SUMMARY.md
  modified:
    - lib/cairnloop/application.ex
    - lib/cairnloop/workers/ingest_scrypath.ex
    - test/cairnloop/application_test.exs
    - test/cairnloop/workers/ingest_scrypath_test.exs

key-decisions:
  - "Scrypath automation remains disabled unless :scrypath_automation_enabled is true and both API URL and API key are non-placeholder values."
  - "The resolved-conversation bridge enqueues only conversation_id; support content is fetched later inside the ready worker path."
  - "Disabled and misconfigured Scrypath worker jobs discard deterministically before building Req clients or issuing HTTP."

patterns-established:
  - "Use Cairnloop.ScrypathConfig.status/1 as the single Scrypath side-effect readiness gate."
  - "Bounded misconfiguration reasons are atoms only and do not include raw URL or secret values."

requirements-completed: [OPS-01, OPS-02]

duration: 7 min
completed: 2026-06-30
status: complete
---

# Phase 58 Plan 05: Optional Scrypath Side-Effect Trust Summary

**Scrypath side effects are now inert by default, fail closed when enabled with unsafe config, and post durable conversation payloads only after ready config validation.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-29T23:54:12Z
- **Completed:** 2026-06-30T00:01:09Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Added `Cairnloop.ScrypathConfig.status/1` and `ready?/1` to centralize disabled, ready, and misconfigured side-effect states.
- Updated `Cairnloop.Application` to attach/enqueue Scrypath work only for ready config and to enqueue `conversation_id` only.
- Updated `Cairnloop.Workers.IngestScrypath` to discard disabled/misconfigured jobs before Req client construction and to build outbound JSON from `Chat.get_conversation!/1`.
- Added focused DB-free tests for config state, bridge enqueue decisions, worker discard paths, and ready HTTP payloads via `Req.Test`.

## Task Commits

1. **Task 1 RED: Scrypath config status tests** - `0cdf35a` (test)
2. **Task 1 GREEN: Scrypath config helper** - `d4f78ca` (feat)
3. **Task 2 RED: bridge readiness tests** - `6850ca1` (test)
4. **Task 2 GREEN: ready-only bridge** - `3c0edc8` (feat)
5. **Task 3 RED: worker guard tests** - `9d198bc` (test)
6. **Task 3 GREEN: worker validation and payload** - `4274b6e` (feat)

## Files Created/Modified

- `lib/cairnloop/scrypath_config.ex` - Central status helper for Scrypath enabled/ready/misconfigured state.
- `lib/cairnloop/application.ex` - Ready-only telemetry attachment and conversation-resolved enqueue guard.
- `lib/cairnloop/workers/ingest_scrypath.ex` - Worker-side Scrypath config validation and durable payload construction.
- `test/cairnloop/application_test.exs` - Bridge disabled, misconfigured, and ready enqueue coverage.
- `test/cairnloop/workers/ingest_scrypath_test.exs` - Config helper and worker HTTP/no-HTTP coverage.

## Decisions Made

- Placeholder Scrypath defaults (`https://api.scrypath.local/v1/index`, `dummy`) are treated as unsafe when automation is enabled.
- Misconfiguration reasons are bounded atoms, so diagnostics can be reason-forward without leaking URL or key values.
- The bridge no longer forwards support text from telemetry metadata; the worker owns durable conversation fetch and outbound payload construction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Formatted Task 3 test file after gate failure**
- **Found during:** Task 3 (Validate Scrypath worker before external HTTP)
- **Issue:** `mix ci.fast` failed its `mix format --check-formatted` gate for `test/cairnloop/workers/ingest_scrypath_test.exs`.
- **Fix:** Ran `mix format` on the 58-05 touched files and reran the focused checks plus `mix ci.fast`.
- **Files modified:** `test/cairnloop/workers/ingest_scrypath_test.exs`
- **Verification:** `mix test test/cairnloop/application_test.exs test/cairnloop/workers/ingest_scrypath_test.exs --warnings-as-errors`, `mix compile --warnings-as-errors`, and `mix ci.fast` passed.
- **Committed in:** `4274b6e`

---

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** No scope change; the formatting fix was required for the existing quality gate.

## Issues Encountered

- `mix ci.fast` initially failed on formatting only; after `mix format`, the full fast gate passed.
- The checkout had pre-existing dirty files. Only 58-05 files were staged for task commits.

## Verification

- `mix test test/cairnloop/workers/ingest_scrypath_test.exs --warnings-as-errors` - passed after Task 1 and Task 3 GREEN.
- `mix test test/cairnloop/application_test.exs --warnings-as-errors` - passed after Task 2 GREEN.
- `mix test test/cairnloop/application_test.exs test/cairnloop/workers/ingest_scrypath_test.exs --warnings-as-errors` - passed, 10 tests, 0 failures.
- `mix compile --warnings-as-errors` - passed.
- `mix ci.fast` - passed, 1110 tests, 0 failures, 62 excluded.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required. Hosts must still explicitly opt into Scrypath automation with a real API URL and API key.

## Next Phase Readiness

OPS-01 and OPS-02 are satisfied for the existing Scrypath side-effect path. Plan 58-07 can surface the new bounded status reasons in doctor/readiness output without adding another Scrypath config model.

## Self-Check: PASSED

- Files verified: `lib/cairnloop/scrypath_config.ex`, `lib/cairnloop/application.ex`, `lib/cairnloop/workers/ingest_scrypath.ex`, `test/cairnloop/application_test.exs`, `test/cairnloop/workers/ingest_scrypath_test.exs`, and this summary.
- Commits verified: `0cdf35a`, `d4f78ca`, `6850ca1`, `3c0edc8`, `9d198bc`, `4274b6e`.

---
*Phase: 58-identity-ingress-and-side-effect-trust*
*Completed: 2026-06-30*
