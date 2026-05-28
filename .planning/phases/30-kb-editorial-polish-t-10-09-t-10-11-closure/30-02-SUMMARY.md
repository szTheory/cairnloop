---
phase: 30
plan: "02"
subsystem: kb-editorial-ui
tags: [kb, nav, presenter, copy, brand-tokens, tdd, pure-test]
dependency_graph:
  requires: []
  provides:
    - "Cairnloop.Web.KnowledgeBaseLive.NavComponent.kb_nav/1 — import and call <.kb_nav current={:index|:editor|:suggestions|:gaps} />"
    - "ReviewTaskPresenter.action_label/2 — 3-variant KB-04 calm copy"
  affects:
    - "lib/cairnloop/web/knowledge_base_live/nav_component.ex (new)"
    - "lib/cairnloop/web/review_task_presenter.ex (extended)"
tech_stack:
  added: []
  patterns:
    - "Phoenix.Component function component with typed attr"
    - "cond-based presenter copy dispatch (3-variant action_label)"
    - "TDD RED/GREEN cycle for pure presenter + render tests"
key_files:
  created:
    - "lib/cairnloop/web/knowledge_base_live/nav_component.ex"
    - "test/cairnloop/web/knowledge_base_live/nav_component_test.exs"
    - "test/cairnloop/web/review_task_presenter_test.exs"
  modified:
    - "lib/cairnloop/web/review_task_presenter.ex"
decisions:
  - "cond used (vs case) for action_label/2 to allow compound boolean predicates (suggestion.status AND suggestion_type check)"
  - "active/inactive nav link styles computed via nav_link_style/1 helper to keep ~H template clean"
  - "Tasks 1+2 committed together — test and implementation are the TDD unit for NavComponent"
metrics:
  duration: "~30 minutes"
  completed: "2026-05-28T17:21:32Z"
  tasks_completed: 3
  files_changed: 4
---

# Phase 30 Plan 02: NavComponent + action_label/2 KB-04 Copy Variants Summary

NavComponent.kb_nav/1 function component rendering three routed KB nav links with aria-current + primary border active marker (bare brand tokens only), plus ReviewTaskPresenter.action_label/2 extended to three UI-SPEC §KB-04 calm copy variants.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create NavComponent.kb_nav/1 shared editorial nav function component | a8f8937 | lib/cairnloop/web/knowledge_base_live/nav_component.ex (new) |
| 2 | Pure nav_component_test.exs covering links, active marker, aria-current | a8f8937 | test/cairnloop/web/knowledge_base_live/nav_component_test.exs (new) |
| 3 | Extend action_label/2 to 3 calm KB-04 copy variants + pure presenter test | 34ce457 | lib/cairnloop/web/review_task_presenter.ex (modified), test/cairnloop/web/review_task_presenter_test.exs (new) |

## What Was Built

### NavComponent (KB-01)

New module `Cairnloop.Web.KnowledgeBaseLive.NavComponent`:
- `kb_nav/1` — public function component, `attr :current, :atom, required: true`
- Private `kb_nav_link/1` with `to`, `label`, `active` attrs
- Renders `<nav aria-label="Knowledge base">` container (UI-SPEC §1 visual spec)
- Three `<.link navigate={...}>` entries: "Knowledge base" → `/knowledge-base`, "Suggestions" → `/knowledge-base/suggestions`, "Gaps" → `/knowledge-base/gaps`
- Active state: `aria-current="page"` + `border-bottom: 2px solid var(--cl-primary)` (never color alone — brand §7.5)
- `:editor` current value renders no active marker
- All CSS: bare `var(--cl-*)` tokens, no hex fallbacks (BRAND-04 compliant)

Usage by Plans 03 and 04:
```elixir
import Cairnloop.Web.KnowledgeBaseLive.NavComponent
# in render/1 ~H block:
<.kb_nav current={:index} />   # or :editor | :suggestions | :gaps
```

### ReviewTaskPresenter action_label/2 (KB-04)

Changed `action_label(:open_for_edit)` from `"Open for edit"` to `"Open for manual edit"`.

Rewrote the 2-arity `action_label/2` suggestion clause with `cond` to implement UI-SPEC §KB-04:

| Condition | Return value |
|-----------|-------------|
| `suggestion.status == :failed` | `"Review and draft manually"` |
| `suggestion.suggestion_type == :article` OR `quick_fix_outcome_label == "Manual draft required"` | `"Create manual draft"` |
| (default) | `"Open for manual edit"` |

Note: UI-SPEC's `:new_article` maps to the in-tree `:article` enum value (confirmed from `@suggestion_type_values [:article, :revision]` — no `:new_article` exists).

All other `action_label/1` clauses (`:approve`, `:reject`, `:defer`, `:publish`) and the `action_label(action, _task)` fallback are unchanged.

## Test Results

- `nav_component_test.exs` — 8 tests, 0 failures (pure render assertions)
- `review_task_presenter_test.exs` — 13 tests, 0 failures (pure presenter assertions)
- `brand_token_gate_test.exs` — 1 test, 0 failures (BRAND-04 gate still passes)
- `mix compile --warnings-as-errors` — clean

## Deviations from Plan

None — plan executed exactly as written.

## TDD Gate Compliance

- RED commits: tests written and confirmed failing before implementation
- GREEN commits: implementation added to pass all tests
- No REFACTOR step needed (code already clean)

Tasks 1+2 are committed together (a8f8937) as a single TDD unit — the component and its test form one atomic change.

## Known Stubs

None — all behaviors are fully implemented and tested.

## Threat Flags

None — NavComponent is purely presentational (no network endpoints, no auth paths, no DB reads). ReviewTaskPresenter change is a pure string-returning function. No new threat surface introduced.

## Self-Check

Files created/modified:
- lib/cairnloop/web/knowledge_base_live/nav_component.ex: EXISTS
- test/cairnloop/web/knowledge_base_live/nav_component_test.exs: EXISTS
- lib/cairnloop/web/review_task_presenter.ex: MODIFIED (contains "Open for manual edit", "Create manual draft", "Review and draft manually")
- test/cairnloop/web/review_task_presenter_test.exs: EXISTS

Commits:
- a8f8937 — Tasks 1+2 (NavComponent + nav_component_test.exs)
- 34ce457 — Task 3 (action_label/2 + review_task_presenter_test.exs)
