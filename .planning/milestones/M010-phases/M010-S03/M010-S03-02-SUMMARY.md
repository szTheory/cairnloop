---
phase: M010-S03
plan: "02"
subsystem: api
tags: [elixir, ecto, knowledge-base, review-workflow, publish-guard]
requires:
  - phase: M010-S03-01
    provides: durable review-task storage, query seams, and append-only task events
provides:
  - explicit approve, reject, defer, and publish review-task commands
  - fail-closed draft collision handling before KB draft staging
  - revision freshness checks on the canonical review-task publish path
affects: [M010-S03-03, M010-S03-04, review-inbox, kb-editor]
tech-stack:
  added: []
  patterns: [task-owned draft staging, bounded decision reasons, explicit publish boundary]
key-files:
  created: []
  modified:
    - lib/cairnloop/knowledge_automation.ex
    - lib/cairnloop/knowledge_automation/review_task.ex
    - lib/cairnloop/knowledge_base.ex
    - test/cairnloop/knowledge_automation/review_task_test.exs
key-decisions:
  - "Approval stays draft-only and records the staged revision on the review task; publish remains a separate command."
  - "Revision publish freshness reuses the suggestion's stored base revision anchor and returns stale tasks to review_needed before canonical state changes."
patterns-established:
  - "Review decisions use bounded reason enums through ReviewTask.decision_changeset/7 plus append-only ReviewTaskEvent records."
  - "Review-task publish flows load the staged revision and delegate canonical promotion to KnowledgeBase.publish_revision/1 only."
requirements-completed: [REVIEW-02, REVIEW-03, OPS-02]
duration: 10 min
completed: 2026-05-22
---

# Phase 11 Plan 02: Review command semantics Summary

**Review-task command seams now stage guarded KB drafts, record structured decisions, and publish only through the canonical revision promotion path.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-22T08:16:00Z
- **Completed:** 2026-05-22T08:26:34Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added `approve_review_task/2`, `reject_review_task/2`, `defer_review_task/2`, and `publish_review_task/2` to `Cairnloop.KnowledgeAutomation`.
- Guarded approval against unrelated active drafts and recorded structured decision metadata plus append-only task history.
- Enforced explicit publish-only transitions with stale-base detection before `KnowledgeBase.publish_revision/1` can mutate canonical KB state.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement approve, reject, and defer semantics with structured audit history** - `2abf8b9` (test), `793ec0f` (feat)
2. **Task 2: Implement separate publish with base-revision freshness guards** - `771e85e` (test), `01a9bf8` (feat)

## Files Created/Modified
- `lib/cairnloop/knowledge_automation.ex` - review-task command APIs, collision guards, publish freshness checks, and event-writing helpers
- `lib/cairnloop/knowledge_automation/review_task.ex` - bounded decision reason validation and reusable decision changeset helper
- `lib/cairnloop/knowledge_base.ex` - read helpers for staged article and revision lookup used by review-task command paths
- `test/cairnloop/knowledge_automation/review_task_test.exs` - focused command tests for approve, reject, defer, publish, collision, and stale-base behavior

## Decisions Made

- Approval records `staged_article_id` and `staged_revision_id` on the review task and never publishes as a side effect.
- Draft collisions move tasks back to `review_needed` with a bounded `draft_conflict` reason instead of mutating unrelated drafts.
- Revision suggestions reuse the stored `base_revision_id` anchor for freshness checks before publish.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed review command control flow and collision reason semantics**
- **Found during:** Task 1 and Task 2 verification
- **Issue:** The first implementation scoped `task` incorrectly inside `with ... else` branches, and the collision path recorded a generic reason instead of the required `draft_conflict`-style reason.
- **Fix:** Reworked the command flow to keep task context available in failure branches and changed the fail-closed approval collision path to persist `:draft_conflict`.
- **Files modified:** `lib/cairnloop/knowledge_automation.ex`, `test/cairnloop/knowledge_automation/review_task_test.exs`
- **Verification:** `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base_test.exs`
- **Committed in:** `01a9bf8` (part of task commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The auto-fix was required to satisfy the plan's fail-closed approval semantics and keep the publish path verifiable. No scope creep.

## Issues Encountered

- The focused test run emits background `Chimeway.Repo` connection errors in this workspace because no test database is configured for that repo alias, but the targeted mock-driven suite still completes and passes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Review-task command semantics are in place for the next Phase 11 UI/editor handoff work.
- The shared review inbox can now drive explicit approve, reject, defer, and publish actions without bypassing the KB publish boundary.

## Self-Check: PASSED

- Verified summary file exists at `.planning/milestones/M010-phases/M010-S03/M010-S03-02-SUMMARY.md`.
- Verified task commits `2abf8b9`, `793ec0f`, `771e85e`, and `01a9bf8` exist in git history.

---
*Phase: M010-S03*
*Completed: 2026-05-22*
