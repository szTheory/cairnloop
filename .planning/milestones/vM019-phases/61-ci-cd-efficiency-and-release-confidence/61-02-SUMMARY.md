---
phase: 61-ci-cd-efficiency-and-release-confidence
plan: "02"
subsystem: infra
tags: [github-actions, ci, e2e, source-contracts, timing-evidence]
requires:
  - phase: 61-01
    provides: "DB-free CI workflow source contract"
provides:
  - "CI workflow action/runtime refresh to checkout v7, cache v6, and upload-artifact v7"
  - "PR E2E path gate with always-on aggregate release gate semantics"
  - "Bounded CI timing, cache, compile, slow-test, E2E, and Playwright artifact evidence"
affects: [ci, e2e, release-gate, phase-61]
tech-stack:
  added: []
  patterns:
    - "CI workflow source contracts assert topology and security posture as source"
key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
    - "test/cairnloop/ci_workflow_contract_test.exs"
key-decisions:
  - "Upgraded first-party CI actions to current maintained majors verified from official release pages: checkout v7, cache v6, upload-artifact v7; setup-node remains v6."
  - "Kept one stable aggregate `release_gate`; optional PR E2E skips pass only when the source path gate says E2E is not required."
  - "Kept build caches for now and added timing/cache evidence before making any cache-removal decision."
patterns-established:
  - "Optional CI jobs must be interpreted by an always-on aggregate gate rather than becoming branch-protection checks directly."
requirements-completed: [CI-02, CI-03, CI-04, CI-05]
duration: 8 min
completed: 2026-07-01
status: complete
---

# Phase 61 Plan 02: CI Workflow Refresh Summary

**CI now uses current action/runtime posture, path-gated PR E2E, and bounded maintainer evidence without weakening the aggregate gate.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-01T01:18:00Z
- **Completed:** 2026-07-01T01:26:21Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Updated CI first-party action majors to `actions/checkout@v7`, `actions/cache@v6`, and `actions/upload-artifact@v7`; retained `actions/setup-node@v6`, `erlef/setup-beam@v1`, read-only permissions, `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`, and checkout credential opt-out.
- Added a `changes` job that fetches the exact PR base SHA, diffs `BASE_SHA...HEAD`, emits `e2e_required`, and path-gates PR E2E while running E2E for non-PR trusted/manual contexts.
- Updated `release_gate` to run with `if: ${{ always() }}` and accept only successful E2E or an intentional path-gated skip; E2E failure, cancellation, or skipped-when-required still fails closed.
- Added CI step-summary evidence for compile profile timing, lane durations, cache hits, slowest headless tests, split E2E phase timings, and failure-only Playwright trace/screenshot artifacts with three-day retention.

## Task Commits

Each task was committed atomically:

1. **Task 1: Refresh main CI action/runtime posture** - `f78fbd4` (`ci(61-02)`)
2. **Task 2: Add E2E path gate and aggregate semantics** - `40c30d2` (`ci(61-02)`)
3. **Task 3: Add bounded CI evidence and useful Playwright artifacts** - `beb7bd1` (`ci(61-02)`)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `.github/workflows/ci.yml` - Action major refresh, `changes` job, path-gated E2E, aggregate gate handling, timing summaries, split E2E commands, and Playwright artifact posture.
- `test/cairnloop/ci_workflow_contract_test.exs` - Updated and expanded source-contract assertions for action majors, PR diffing, path list, optional E2E semantics, timing labels, cache evidence, and artifact retention.

## Decisions Made

- Chose the latest current maintained major for CI actions where official release pages showed no incompatibility: checkout v7, cache v6, upload-artifact v7. Kept setup-node at v6 because v6 is current for this workflow.
- Did not remove `_build` caches in this plan. The workflow now records timing/cache data so future removal decisions can be evidence-backed.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- After converting single-line `run:` commands into timed shell blocks, one source-contract assertion still expected `run: mix ci.fast`. The assertion was corrected to check the command itself before the Task 3 commit.

## Verification

- `mix test test/cairnloop/ci_workflow_contract_test.exs --warnings-as-errors` - passed, 7 tests, 0 failures.
- `mix ci.fast` - passed, 1210 tests, 0 failures, 81 excluded. Hex reported an expired local auth session while continuing with public dependency access; this did not block the gate.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Demo smoke and release workflow plans can now update their own workflow posture and contracts independently. Phase-level docs should record that CI E2E skips are source-path gated and interpreted through `release_gate`.

---
*Phase: 61-ci-cd-efficiency-and-release-confidence*
*Completed: 2026-07-01*
