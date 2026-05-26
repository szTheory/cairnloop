---
phase: 10-citation-backed-draft-suggestions
plan: 03
subsystem: ui
tags: [phoenix-liveview, knowledge-base, knowledge-automation, citations, testing]
requires:
  - phase: 10-citation-backed-draft-suggestions
    provides: citation-backed suggestion persistence, generation, and stale-revision gating
provides:
  - shared suggestion review surface for gap-driven and stale-revision proposals
  - suggestion-first trust and grounding presentation inside the KB maintenance lane
  - phase-10-safe review actions with explicit manual-edit handoff
affects: [phase-10-plan-04, phase-11-review-gated-kb-updates, phase-12-in-thread-quick-fix-ops-closure]
tech-stack:
  added: []
  patterns: [shared suggestion review lane, suggestion-first presenter copy, explicit manual-edit handoff]
key-files:
  created:
    - .planning/phases/10-citation-backed-draft-suggestions/10-03-SUMMARY.md
  modified:
    - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
    - lib/cairnloop/web/article_suggestion_presenter.ex
    - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
key-decisions:
  - "Kept the existing shared review-task route in HEAD, but shifted the rendered surface back to suggestion truth so Phase 10 remains inspect-first instead of publish-first."
  - "Bound the review actions to regenerate, dismiss, and open-for-manual-edit even though later-phase review-task actions already existed in the main worktree."
patterns-established:
  - "Suggestion review surfaces show provenance, grounding, stale pressure, and proposal content ahead of any later workflow state."
  - "Manual editing stays an explicit redirect from suggestion review, with review context preserved in the editor return path."
requirements-completed: [DRAFT-01, DRAFT-02, DRAFT-03]
duration: 6min
completed: 2026-05-23
---

# Phase 10 Plan 03: Citation-Backed Draft Suggestions Summary

**One shared suggestion-review lane now fronts gap-driven article drafts and stale-revision proposals with evidence-first copy, derived revision diffs, and only Phase 10-safe actions**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-23T09:27:00Z
- **Completed:** 2026-05-23T09:32:34Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Reframed the dedicated `/knowledge-base/suggestions` surface around suggestion status, grounding status, stale pressure, evidence, citation anchors, and proposed content instead of later publish workflow state.
- Preserved the shared gap and article entrypoints into the same review lane while keeping revision diffs derived from `base_revision_id` content plus `proposed_markdown`.
- Replaced review-task approval and publish controls on this surface with only `regenerate`, `dismiss`, and `open for manual edit`, preserving the explicit handoff into the existing editor.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Phase 10 entrypoints and the dedicated suggestion review surface** - `b9e5802` (test), `0d78589` (feat)
2. **Task 2: Limit review actions to inspect, regenerate, dismiss, and explicit manual-edit affordances** - `e490766` (test), `ea9d89b` (feat)

## Files Created/Modified
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` - Suggestion-first review rendering plus suggestion-scoped regenerate, dismiss, and manual-edit actions.
- `lib/cairnloop/web/article_suggestion_presenter.ex` - Grounding and queue-summary presentation for ready versus blocked suggestions.
- `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` - Focused LiveView coverage for the shared review surface, evidence rendering, and Phase 10 action boundary.

## Decisions Made
- Preserved the current shared review-task lane in the main worktree rather than rewiring navigation again, but made the rendered experience comply with the narrower Phase 10 review contract.
- Treated inspect as the page itself rather than adding a redundant inspect button, so failed suggestions stay limited to inspection and regeneration.

## Deviations from Plan

None - plan intent was satisfied on the current repository state without extra scope or auto-fix deviations.

## Issues Encountered

- Focused ExUnit runs still emit repeated `missing the :database key in options for Chimeway.Repo` connection errors during app boot, but both required review-surface suites exit `0` and verify the plan hermetically.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The Phase 10 suggestion lane is now safe to build on for authoring-target creation and richer review-task follow-through without reintroducing publish-first controls here.
- The shared main worktree still contains unrelated user and later-phase changes, all left untouched.

## Self-Check: PASSED

- Found `.planning/phases/10-citation-backed-draft-suggestions/10-03-SUMMARY.md`
- Found commit `b9e5802`
- Found commit `0d78589`
- Found commit `e490766`
- Found commit `ea9d89b`

---
*Phase: 10-citation-backed-draft-suggestions*
*Completed: 2026-05-23*
