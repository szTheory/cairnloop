---
phase: 10-citation-backed-draft-suggestions
plan: "05"
subsystem: knowledge_automation
tags: [phoenix, liveview, ecto, retrieval, knowledge-base, testing]
requires:
  - phase: 10-04
    provides: shared suggestion review lane and review-task redirect contract
provides:
  - gap-candidate suggestion grounding loaded from durable candidate evidence inside KnowledgeAutomation
  - stale revision gating loaded from repo-backed gap events and fresh canonical grounding inside the revision path
  - shipped Gaps and Index entrypoints proven against real domain loading instead of shallow mocks
affects: [phase-10-verification, suggestion-review, knowledge-base-index, gap-dashboard]
tech-stack:
  added: []
  patterns: [domain-owned entrypoint hydration, fail-closed suggestion gating, app-configurable test seams]
key-files:
  created: []
  modified:
    - lib/cairnloop/knowledge_automation.ex
    - lib/cairnloop/web/knowledge_base_live/index.ex
    - test/cairnloop/knowledge_automation/article_suggestion_test.exs
    - test/cairnloop/web/knowledge_base_live/gaps_test.exs
key-decisions:
  - "Gap-driven article suggestions now hydrate candidate retrieval and manual-handling evidence inside KnowledgeAutomation before grounding."
  - "Revision suggestions now load article-linked GapEvent rows plus a fresh canonical grounding bundle in-domain before stale gating."
  - "Retrieval, knowledge-base, and enqueue seams can fall back to application config so shipped LiveView paths stay testable without changing the UI contract."
patterns-established:
  - "Thin LiveView entrypoints: pass identity and scope only, load durable evidence inside the domain."
  - "Shared review-lane redirect can start from pending suggestions as long as the durable suggestion row already exists."
requirements-completed: [DRAFT-01, DRAFT-02, DRAFT-03]
duration: 54 min
completed: 2026-05-23
---

# Phase 10 Plan 05: Citation-backed entrypoint grounding Summary

**Gap-dashboard and KB-index suggestion buttons now hydrate their own durable evidence in-domain before queueing or blocking generation.**

## Performance

- **Duration:** 54 min
- **Started:** 2026-05-23T10:43:00Z
- **Completed:** 2026-05-23T11:37:10Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Gap-driven article suggestions now load the selected candidate with `get_gap_candidate!/2`, derive the draft query from durable candidate evidence, and stop using the generic `"Knowledge Base maintenance"` fallback on that path.
- Revision suggestions now load article-linked stale signals from durable `GapEvent` rows and build a fresh canonical grounding bundle before `StaleArticleSignal.build_revision_gate/3`.
- The shipped `Gaps` and `Index` LiveView entrypoints now prove the redirect-to-review flow against real domain loading instead of shallow request mocks.

## Task Commits

1. **Task 1: Replace gap-candidate generic fallback with hydrated candidate evidence** - `280cb51` (`test`)
2. **Task 2: Load repo-backed stale evidence and fresh canonical grounding inside the revision path** - `db0ccf9` (`feat`)

_Note: the RED gate covered both shipped entrypoints first, then the overlapping `KnowledgeAutomation` implementation for Tasks 1 and 2 landed together because both tasks modify the same in-domain request-preparation path._

## Files Created/Modified
- `lib/cairnloop/knowledge_automation.ex` - Hydrates gap candidates, loads stale revision inputs in-domain, and exposes app-configurable retrieval/KB/enqueue seams for the shipped entrypoints.
- `lib/cairnloop/web/knowledge_base_live/index.ex` - Preserves `tenant_scope` and `host_user_id` on the revision button path while keeping the UI contract thin.
- `test/cairnloop/knowledge_automation/article_suggestion_test.exs` - Proves candidate-scoped grounding, fail-closed gap handling, and repo-backed stale revision prep on the domain surface.
- `test/cairnloop/web/knowledge_base_live/gaps_test.exs` - Exercises the real `Gaps` and `Index` entrypoints through the shared review-lane redirect.

## Decisions Made
- Kept evidence loading inside `KnowledgeAutomation` instead of pushing candidate payloads or stale inputs into LiveView events.
- Preserved fail-closed behavior by marking weak or citation-missing bundles failed after hydration rather than widening generation eligibility.
- Allowed pending suggestions to open the shared review lane immediately once the durable row exists, matching the shipped redirect contract.

## Deviations from Plan

### Execution Deviation

**1. Overlapping task implementation landed in one feature commit**
- **Found during:** Task 2 while staging commits from a dirty worktree
- **Issue:** Tasks 1 and 2 both modify the same `KnowledgeAutomation` request-preparation surface, and the file already contained unrelated user changes.
- **Fix:** Kept the TDD RED gate separate, then staged only the plan-owned hunks and shipped one shared implementation commit for the overlapping domain work.
- **Files modified:** `lib/cairnloop/knowledge_automation.ex`, `lib/cairnloop/web/knowledge_base_live/index.ex`, related tests
- **Verification:** `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs`
- **Committed in:** `db0ccf9`

---

**Total deviations:** 1 execution deviation
**Impact on plan:** Behavior matches the plan and verification blockers are closed; the deviation only affects how the overlapping implementation work was committed.

## Issues Encountered
- `lib/cairnloop/knowledge_automation.ex` was already dirty before execution, so staging had to be limited to plan-owned hunks to avoid pulling unrelated work into this plan.
- Focused test runs emit unrelated `Chimeway.Repo` missing-database logs in this workspace, but the targeted ExUnit suite still passes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 10 verification blockers at the real suggestion entrypoints are closed.
- The shared review lane, suggestion review flow, and later publish-gated work can now assume both entrypoints arrive with durable grounding metadata instead of generic fallback input.

## Verification

- `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs`

## Self-Check: PASSED

- Summary file exists at `.planning/phases/10-citation-backed-draft-suggestions/10-05-SUMMARY.md`
- Commits `280cb51` and `db0ccf9` exist in git history

---
*Phase: 10-citation-backed-draft-suggestions*
*Completed: 2026-05-23*
