---
phase: M010-S03
plan: "01"
subsystem: database
tags: [ecto, phoenix, review-tasks, audit-history, knowledge-automation]
requires:
  - phase: M010-S02
    provides: ArticleSuggestion proposal artifacts and suggestion review foundation
provides:
  - Durable review task schema with separated workflow state
  - Append-only review task event history
  - Scoped review task list, detail, and create-or-get APIs
affects: [M010-S03-02, M010-S03-03, review-inbox, publish-follow-through]
tech-stack:
  added: []
  patterns: [separate proposal-vs-workflow persistence, append-only relational audit history, scoped create-or-get context seams]
key-files:
  created:
    - lib/cairnloop/knowledge_automation/review_task.ex
    - lib/cairnloop/knowledge_automation/review_task_event.ex
    - priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs
    - .planning/milestones/M010-phases/M010-S03/M010-S03-01-SUMMARY.md
  modified:
    - lib/cairnloop/knowledge_automation.ex
    - test/cairnloop/knowledge_automation/review_task_test.exs
key-decisions:
  - "Review workflow state stays in ReviewTask rows rather than extending ArticleSuggestion."
  - "One active review task per suggestion is enforced with a partial unique index over active queue states."
  - "Task creation is idempotent and emits a first-class task_created event immediately."
patterns-established:
  - "ReviewTask wraps AI suggestions with tenant-scoped workflow state while leaving proposal evidence untouched."
  - "ReviewTaskEvent stores operator-visible history as append-only rows with structured enums instead of freeform comments."
requirements-completed: [REVIEW-01, REVIEW-03]
duration: 6min
completed: 2026-05-22
---

# Phase 11 Plan 01: Review task storage and query seams Summary

**Durable review-task storage with append-only audit history and scoped create-or-get APIs over ArticleSuggestion**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-22T08:08:47Z
- **Completed:** 2026-05-22T08:14:27Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `ReviewTask` as a separate host-owned workflow record with structured decision, publish, and re-review fields.
- Added `ReviewTaskEvent` and migration indexes so review history is append-only and one active task per suggestion is enforceable.
- Exposed `list_review_tasks/1`, `get_review_task!/2`, and `ensure_review_task_for_suggestion/2` on `Cairnloop.KnowledgeAutomation`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create durable `ReviewTask` and `ReviewTaskEvent` storage with active-task enforcement** - `fb4e295` (test), `10d10d0` (feat)
2. **Task 2: Add scoped review-task query and creation seams in `KnowledgeAutomation`** - `2bfc009` (test), `d6e3f7c` (feat)

## Files Created/Modified

- `lib/cairnloop/knowledge_automation/review_task.ex` - Durable review task schema and validation rules.
- `lib/cairnloop/knowledge_automation/review_task_event.ex` - Append-only relational event schema for review history.
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` - Review task tables, partial unique active-task index, and event chronology indexes.
- `lib/cairnloop/knowledge_automation.ex` - Scoped list/detail/create seams for review tasks.
- `test/cairnloop/knowledge_automation/review_task_test.exs` - Storage and public API contract coverage.

## Decisions Made

- Kept proposal truth, workflow truth, and canonical publish linkage in separate columns and tables to preserve the D-01 through D-04 boundary.
- Treated `:ready` suggestions as `:pending_review` tasks and durable `:failed` suggestions as `:review_needed` tasks to preserve the inbox queue semantics.
- Used immediate `task_created` event insertion in the create-or-get seam so later UI and follow-through work can rely on durable history from the first transition.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated planning state files manually after GSD state handlers failed**
- **Found during:** Summary/state update
- **Issue:** `gsd-sdk query state.advance-plan`, `state.record-metric`, `state.add-decision`, and `roadmap.update-plan-progress "11"` failed against the repo’s current planning format (`Cannot parse Current Plan...`, `summary required`, `Phase 11 not found`).
- **Fix:** Applied minimal manual updates to `.planning/STATE.md`, `.planning/ROADMAP.md`, and `.planning/REQUIREMENTS.md` so the completed plan, requirement status, and next-step context are recorded correctly.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`
- **Verification:** Confirmed the summary exists, Phase 11 roadmap now shows `1/TBD`, and `REVIEW-01` / `REVIEW-03` now read as verified in `REQUIREMENTS.md`.
- **Committed in:** final docs commit

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Documentation/state bookkeeping needed manual handling, but implementation scope and verification stayed unchanged.

## Issues Encountered

- The focused test suite emits workspace-level `Chimeway.Repo` database configuration errors during boot (`missing the :database key`), but the review-task suite itself uses a mocked repo and completed with 10 passing tests.
- The repo’s current milestone planning files are not fully compatible with the expected `gsd-sdk` state handlers, so final state updates were recorded manually.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The review inbox can now query task rows independently of `ArticleSuggestion` and load linked evidence plus history in one read model.
- Later Phase 11 plans can build approval, edit handoff, publish, and reindex follow-through on top of stable task ids and append-only events.

## Self-Check: PASSED

---
*Phase: M010-S03*
*Completed: 2026-05-22*
