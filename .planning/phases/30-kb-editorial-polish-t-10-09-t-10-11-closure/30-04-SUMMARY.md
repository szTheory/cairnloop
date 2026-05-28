---
phase: 30-kb-editorial-polish-t-10-09-t-10-11-closure
plan: "04"
subsystem: kb-editorial-security
tags: [elixir, phoenix, liveview, editor_handoff, sec-01, kb-01, knowledge_automation]

# Dependency graph
requires:
  - phase: 30-01
    provides: EditorHandoff.sign/5 with opts, record_editor_handoff/2, Token.decode/1
  - phase: 30-02
    provides: NavComponent.kb_nav/1 function component

provides:
  - "SuggestionReview.open_for_manual_edit: record_editor_handoff/2 DB write before sign + marker-bearing EditorHandoff.sign/5"
  - "ConversationLive.open_manual_draft: record_editor_handoff/2 DB write before sign + marker-bearing EditorHandoff.sign/5 (gate regression fix)"
  - "Gaps.render: shared <.kb_nav current={:gaps} /> nav shell"
  - "SuggestionReview.render: shared <.kb_nav current={:suggestions} /> nav shell"
  - "suggestion_review_test.exs: record_editor_handoff-called assertion + marker-bearing token decode assertion (12 tests green)"
  - "conversation_live_test.exs: record_editor_handoff/2 mock clause for open_manual_draft path (69 tests green)"

affects:
  - "Phase 31 golden path: conversation->editor path now goes through the SEC-01 gate (record + marker); future quick-fix work must include both the DB write and the marker opt"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SEC-01 double-layer gate minting: record_editor_handoff/2 before EditorHandoff.sign/5 with manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()"
    - "Fail-closed handoff write: wrap record_editor_handoff in case, route {:error, _} to existing error flash rather than crash"
    - "Token decode in test: pin secret_key_base via Application.put_env(:cairnloop, EditorHandoff, ...) in setup; decode with Token.decode/1 to assert non-empty manual_edit_opened_at"

key-files:
  created: []
  modified:
    - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
    - lib/cairnloop/web/knowledge_base_live/gaps.ex
    - lib/cairnloop/web/conversation_live.ex
    - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
    - test/cairnloop/web/conversation_live_test.exs

key-decisions:
  - "ConversationLive record_editor_handoff wrapped in case (not bare {:ok, _} =) so a write failure falls through to the existing 'Manual draft could not be opened right now.' flash, matching the calm fail-closed posture"
  - "Existing action_label copy assertions in suggestion_review_test.exs updated to match Plan 02 KB-04 variants ('Create manual draft', 'Open for manual edit', 'Review and draft manually') — not new tests, just updated assertions"
  - "cross-file SEC-01 note recorded: conversation->editor path now requires both record_editor_handoff + marker; Phase 31 quick-fix wiring must include both"

# Metrics
duration: "~5 minutes"
completed: "2026-05-28T17:34:25Z"
tasks_completed: 3
files_changed: 5
---

# Phase 30 Plan 04: SEC-01 Token Minting + KB-01 Nav Shell Completion Summary

Wire both legitimate editor entry points (SuggestionReview.open_for_manual_edit and ConversationLive.open_manual_draft) through the SEC-01 double-layer gate: record_editor_handoff/2 DB write + marker-bearing EditorHandoff.sign/5; add the shared editorial nav shell to Gaps and SuggestionReview; prove via extended suggestion_review_test.exs.

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-28T17:29:37Z
- **Completed:** 2026-05-28T17:34:25Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Wired the SEC-01 DB-write side at the SuggestionReview minting site: `record_editor_handoff(suggestion.id, scope_filters)` is now called before `EditorHandoff.sign/5` in `open_for_manual_edit`, satisfying T-10-09 at this entry point
- Minted token in SuggestionReview now carries `manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()` — satisfies T-10-11 token-layer gate
- Fixed the ConversationLive gate regression: `open_manual_draft` now also calls `record_editor_handoff/2` then mints a marker-bearing token; write failure is handled with a calm flash rather than a crash
- Added the shared `<.kb_nav current={:suggestions} />` nav shell to SuggestionReview and `<.kb_nav current={:gaps} />` to Gaps (KB-01 nav on all 4 KB routes)
- Extended `suggestion_review_test.exs` with a new test that asserts the DB handoff was recorded (`assert_received {:record_editor_handoff, 11, _opts}`) and the token decodes to a payload with a non-empty `manual_edit_opened_at` binary
- Fixed 3 pre-existing copy assertions in `suggestion_review_test.exs` to match Plan 02's new KB-04 action_label variants

## Task Commits

1. **Task 1: SuggestionReview — record DB handoff + sign marker-bearing token + shared nav** — `374ebe8`
2. **Task 2: ConversationLive open_manual_draft gate + Gaps shared nav** — `2ac5b4b`
3. **Task 3: Extend suggestion_review_test with DB handoff + marker-bearing token assertions** — `6cbc3ad`

## Files Created/Modified

- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — import NavComponent, record_editor_handoff before sign, manual_edit_opened_at marker opt, <.kb_nav current={:suggestions} />
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` — import NavComponent, <.kb_nav current={:gaps} />
- `lib/cairnloop/web/conversation_live.ex` — record_editor_handoff in {:ok, article_id} branch (fail-closed case wrap), manual_edit_opened_at marker opt
- `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` — MockKnowledgeAutomation.record_editor_handoff/2 clause, secret_key_base pin, new marker-token test, 3 updated action_label copy assertions
- `test/cairnloop/web/conversation_live_test.exs` — MockKnowledgeAutomation.record_editor_handoff/2 clause (Rule 1 fix for open_manual_draft test)

## Decisions Made

- ConversationLive `record_editor_handoff` wrapped in `case` (not bare `{:ok, _} =`) to surface write failures as calm "Manual draft could not be opened right now." flash — matches existing fail-closed posture on the same path.
- The three existing `suggestion_review_test.exs` action_label assertions ("Open for edit", "Open manual draft") were updated to match Plan 02's KB-04 copy variants. These were pre-existing failures introduced by Plan 02's `ReviewTaskPresenter.action_label/2` change.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed 3 pre-existing action_label copy assertions in suggestion_review_test.exs**
- **Found during:** Task 3 test run
- **Issue:** Plan 02 changed `ReviewTaskPresenter.action_label(:open_for_edit, task)` to return context-sensitive KB-04 variants; the existing tests still asserted the old "Open for edit" / "Open manual draft" strings
- **Fix:** Updated assertions to "Create manual draft" (article suggestion), "Open for manual edit" (revision suggestion, default), "Review and draft manually" (failed suggestion)
- **Files modified:** `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`
- **Commit:** 6cbc3ad

**2. [Rule 1 - Bug] Added record_editor_handoff/2 mock clause to conversation_live_test.exs MockKnowledgeAutomation**
- **Found during:** Post-Task-2 regression check on conversation_live_test.exs
- **Issue:** Task 2 added the `record_editor_handoff/2` call to the `open_manual_draft` path in ConversationLive; the test's MockKnowledgeAutomation did not have this function, causing UndefinedFunctionError
- **Fix:** Added `record_editor_handoff/2` returning `{:ok, suggestion}` to MockKnowledgeAutomation in conversation_live_test.exs
- **Files modified:** `test/cairnloop/web/conversation_live_test.exs`
- **Commit:** 6cbc3ad

## Cross-File Regression Note (for Phase 31)

**ConversationLive open_manual_draft is now inside the SEC-01 gate.** Any future work that touches the conversation → quick-fix → editor path must include BOTH:
1. `knowledge_automation().record_editor_handoff(suggestion_id, opts)` (DB write)
2. `manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()` passed to `EditorHandoff.sign/5`

Omitting either will cause the Editor's `verify!/2` gate to raise `Ecto.NoResultsError` (calm flash + redirect in Phase 30 Plan 03, but still a broken user flow).

## Test Results

- `mix compile --warnings-as-errors`: clean
- `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`: 12 tests, 0 failures
- `mix test test/cairnloop/web/conversation_live_test.exs`: 69 tests, 0 failures
- Full `mix test`: 737 tests, 6 failures (1 known baseline: Automation.DraftTest M005 drift; 5 pre-Plan-04 failures in KnowledgeBaseLiveTest from Plan 01's verify!/2 strengthening — Plan 03's scope to fix)

## Known Stubs

None — all behaviors fully implemented and tested. No placeholder data or unconnected data paths.

## Threat Flags

No new unplanned threat surface. Both `record_editor_handoff` calls thread scope opts through the existing `apply_scope/2` + `enforce_scope!/3` pipeline (inherited from Plan 01's facade implementation). The nav additions are purely presentational.

## Self-Check

Files modified:
- lib/cairnloop/web/knowledge_base_live/suggestion_review.ex: EXISTS (contains "record_editor_handoff", "manual_edit_opened_at", "kb_nav current={:suggestions}")
- lib/cairnloop/web/knowledge_base_live/gaps.ex: EXISTS (contains "kb_nav current={:gaps}")
- lib/cairnloop/web/conversation_live.ex: EXISTS (contains "record_editor_handoff", "manual_edit_opened_at")
- test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs: EXISTS (contains "record_editor_handoff", "manual_edit_opened_at")
- test/cairnloop/web/conversation_live_test.exs: EXISTS (contains "record_editor_handoff")

Commits:
- 374ebe8 — Task 1 (suggestion_review.ex)
- 2ac5b4b — Task 2 (conversation_live.ex, gaps.ex)
- 6cbc3ad — Task 3 (suggestion_review_test.exs, conversation_live_test.exs)
