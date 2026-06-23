---
phase: 37-component-primitives
plan: "05"
subsystem: ui
tags: [phoenix, liveview, accessibility, aria, heex, css]

# Dependency graph
requires:
  - phase: 37-01
    provides: .cl-table-scroll CSS utility in cairnloop.css (overflow-x: auto, focus-ring)

provides:
  - Four .cl-table instances in operator screens each wrapped in an accessible div.cl-table-scroll region
  - aria-label="Audit log" on audit_log_live.ex
  - aria-label="Knowledge base articles" on knowledge_base_live/index.ex
  - aria-label="Suggested KB edits" on knowledge_base_live/suggestion_review.ex
  - aria-label="Policies" on settings_live.ex (cl-mb-7 preserved on table)

affects: [38-shell-migration, 43-responsive]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "cl-table-scroll wrapper: additive div with role=region + tabindex=0 + descriptive aria-label around every .cl-table"
    - ":if guard stays on <table> not on wrapper — empty-state path unchanged"
    - "cl-mb-7 margin utility preserved on the <table> element, not moved to wrapper"

key-files:
  created: []
  modified:
    - lib/cairnloop/web/audit_log_live.ex
    - lib/cairnloop/web/knowledge_base_live/index.ex
    - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
    - lib/cairnloop/web/settings_live.ex

key-decisions:
  - "Wrapper div placed outside :if guard — the :if stays on <table> so the empty-state path is unaffected"
  - "cl-mb-7 margin utility on the policies table left on <table>, not moved to wrapper (plan spec preserved)"

patterns-established:
  - "Accessible table scroll: <div class=cl-table-scroll role=region tabindex=0 aria-label={descriptive}><table ...>"
  - "aria-labels are call-site-specific and describe the data domain, never generic"

requirements-completed: [UIC-05]

# Metrics
duration: 15min
completed: 2026-06-03
---

# Phase 37 Plan 05: Table Scroll Wrapper Summary

**Four existing `.cl-table` operator screens wrapped in accessible `div.cl-table-scroll` scroll regions with descriptive ARIA labels — latent overflow fix, no redesign**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-03T19:10:00Z
- **Completed:** 2026-06-03T19:25:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- All four `.cl-table` instances in the operator surface are now wrapped in `<div class="cl-table-scroll" role="region" tabindex="0" aria-label="...">` with descriptive, call-site-specific labels (WCAG 2.2 accessible name requirement met)
- Settings policies table `cl-mb-7` preserved on the `<table>` element as specified; `:if` guards on all four tables unchanged
- Build warnings-clean (`mix compile --warnings-as-errors` exits 0); no regressions introduced (pre-existing test failures confirmed pre-existing before edits)

## Task Commits

1. **Task 1: Wrap audit log + KB index + KB suggestion-review tables** - `77eb7f0` (feat)
2. **Task 2: Wrap settings policies table + verify all four** - `2b2cbda` (feat)

## Files Created/Modified

- `lib/cairnloop/web/audit_log_live.ex` - Added `<div class="cl-table-scroll" role="region" tabindex="0" aria-label="Audit log">` wrapper around the audit events table
- `lib/cairnloop/web/knowledge_base_live/index.ex` - Added wrapper with `aria-label="Knowledge base articles"` around the articles table
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` - Added wrapper with `aria-label="Suggested KB edits"` around the review queue table
- `lib/cairnloop/web/settings_live.ex` - Added wrapper with `aria-label="Policies"` around the SLA policies table; `cl-mb-7` preserved on `<table>`

## Decisions Made

- Wrapper `<div>` placed as the outer container; the `:if` guard stays on `<table>` (not moved to the wrapper) so the empty-state rendering path is completely unaffected — consistent with plan spec.
- `cl-mb-7` margin utility remains on the `<table>` element in settings_live.ex as explicitly required by the plan — moving it to the wrapper would alter layout intent.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Worktree did not have its own `deps`/`_build` directories. Resolved by symlinking to the main repo's `deps` and `_build` directories so `mix compile --warnings-as-errors` could run correctly in the worktree context. This is a standard worktree setup artifact, not a code issue.
- Full `mix test` showed 2 pre-existing failures (`OutboundWorkerTest` unique-key assertion and `SettingsLiveTest` test-ordering isolation issue). Confirmed both failures existed on the Task 1 commit (before any Task 2 edits) via `git stash` + retest. Zero regressions from this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All four `.cl-table` call sites are now accessible scroll regions — Phase 43 (responsive/D3) inherits accessible tables without further wrapper work.
- Phase 38 shell migration can proceed; the wrappers are additive and do not conflict with `cl_page` shell adoption.

---
*Phase: 37-component-primitives*
*Completed: 2026-06-03*
