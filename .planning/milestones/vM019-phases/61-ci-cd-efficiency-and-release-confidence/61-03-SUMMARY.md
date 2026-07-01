---
phase: 61-ci-cd-efficiency-and-release-confidence
plan: "03"
subsystem: infra
tags: [github-actions, demo-smoke, docker, source-contracts]
requires:
  - phase: 61-01
    provides: "DB-free demo workflow source-contract pattern"
provides:
  - "Demo smoke checkout action refresh to v7"
  - "Narrowed demo-smoke path filters for adoption-signal changes"
  - "Bounded Docker/runtime/duration summary evidence"
affects: [demo-smoke, docker, ci, phase-61]
tech-stack:
  added: []
  patterns:
    - "Docker smoke workflow remains a thin delegator to ./bin/demo smoke"
key-files:
  created: []
  modified:
    - ".github/workflows/demo-smoke.yml"
    - "test/cairnloop/demo_smoke_workflow_contract_test.exs"
key-decisions:
  - "Removed broad `lib/**` and `priv/**` demo-smoke triggers because normal CI/E2E now cover those changes more directly."
  - "Added `CONTRIBUTING.md` to demo-smoke path filters because contributor adoption guidance can affect Docker/demo usage."
patterns-established:
  - "Demo smoke summaries expose bounded runtime facts without inlining wrapper internals."
requirements-completed: [CI-02, CI-03, CI-04, CI-05]
duration: 4 min
completed: 2026-07-01
status: complete
---

# Phase 61 Plan 03: Demo Smoke Workflow Summary

**Docker demo smoke now runs on adoption-signal paths with current action posture and bounded runtime evidence.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-01T01:24:30Z
- **Completed:** 2026-07-01T01:28:40Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Updated demo smoke checkout usage to `actions/checkout@v7` while preserving read-only permissions, PR-only cancellation, `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`, and `persist-credentials: false`.
- Narrowed demo-smoke path filters to Docker wrapper, example app, docs/adoption guidance, workflow, Mix, and config changes; removed broad `lib/**` and `priv/**` overlap.
- Added bounded `$GITHUB_STEP_SUMMARY` output for Docker version, Docker Compose version, workflow event, ref, and `./bin/demo smoke` duration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Refresh demo smoke action posture** - `8f8b02f` (`ci(61-03)`)
2. **Task 2: Narrow demo smoke path filters to adoption-signal changes** - `c955f45` (`ci(61-03)`)
3. **Task 3: Add bounded demo smoke summary evidence** - `282ccb1` (`ci(61-03)`)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `.github/workflows/demo-smoke.yml` - Updated checkout action major, narrowed path filters, and summary evidence around the existing wrapper command.
- `test/cairnloop/demo_smoke_workflow_contract_test.exs` - Updated action, path-filter, negative, and summary assertions.

## Decisions Made

- Kept Docker smoke outside default `mix ci` and outside `.github/workflows/ci.yml`.
- Kept Docker/route-smoke behavior inside `./bin/demo smoke`; the workflow only records bounded runtime facts.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## Verification

- `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` - passed, 3 tests, 0 failures.
- `mix ci.fast` - passed, 1210 tests, 0 failures, 81 excluded. Hex reported an expired local auth session while continuing with public dependency access; this did not block the gate.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Release workflow work can proceed with CI/demo smoke posture updated. Phase-level docs should record demo smoke as a targeted adoption proof, not a broad duplicate of normal CI.

---
*Phase: 61-ci-cd-efficiency-and-release-confidence*
*Completed: 2026-07-01*
