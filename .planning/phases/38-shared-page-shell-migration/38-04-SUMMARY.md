---
phase: 38-shared-page-shell-migration
plan: "04"
subsystem: web-presenters
tags: [breadcrumb, shell-02, tdd, wire-up, kb-editor, suggestion-review]
dependency_graph:
  requires: [38-02, 38-03]
  provides: [wired-breadcrumb-editor, wired-breadcrumb-suggestion-review]
  affects:
    - lib/cairnloop/web/knowledge_base_live/editor.ex
    - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
tech_stack:
  added: []
  patterns: [presenter-idiom, tdd-red-green-refactor, slot-wire-up]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/knowledge_base_live/editor.ex
    - lib/cairnloop/web/knowledge_base_live/suggestion_review.ex
    - test/cairnloop/web/knowledge_base_live_test.exs
    - test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs
decisions:
  - "suggestion_review_crumb_title/1 private helper delegates to task_title/1 — keeps presenter call in template clean and consistent with the existing task-title idiom"
  - "Test fixtures for editor breadcrumb tests require return_to in params (not just in token) because EditorHandoff.verify! checks param vs token match — consistent with existing review-origin test pattern"
metrics:
  duration: "~30 minutes"
  completed: "2026-06-04T02:20:00Z"
  tasks_completed: 2
  files_created: 0
  files_modified: 4
---

# Phase 38 Plan 04: BreadcrumbPresenter Wire-up Summary

**One-liner:** Wired `BreadcrumbPresenter.editor_items/2` into the KB editor and added a `cl_breadcrumb` slot (via `suggestions_items/1`) to suggestion_review, closing SHELL-02 with origin-aware and static-lane breadcrumbs backed by 5 new render assertions.

## What Was Built

### Task 1: Origin-aware editor breadcrumb

`lib/cairnloop/web/knowledge_base_live/editor.ex` — replaced the static inline items list in the `:breadcrumb` slot (established by plan 38-02) with `BreadcrumbPresenter.editor_items(@review_context.return_to, @article.title)`. Added `alias Cairnloop.Web.BreadcrumbPresenter`.

Result:
- **Conversation origin** (`return_to = "/42"` or any non-KB path): 3-item trail — "Conversation" back crumb with `navigate` link → "Knowledge" → "Editing: <title>" (current, `aria-current="page"`)
- **Lane origin** (`return_to = "/knowledge-base/..."` path): 3-item trail — "Suggestions" back crumb with link → "Knowledge" → "Editing: <title>"
- **No origin** (`return_to = nil`): static 2-item fallback — "Knowledge" back link → "Editing: <title>"
- Raw `return_to` path is NEVER the crumb label (T-38-08 mitigated, negative-copy assertion confirms)
- The `@review_context.return_to` assign is the already-token-verified value from mount; no new decoding or trust boundary introduced (T-38-07 mitigation: unchanged)

### Task 2: Static lane breadcrumb in suggestion_review

`lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — suggestion_review previously had NO breadcrumb. Added:
- `alias Cairnloop.Web.BreadcrumbPresenter`
- `<:breadcrumb>` slot to `cl_page` with `BreadcrumbPresenter.suggestions_items(suggestion_review_crumb_title(@selected_task))`
- Private helper `suggestion_review_crumb_title/1` that returns the task title string when a task is selected, or nil otherwise

Result:
- **No selected task**: 2-item static lane crumb — "Knowledge" back link → "Suggestions" (current, `aria-current="page"`)
- **Selected task**: 3-item trail — "Knowledge" back link → "Suggestions" back link (`/knowledge-base/suggestions`) → task title (current)
- No conversation `return_to` invented (suggestion_review is a review-lane index, not a handoff receiver — Phase 42 threading is the correct home for that)

## TDD Gate Compliance

| Gate | Task | Commit | Status |
|------|------|--------|--------|
| RED — failing editor tests | Task 1 | `2759f63` | Passed (1 failure on `assert html =~ "Conversation"`) |
| GREEN — editor implementation | Task 1 | `b4135ca` | Passed (22 tests, 0 failures) |
| RED — failing suggestion_review tests | Task 2 | `2a73ee8` | Passed (2 failures on `assert html =~ "cl-breadcrumb"`) |
| GREEN — suggestion_review implementation | Task 2 | `74c10b3` | Passed (15 tests, 0 failures) |
| REFACTOR | both | skipped | No cleanup needed — implementations were minimal and clean |

## Tasks

| Task | Name | Commit(s) | Files |
|------|------|-----------|-------|
| 1 (RED) | Failing tests for origin-aware editor breadcrumb | `2759f63` | `test/cairnloop/web/knowledge_base_live_test.exs` |
| 1 (GREEN) | Wire BreadcrumbPresenter into editor :breadcrumb slot | `b4135ca` | `lib/cairnloop/web/knowledge_base_live/editor.ex` |
| 2 (RED) | Failing tests for static lane breadcrumb in suggestion_review | `2a73ee8` | `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` |
| 2 (GREEN) | Add cl_breadcrumb slot to suggestion_review | `74c10b3` | `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` |

## Verification Results

- `mix compile --warnings-as-errors` exits 0 (clean)
- `mix test test/cairnloop/web/knowledge_base_live_test.exs` — 22 tests, 0 failures
- `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` — 15 tests, 0 failures
- Combined: 37 tests, 0 failures
- `mix test` full suite: 888 tests, 2 failures (both are pre-existing baseline: `OutboundWorkerTest` + `SettingsLiveTest` — unchanged from baseline)
- `grep -c "BreadcrumbPresenter.editor_items" lib/cairnloop/web/knowledge_base_live/editor.ex` returns 1
- `grep -c "BreadcrumbPresenter" lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` returns 2
- `grep -c "<:breadcrumb>" lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` returns 1

## Acceptance Criteria Verification

### Task 1 (editor)
- [x] `BreadcrumbPresenter.editor_items` used in editor.ex ≥1 occurrence
- [x] Static inline items list replaced (no longer hardcoded in slot)
- [x] Render (conversation origin): `cl-breadcrumb`, `navigate="/42"`, `cl-breadcrumb__sep`, `aria-current="page"`, label "Conversation"; `>/42<` does NOT appear
- [x] Render (lane origin): label "Suggestions" with working back link
- [x] Render (no origin): "Knowledge" link + "Editing: " current crumb
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/cairnloop/web/knowledge_base_live_test.exs` exits 0

### Task 2 (suggestion_review)
- [x] `BreadcrumbPresenter` in suggestion_review.ex ≥1 occurrence
- [x] `<:breadcrumb>` slot in suggestion_review.ex ≥1 occurrence
- [x] Render: `cl-breadcrumb`, `/knowledge-base` back link, "Suggestions", `aria-current="page"`
- [x] No conversation/`return_to` invented (purely lane-derived crumb)
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` exits 0

## Deviations from Plan

None — plan executed exactly as written.

The `suggestion_review_crumb_title/1` helper was added as a minor implementation detail to keep the template expression clean; it wraps the existing `task_title/1` private function and is consistent with the module's existing pattern.

Test fixture setup required `"return_to"` to be passed as a URL param (not just in the token) for `EditorHandoff.verify!/2` to validate correctly — this matches the existing review-origin test pattern established in plan 38-02 tests and required no deviation from the plan's test approach.

## Known Stubs

None. Both wired breadcrumbs are fully live — editor crumbs are origin-derived from the already-verified `return_to` assign; suggestion_review crumbs are statically lane-derived from `@selected_task`. No data is mocked or deferred.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The wire-up reuses `@review_context.return_to` (already verified upstream via signed handoff token) and static lane assigns. T-38-07 (open-redirect via back crumb) and T-38-08 (raw path reflected as label) remain mitigated as planned — no new threat surface beyond the plan's threat model.

## Self-Check: PASSED

- `lib/cairnloop/web/knowledge_base_live/editor.ex` — FOUND
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — FOUND
- `test/cairnloop/web/knowledge_base_live_test.exs` — FOUND (22 tests)
- `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` — FOUND (15 tests)
- RED commit `2759f63` — FOUND
- GREEN commit `b4135ca` — FOUND
- RED commit `2a73ee8` — FOUND
- GREEN commit `74c10b3` — FOUND
- 37 combined tests, 0 failures — VERIFIED
