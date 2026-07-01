---
phase: 61-ci-cd-efficiency-and-release-confidence
plan: "01"
subsystem: testing
tags: [github-actions, ci, release, source-contracts, exunit]
requires: []
provides:
  - "DB-free source-contract tests for CI workflow posture"
  - "DB-free source-contract tests for release workflow posture"
  - "Fast local workflow-contract gate covering demo, CI, and release workflows"
affects: [ci, release, demo-smoke, phase-61]
tech-stack:
  added: []
  patterns:
    - "Workflow source-contract tests read YAML as source instead of invoking GitHub Actions"
key-files:
  created:
    - "test/cairnloop/ci_workflow_contract_test.exs"
    - "test/cairnloop/release_workflow_contract_test.exs"
  modified: []
key-decisions:
  - "Wave 0 locked the current dirty-worktree workflow baseline first so later plans can tighten expectations deliberately."
  - "Source-contract tests stay DB-free and use direct source scans modeled on the existing demo-smoke workflow contract."
patterns-established:
  - "DB-free workflow contract: ExUnit reads workflow YAML, asserts security and topology invariants, and avoids Repo, Docker, browser, network, and GitHub Actions."
requirements-completed: [CI-02, CI-03, CI-04, CI-05, CI-06]
duration: 20 min
completed: 2026-07-01
status: complete
---

# Phase 61 Plan 01: Workflow Contract Tests Summary

**DB-free ExUnit source contracts now guard CI and release workflow posture before workflow mutations.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-01T01:01:00Z
- **Completed:** 2026-07-01T01:21:42Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Added `Cairnloop.CIWorkflowContractTest` to lock the current CI triggers, read-only permissions, Node 24 opt-in, action majors, checkout credential opt-out, lane topology, release gate inputs, cache summaries, and Playwright artifact baseline.
- Added `Cairnloop.ReleaseWorkflowContractTest` to lock trusted release triggers, scoped release-please write permissions, read-only publish posture, exact release SHA checkout, Hex token preflight, dry run, package inspection, publish, Hex info, and HexDocs fetch.
- Proved the demo, CI, and release source-contract tests run together as a fast DB-free local gate.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Add CI workflow source contract** - `c2912a9` (`test(61-01)`)
2. **Task 2: Add release workflow source contract** - `fa94860` (`test(61-01)`)
3. **Task 3: Prove workflow contracts run as a fast local gate** - verification-only; no source change beyond Tasks 1-2

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `test/cairnloop/ci_workflow_contract_test.exs` - DB-free CI workflow source contract and helper functions.
- `test/cairnloop/release_workflow_contract_test.exs` - DB-free release workflow source contract and helper functions.

## Decisions Made

- Locked the current workflow baseline first, including known Plan 61-02 and Plan 61-04 targets, so subsequent workflow edits update tests intentionally rather than hiding drift.
- Kept helpers local to the test modules instead of introducing shared parsing infrastructure; the source scans are small and phase-scoped.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- One initial CI test helper call used the pipeline in the wrong argument order for `Regex.scan/2`. It was corrected before the Task 1 commit and the focused test passed.

## Verification

- `mix format --check-formatted test/cairnloop/ci_workflow_contract_test.exs && mix test test/cairnloop/ci_workflow_contract_test.exs --warnings-as-errors` - passed, 5 tests, 0 failures.
- `mix format --check-formatted test/cairnloop/release_workflow_contract_test.exs && mix test test/cairnloop/release_workflow_contract_test.exs --warnings-as-errors` - passed, 5 tests, 0 failures.
- `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs --warnings-as-errors` - passed, 13 tests, 0 failures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Wave 1 can now mutate `.github/workflows/ci.yml`, `.github/workflows/demo-smoke.yml`, and `.github/workflows/release-please.yml` with source-contract tests in place.

---
*Phase: 61-ci-cd-efficiency-and-release-confidence*
*Completed: 2026-07-01*
