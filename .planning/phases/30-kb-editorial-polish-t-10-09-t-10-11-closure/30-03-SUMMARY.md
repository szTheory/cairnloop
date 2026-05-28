---
phase: 30-kb-editorial-polish-t-10-09-t-10-11-closure
plan: "03"
subsystem: kb-editorial-ui
tags: [elixir, phoenix, liveview, knowledge_base, gap_candidate, editor_handoff, nav, tdd]

# Dependency graph
requires:
  - plan: "30-01"
    provides: "list_articles/1, get_gap_candidate/2, EditorHandoff.verify!/2 with marker gate"
  - plan: "30-02"
    provides: "NavComponent.kb_nav/1 function component"

provides:
  - "Index.mount/3 reads via KnowledgeBase.list_articles/1 (arch invariant #5 restored)"
  - "Index.handle_event(new_article) — create_article + push_navigate + calm error flash"
  - "Index.render — shared nav shell <.kb_nav current={:index} />, New article button (bare brand tokens)"
  - "Editor.mount/3 try/rescue Ecto.NoResultsError — calm flash D-06 copy + push_navigate /knowledge-base/suggestions"
  - "Editor.load_gap_candidate_from_suggestion/2 — derives gap_candidate from suggestion.entrypoint_type/:gap_candidate"
  - "Editor.render — shared nav shell <.kb_nav current={:editor} />"
  - "Editor.render — read-only Source gap sidebar gated on @gap_candidate (D-07: top-level assign)"
  - "knowledge_base_live_test.exs — 16 green tests including 4 gate-rescue assertions + gap sidebar + new_article"

affects:
  - "lib/cairnloop/web/knowledge_base_live/index.ex (modified)"
  - "lib/cairnloop/web/knowledge_base_live/editor.ex (modified)"
  - "test/cairnloop/web/knowledge_base_live_test.exs (updated)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "try/rescue Ecto.NoResultsError in mount/3: whole-body rescue returns {:ok, socket} with put_flash + push_navigate — fail-closed, redirect always valid"
    - "load_gap_candidate_from_suggestion/2: case {entrypoint_type, entrypoint_id} pattern — nil-guard for non-gap entrypoints"
    - "socket_with_flash/0 test helper: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}} — required for put_flash in headless socket tests"

key-files:
  created: []
  modified:
    - lib/cairnloop/web/knowledge_base_live/index.ex
    - lib/cairnloop/web/knowledge_base_live/editor.ex
    - test/cairnloop/web/knowledge_base_live_test.exs

decisions:
  - "socket_with_flash/0 helper introduced for rescue/flash-assertion tests: %Phoenix.LiveView.Socket{} lacks assigns.flash by default; put_flash/3 requires it. Used only for tests that trigger the rescue path."
  - "Gap sidebar gated on @gap_candidate (top-level assign via load_gap_candidate_from_suggestion/2), NOT @review_context.gap_candidate — implementing D-07 which supersedes UI-SPEC §3's gap_candidate_id-in-token approach"
  - "Pre-existing sealed render literals (#e5e7eb, #f8fafc, #fff) in editor.ex left untouched per CLAUDE.md seal policy; only new markup uses bare var(--cl-*) tokens"
  - "All 4 assert_raise tests converted to flash+redirect assertions: whole-body rescue in mount/3 catches ALL Ecto.NoResultsError including those from ensure_editor_target_matches! and ensure_review_task_match!"

metrics:
  duration: "~40 min"
  completed: "2026-05-28T17:37:00Z"
  tasks_completed: 3
  files_changed: 3
---

# Phase 30 Plan 03: LiveView Wiring — Index/Editor + Test Updates Summary

Index reads via `list_articles/1`, renders shared nav + New article button; Editor derives + renders read-only Source gap sidebar, rescues gate failures into exact calm flash + redirect; all 16 `knowledge_base_live_test.exs` tests green with marker-bearing tokens and rescue assertions replacing assert_raise.

## Performance

- **Duration:** ~40 min
- **Started:** 2026-05-28T17:00:00Z
- **Completed:** 2026-05-28T17:37:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Replaced `repo().all(Article)` with `KnowledgeBase.list_articles(scope_filters(session))` in Index.mount — restores arch invariant #5 (no direct schema queries from web layer)
- Added `handle_event("new_article")` to Index mirroring the existing `suggest_revision` event shape: `create_article(%{title: "Untitled article", status: :draft})` → `push_navigate` or calm error flash
- Added New article button to Index render with bare brand tokens (cl-primary, cl-primary-text, cl-radius-sm), min-height 44px, phx-click-loading disabled treatment
- Added empty-state copy ("No articles yet." + "Create the first article...") when `@articles == []`
- Added `import NavComponent` + `<.kb_nav current={:index} />` to Index render
- Wrapped Editor.mount/3 body in `try/rescue Ecto.NoResultsError` — returns `{:ok, socket}` with exact D-06 calm flash + `push_navigate(to: "/knowledge-base/suggestions")` — never re-raises
- Added `load_gap_candidate_from_suggestion/2`: when `suggestion.entrypoint_type == :gap_candidate and is_integer(entrypoint_id)` → calls `knowledge_automation().get_gap_candidate(gid, scope_filters)`, else `nil`
- Added `:gap_candidate` assign to Editor mount assign chain
- Added Source gap sidebar in Editor render: `aria-label="Source gap evidence"`, gated on `@gap_candidate`, shows gap title, evidence count chip (`"#{evidence_count} evidence"`), freshness label via `GapCandidatePresenter.freshness_label/1`, "Retrieval evidence" section with empty fallback
- Added `<.kb_nav current={:editor} />` to Editor render
- Updated `knowledge_base_live_test.exs`: 7 sign calls updated with `manual_edit_opened_at` opt; 4 `assert_raise` tests rewritten as flash+redirect assertions; `get_gap_candidate/2` added to `MockKnowledgeAutomation`; gap sidebar test (Source gap, gap title, "2 evidence", "Seen today"); non-gap test (refute "Source gap"); new_article tests (push_navigate + error flash)

## Task Commits

1. **Task 1: Wire Index to list_articles/1, shared nav shell, and New article button** - `fd9f0e4` (feat)
2. **Task 2: Add Editor gap sidebar, mount rescue, and shared nav shell** - `e99aa8c` (feat)
3. **Task 3: Update knowledge_base_live_test.exs** - `76d3119` (test)

## Files Created/Modified

- `lib/cairnloop/web/knowledge_base_live/index.ex` — Replaced `repo().all(Article)` with `list_articles/1`; added `handle_event("new_article")`; added `<.kb_nav current={:index} />`; added New article button (bare brand tokens); added empty-state copy
- `lib/cairnloop/web/knowledge_base_live/editor.ex` — Wrapped mount/3 in try/rescue; added `load_gap_candidate_from_suggestion/2`; added `:gap_candidate` assign; added `<.kb_nav current={:editor} />`; added Source gap sidebar
- `test/cairnloop/web/knowledge_base_live_test.exs` — 7 sign calls updated; 4 assert_raise → flash+redirect; `get_gap_candidate/2` + suggestion fixtures 18/19 added to Mock; gap sidebar + non-gap + new_article tests added; `socket_with_flash/0` helper added

## Decisions Made

- **socket_with_flash/0 helper:** `%Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}` required because `put_flash/3` reads `assigns.flash` (KeyError on plain socket). Only flash-path tests use it; non-flash tests continue to use `%Phoenix.LiveView.Socket{}`.
- **D-07 supersedes UI-SPEC §3:** Gap sidebar gated on `@gap_candidate` (top-level assign), not `@review_context.gap_candidate` or a URL `gap_candidate_id` param. `load_gap_candidate_from_suggestion/2` derives the gap from `suggestion.entrypoint_type/:gap_candidate + entrypoint_id` — no token/URL change required.
- **Whole-body rescue:** All `Ecto.NoResultsError` raised inside mount/3 (from verify!, ensure_editor_target_matches!, ensure_review_task_match!, ensure_review_task_target_matches!, get!) are caught by the single rescue clause — fail-closed per D-06 intent.

## Tests Converted from assert_raise to flash+redirect assertions

| Test | Previously | Now |
|------|-----------|-----|
| "editor rejects bare suggestion ids without a signed handoff" | `assert_raise Ecto.NoResultsError` | `{:ok, socket}` with flash == D-06 copy |
| "editor rejects suggestion ids that do not belong to the route article" | `assert_raise Ecto.NoResultsError` | `{:ok, socket}` with flash == D-06 copy |
| "editor rejects review tasks that do not belong to the selected suggestion" | `assert_raise Ecto.NoResultsError` | `{:ok, socket}` with flash == D-06 copy |
| "editor rejects bare review_task ids that target a different article" | `assert_raise Ecto.NoResultsError` | `{:ok, socket}` with flash == D-06 copy |

## Gap-Sidebar Mock Fixture Shape (for Phase 31 golden-path test reuse)

```elixir
# MockKnowledgeAutomation.get_gap_candidate/2
def get_gap_candidate(7, _opts) do
  %GapCandidate{
    id: 7,
    title: "Billing export gap",
    seed_excerpt: "Customers cannot export billing data",
    candidate_type: :manual_handling,
    evidence_count: 2,
    last_seen_at: DateTime.utc_now()
  }
end

# ArticleSuggestion fixture with gap entrypoint
%ArticleSuggestion{
  id: 18,
  entrypoint_type: :gap_candidate,
  entrypoint_id: 7,
  ...
}
```

Expected rendered HTML:
- `html =~ "Source gap"` — sidebar heading
- `html =~ "Billing export gap"` — gap title
- `html =~ "2 evidence"` — evidence_count chip
- `html =~ "Seen today"` — GapCandidatePresenter.freshness_label/1 for recent last_seen_at

## Deviations from Plan

None — plan executed exactly as written. One implementation detail added inline: the `socket_with_flash/0` test helper was discovered necessary because `%Phoenix.LiveView.Socket{}` lacks `assigns.flash` by default, causing `put_flash/3` in the rescue path to raise `KeyError`. This is a test infrastructure detail, not a deviation from plan intent.

## Known Stubs

None — all behaviors are fully implemented and tested. The gap sidebar renders real data from `GapCandidatePresenter` helpers; the New article button creates a real article struct via `KnowledgeBase.create_article/1`.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced. All new LiveView event handlers (`new_article`) follow the existing `suggest_revision` event shape with the same error handling pattern. The mount rescue is additive safety (converts raises to calm UI responses) — it does not bypass any auth gates.

## Self-Check: PASSED

Files created/modified:
- lib/cairnloop/web/knowledge_base_live/index.ex: FOUND
- lib/cairnloop/web/knowledge_base_live/editor.ex: FOUND
- test/cairnloop/web/knowledge_base_live_test.exs: FOUND
- .planning/phases/30-kb-editorial-polish-t-10-09-t-10-11-closure/30-03-SUMMARY.md: FOUND

Commits:
- fd9f0e4 — Task 1 (Wire Index to list_articles/1, shared nav shell, and New article button)
- e99aa8c — Task 2 (Add Editor gap sidebar, mount rescue, and shared nav shell)
- 76d3119 — Task 3 (Update knowledge_base_live_test.exs)

Test results:
- `mix test test/cairnloop/web/knowledge_base_live_test.exs`: 16 tests, 0 failures
- `mix test test/cairnloop/web/knowledge_base_live/editor_handoff_test.exs`: 5 tests, 0 failures (no regression)
- `mix compile --warnings-as-errors`: clean
