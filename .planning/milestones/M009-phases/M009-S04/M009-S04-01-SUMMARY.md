---
phase: M009-S04
plan: "01"
subsystem: retrieval
tags: [telemetry, retrieval, diagnostics, ranking, grounding]
requires:
  - phase: M009-S03
    provides: grounded drafting status contract and retrieval-backed evidence flows
provides:
  - bounded Cairnloop-native retrieval telemetry events for search and draft grounding
  - structured retrieval diagnostic taxonomy under the existing coarse grounding states
  - ranking summaries that keep canonical and assistive evidence distinct in telemetry
affects: [retrieval, drafting, telemetry, observability]
tech-stack:
  added: []
  patterns: [bounded telemetry metadata, structured diagnostic taxonomy, ranking outcome summaries]
key-files:
  created: [lib/cairnloop/retrieval/telemetry.ex, test/cairnloop/retrieval/telemetry_test.exs]
  modified:
    [
      lib/cairnloop/retrieval.ex,
      lib/cairnloop/retrieval/result.ex,
      lib/cairnloop/retrieval/ranker.ex,
      lib/cairnloop/telemetry.ex,
      test/cairnloop/retrieval_test.exs
    ]
key-decisions:
  - "Used point-in-time `[:cairnloop, :retrieval, ...]` events with bounded metadata instead of span exception metadata so raw error details never leak into the public contract."
  - "Kept `strong | clarification | escalation` as the coarse grounding status and added explicit `diagnostic_class` plus stable reason atoms beneath it."
  - "Derived ranking outcome summaries from the ranker so telemetry can report result buckets and canonical-versus-assistive mix without inspecting raw evidence."
patterns-established:
  - "Retrieval emits one bounded search event and one bounded draft-grounding event at the public library seam."
  - "Grounding bundles carry `diagnostic` and `ranking_summary` alongside the existing `grounding_assessment`."
requirements-completed: [M009-REQ-08]
duration: 10min
completed: 2026-05-20
---

# Phase M009-S04 Plan 01: Retrieval Telemetry Contract Summary

**Bounded Cairnloop retrieval telemetry for search and draft grounding with structured diagnostic classes and ranking outcome summaries**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-20T20:00:40Z
- **Completed:** 2026-05-20T20:10:40Z
- **Tasks:** 1
- **Files modified:** 8

## Accomplishments
- Added `Cairnloop.Retrieval.Telemetry` as the stable `[:cairnloop, :retrieval, ...]` contract for search and draft-grounding events.
- Extended retrieval grounding bundles with explicit `diagnostic` and `ranking_summary` data while preserving the existing coarse product-state contract.
- Added retrieval and telemetry tests that prove bounded metadata, structured subordinate diagnostics, and error classification before rescue fallback.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the stable retrieval telemetry contract and structured diagnostic taxonomy** - `c0c3569` (feat)

## Files Created/Modified
- `lib/cairnloop/retrieval/telemetry.ex` - bounded retrieval telemetry helpers and exception classification
- `lib/cairnloop/retrieval.ex` - retrieval event emission, diagnostic taxonomy, and grounding bundle enrichment
- `lib/cairnloop/retrieval/ranker.ex` - ranking summaries for result buckets, source mix, and ranking outcomes
- `lib/cairnloop/retrieval/result.ex` - normalized retrieval contract documentation
- `lib/cairnloop/telemetry.ex` - public telemetry docs for retrieval events
- `test/cairnloop/retrieval_test.exs` - contract tests for strong, weak, empty, assistive-only, and retrieval-error outcomes
- `test/cairnloop/retrieval/telemetry_test.exs` - bounded telemetry metadata and error-path coverage

## Verification
- `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs` ✅
- `rg -n 'diagnostic|grounding_status|result_bucket|source_mix|canonical_hit_count|assistive_hit_count' lib/cairnloop test/cairnloop` ✅

## Decisions Made
- Used explicit point events for retrieval instead of `:telemetry.span/3` so the public retrieval contract stays bounded even on exceptions.
- Standardized diagnostic classes as `:grounded`, `:weak_grounding`, `:empty_recall`, `:retrieval_error`, and `:policy_limit`.
- Mapped stable reasons to bounded atoms such as `:canonical_results`, `:assistive_only_results`, `:canonical_insufficient_detail`, `:clarification_limit_reached`, and `:provider_timeout`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Switched rescue-based telemetry paths to explicit `try/rescue` blocks**
- **Found during:** Task 1
- **Issue:** Elixir rescue scoping prevented the timing variable from being visible in telemetry error paths.
- **Fix:** Wrapped `search/2` and `ground_for_draft/2` in explicit `try/rescue` blocks so bounded error events can reuse the same timing state.
- **Files modified:** `lib/cairnloop/retrieval.ex`
- **Verification:** `mix test test/cairnloop/retrieval_test.exs test/cairnloop/retrieval/telemetry_test.exs`
- **Committed in:** `c0c3569`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Required for correct error-path telemetry. No scope creep.

## Issues Encountered
- The targeted tests emit existing repo-level Postgrex configuration warnings for `Chimeway.Repo`, but they do not fail the owned retrieval tests or block this plan.

## Known Stubs
None.

## Threat Flags
None.

## Self-Check: PASSED
- Summary file exists at `.planning/milestones/M009-phases/M009-S04/M009-S04-01-SUMMARY.md`.
- Task commit `c0c3569` exists in git history.

## Next Phase Readiness
- Retrieval now exposes one stable observability seam with bounded labels and source-aware diagnostics.
- The next persistence and surface-integration plans can consume `diagnostic`, `ranking_summary`, and the public retrieval telemetry events without changing the coarse grounding status contract.
