---
phase: 61-ci-cd-efficiency-and-release-confidence
plan: "04"
subsystem: release
tags: [github-actions, release-please, hex, release-confidence, source-contracts]
requires:
  - phase: 61-01
    provides: "DB-free release workflow source contract"
provides:
  - "Release workflow action refresh to checkout v7 and cache v6"
  - "Exact release SHA quality preflight before Hex publish"
  - "Bounded release publish summary and timing evidence"
affects: [release, hex-publish, ci, phase-61]
tech-stack:
  added: []
  patterns:
    - "Release publish workflow proves exact SHA quality before irreversible publish"
key-files:
  created: []
  modified:
    - ".github/workflows/release-please.yml"
    - "test/cairnloop/release_workflow_contract_test.exs"
key-decisions:
  - "Kept `googleapis/release-please-action@v5` and upgraded only first-party checkout/cache actions."
  - "Used existing `mix ci.quality` as the release preflight instead of adding a compact alias, preserving docs/package/audit guarantees."
patterns-established:
  - "Release workflows summarize bounded metadata and timings without printing publish secrets."
requirements-completed: [CI-02, CI-03, CI-04, CI-06]
duration: 6 min
completed: 2026-07-01
status: complete
---

# Phase 61 Plan 04: Release Workflow Preflight Summary

**Hex publish now runs source-visible `mix ci.quality` on the exact release SHA before dry run and irreversible publish.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-01T01:25:30Z
- **Completed:** 2026-07-01T01:31:37Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Updated release workflow first-party actions to `actions/checkout@v7` and `actions/cache@v6` while preserving `googleapis/release-please-action@v5`, `erlef/setup-beam@v1`, read-only defaults, job-scoped release-please write permissions, exact SHA checkout, and credential opt-out.
- Added `Release quality preflight` in `publish-hex` after dependency install and before dry run/publish, running `mix ci.quality` against `needs.release-please.outputs.sha`.
- Added bounded release summary evidence for version, tag, release SHA, Elixir/OTP, cache hits, quality preflight duration, dry run duration, package inspection duration, publish duration, Hex info duration, and HexDocs verification duration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Refresh release action/runtime posture** - `211ffa2` (`ci(61-04)`)
2. **Task 2: Add exact-SHA release quality preflight before publish** - `2163fb8` (`ci(61-04)`)
3. **Task 3: Add bounded release workflow summary evidence** - `306611f` (`ci(61-04)`)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `.github/workflows/release-please.yml` - Updated action majors, added release quality preflight, and added bounded release publish summary/timing evidence.
- `test/cairnloop/release_workflow_contract_test.exs` - Updated action, preflight, ordering, summary, and secret-boundary assertions.

## Decisions Made

- Reused `mix ci.quality` rather than creating a new release-specific alias because the existing alias already covers locked deps, unused deps, warnings-clean compile, Credo strict, Hex build, docs warnings-as-errors, and dependency audit.
- Kept HexDocs CDN propagation as best-effort after successful `mix hex.docs fetch`, but now records timing before exiting.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

None.

## Verification

- `mix test test/cairnloop/release_workflow_contract_test.exs --warnings-as-errors` - passed, 6 tests, 0 failures.
- `mix ci.quality` - passed. Hex reported an expired local auth session while continuing with public dependency access; Credo found no issues, Hex build/docs generation succeeded, and dependency audit reported no unignored vulnerabilities.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Final docs can now describe release safety as source-backed: trusted triggers, scoped permissions, exact SHA checkout, `mix ci.quality`, dry run, package inspection, publish, Hex info, and HexDocs fetch.

---
*Phase: 61-ci-cd-efficiency-and-release-confidence*
*Completed: 2026-07-01*
