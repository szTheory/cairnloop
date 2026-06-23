---
phase: 42-cross-screen-threading
plan: "05"
subsystem: web-presenter-liveview
tags: [breadcrumb, knowledge-base, editor, cross-screen-threading, thread-03b, origin-crumb, tdd]
dependency_graph:
  requires: [plans/42-02]
  provides: [BreadcrumbPresenter.editor_items/3, editor origin_conversation_id assign]
  affects: []
tech_stack:
  added: []
  patterns: [total-function-presenter, editor_items/3-arity-extension, knowledge_automation-facade-indirection, scope-root-relative-crumb-href, honest-absence-nil-guard]
key_files:
  created:
    - test/cairnloop/web/knowledge_base_live/editor_test.exs
  modified:
    - lib/cairnloop/web/breadcrumb_presenter.ex
    - lib/cairnloop/web/knowledge_base_live/editor.ex
    - test/cairnloop/web/breadcrumb_presenter_test.exs
decisions:
  - "editor_items/3(origin_id, return_to, title) chosen over optional-arg or separate fn — cleanest total-fn idiom, seals existing /2 clauses byte-for-byte"
  - "Headless test assertion uses href=/id not navigate=/id — Phoenix .link navigate renders as <a href=...> in rendered_to_string"
  - "Symlinked deps/_build from main project into worktree to enable mix test from worktree directory"
metrics:
  duration: "~6 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 4
---

# Phase 42 Plan 05: KB Editor → Originating-Conversation Breadcrumb Crumb Summary

**One-liner:** `BreadcrumbPresenter.editor_items/3` with a new `origin_conversation_id` first arg — when non-nil it prepends a scope-root-relative "From conversation" crumb, delegating to `editor_items/2` on nil — wired into the editor mount via `KnowledgeAutomation.originating_conversation_id(article.id, scope_filters)`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing tests for BreadcrumbPresenter.editor_items/3 | 7b61ccb | test/cairnloop/web/breadcrumb_presenter_test.exs |
| 1 (GREEN) | BreadcrumbPresenter.editor_items/3 implementation | a1dc2b3 | lib/cairnloop/web/breadcrumb_presenter.ex |
| 2 (RED) | Failing tests for editor origin crumb | fb9b505 | test/cairnloop/web/knowledge_base_live/editor_test.exs |
| 2 (GREEN) | Editor mount + breadcrumb slot wired | aeaf954 | lib/cairnloop/web/knowledge_base_live/editor.ex, test/cairnloop/web/knowledge_base_live/editor_test.exs |

## What Was Built

### Task 1: BreadcrumbPresenter.editor_items/3

Added to `lib/cairnloop/web/breadcrumb_presenter.ex` above the existing `editor_items/2` clauses.

```elixir
def editor_items(origin_conversation_id, return_to, title) when not is_nil(origin_conversation_id) do
  [%{label: "From conversation", href: "/#{origin_conversation_id}"} | editor_items(return_to, title)]
end

def editor_items(nil, return_to, title) do
  editor_items(return_to, title)
end
```

- When `origin_conversation_id` is non-nil: prepends `%{label: "From conversation", href: "/#{id}"}` as the first crumb, followed by the existing `editor_items/2` output (scope-root-relative, Pitfall 3, T-42-15)
- When nil: delegates to `editor_items/2` exactly (honest absence, D-12, Pitfall 4)
- Existing `editor_items/2` clauses sealed and untouched
- Total function: explicit `when not is_nil` clause + explicit `nil` fallback
- Returns data only (list of `%{label, href}` maps), never markup

### Task 2: Editor mount + breadcrumb thread

In `lib/cairnloop/web/knowledge_base_live/editor.ex` `mount/3`:

```elixir
origin_conversation_id =
  knowledge_automation().originating_conversation_id(article.id, scope_filters)

socket =
  socket
  |> ...
  |> assign(origin_conversation_id: origin_conversation_id)
```

- `article.id`-keyed lookup, not the in-scope `suggestion` (nil on direct visit — Pitfall 2)
- Routes through `knowledge_automation()` indirection — no raw `Cairnloop.Repo` (criterion-4, D-03)
- `scope_filters` already computed at mount, passed through (T-42-13 / V4 operator scope)

Breadcrumb slot updated:

```heex
<.cl_breadcrumb items={BreadcrumbPresenter.editor_items(@origin_conversation_id, @review_context.return_to, @article.title)} />
```

## Test Coverage

### BreadcrumbPresenter (headless, no Repo)

Added 8 new tests to `test/cairnloop/web/breadcrumb_presenter_test.exs`:

- Present origin id → first crumb is `%{label: "From conversation", href: "/99"}`
- Present origin id → href is scope-root-relative (no `/support` prefix)
- Present origin id → `[_ | rest]` equals `editor_items/2` output
- Present origin id → last-crumb contract holds
- Nil origin id → output equals `editor_items/2` (no extra crumb)
- Nil origin id → last-crumb contract holds
- Nil both → 2-item static fallback (same as `editor_items/2` nil)
- Exhaustive last-crumb contract across all 4 clause variants

### Editor (headless render, no Repo)

Created `test/cairnloop/web/knowledge_base_live/editor_test.exs` with 6 tests:

- Present origin id → rendered HTML contains "From conversation"
- Present origin id → rendered breadcrumb contains `href="/99"` (scope-root-relative)
- Present origin id → no `/support` mount prefix in href
- Nil origin id → no "From conversation" crumb (honest absence, D-12)
- Non-regression: cl_page shell renders (Phase 38 SHELL-01)
- Non-regression: article title present in rendered HTML

The DB-backed mount resolution (`originating_conversation_id/2` round-trip) is covered by Plan 02's REPO-UNAVAILABLE integration tests.

## Deviations from Plan

### Auto-fixed (Rule 1 — Bug): Headless test href format

- **Found during:** Task 2 GREEN phase
- **Issue:** Plan specified asserting `navigate="/99"` in rendered HTML, but Phoenix `<.link navigate={...}>` renders as `<a href="..." data-phx-link="redirect">` in `rendered_to_string/1` output — the `navigate` attribute does not appear in the output
- **Fix:** Updated test assertion to `href="/99"` which correctly matches the rendered output
- **Files modified:** test/cairnloop/web/knowledge_base_live/editor_test.exs
- **Commit:** aeaf954

## Threat Model Coverage

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-42-13 | `originating_conversation_id/2` pipes through `apply_scope/2` (Plan 02); `scope_filters(session)` passed from mount | Inherited from Plan 02 implementation |
| T-42-14 | Nil origin id → crumb omitted entirely (honest absence, D-12); no `/nil` href | Implemented via `editor_items/3` nil clause |
| T-42-15 | Crumb href is `/#{id}` (scope-root-relative); grep gate confirms no `/support/` | Implemented + gated |

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. The origin-conversation crumb is a pure render-layer additive using an existing scoped facade read.

## Known Stubs

None — the origin crumb is fully wired. The DB-backed integration path requires a live Postgres round-trip (plan 02 integration tests) but the render layer is complete.

## Self-Check: PASSED

- [x] `lib/cairnloop/web/breadcrumb_presenter.ex` contains `def editor_items(origin_conversation_id`
- [x] `lib/cairnloop/web/breadcrumb_presenter.ex` contains `"From conversation"`
- [x] `lib/cairnloop/web/knowledge_base_live/editor.ex` contains `originating_conversation_id`
- [x] `test/cairnloop/web/knowledge_base_live/editor_test.exs` exists
- [x] `grep 'Cairnloop.Repo\.' lib/cairnloop/web/knowledge_base_live/editor.ex` → no matches
- [x] `grep '/support/' lib/cairnloop/web/breadcrumb_presenter.ex lib/cairnloop/web/knowledge_base_live/editor.ex` → no matches
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/cairnloop/web/breadcrumb_presenter_test.exs test/cairnloop/web/knowledge_base_live/editor_test.exs` → 43 tests, 0 failures
- [x] Commits 7b61ccb, a1dc2b3, fb9b505, aeaf954 all exist in git log
