---
phase: 37-component-primitives
plan: "03"
subsystem: web-components
tags: [component-primitives, cl_disclosure, cl_fact_list, tdd, token-purity, patch-safety]
dependency_graph:
  requires: ["37-02"]
  provides: [cl_disclosure/1, cl_fact_list/1]
  affects: ["37-04", "37-05", "41-rail-progressive-disclosure"]
tech_stack:
  added: []
  patterns:
    - phx-update="ignore" + stable id for browser-owned open state
    - :for comprehension for iterating list assigns
    - dedicated CSS class namespace (.cl-fact-list*) for standalone primitives
key_files:
  created: []
  modified:
    - lib/cairnloop/web/components.ex
    - test/cairnloop/web/components_test.exs
decisions:
  - cl_disclosure uses phx-update="ignore" + required stable id; open is static-at-mount only
  - cl_fact_list uses dedicated .cl-fact-list* classes (not .cl-details dl which is scoped inside disclosure)
  - P41 forward-compat guardrail recorded in docstring and SUMMARY
metrics:
  duration: "~25 minutes"
  completed: "2026-06-03"
  tasks: 2
  files_modified: 2
---

# Phase 37 Plan 03: cl_disclosure + cl_fact_list Summary

**One-liner:** `cl_disclosure/1` (patch-safe native `<details>` with `phx-update="ignore"`) and `cl_fact_list/1` (`<dl>` of label/value pairs with dedicated `.cl-fact-list` CSS) added via TDD with structural-marker and token-purity tests.

## What Was Built

### Task 1: `cl_disclosure/1` — patch-safe native disclosure (UIC-03 / D-03)

Added to `lib/cairnloop/web/components.ex`. The component:

- Wraps native `<details class="cl-details cl-disclosure">` with `phx-update="ignore"` and a **required stable `id`** — the combination guarantees LiveView's diff/patch algorithm never re-drives the `open` attribute after initial render.
- `open :boolean, default: false` is rendered ONLY as the static HTML boolean attribute at initial mount (HEEx renders `open={@open}` as present/absent correctly). It is NEVER bound to a server assign, NO `phx-click`, NO `Phoenix.LiveView.JS` (reserved for P41 rail-level controls).
- Required `:summary` slot renders inside `<summary class="cl-details__summary">`.
- Required `inner_block` slot renders the disclosure body.
- Reuses existing `.cl-details` CSS (`cairnloop.css:477-485`) — emits **no new CSS**.

**Forward-compat guardrail (P41 — recorded in docstring):** The `phx-update="ignore"` subtree freezes child content from server diffs after mount. Any live-updating content must be placed **outside** the `<details>` element, not inside the `inner_block`.

Three tests added:
1. `open=true` renders `<details`, `phx-update="ignore"`, stable id, `open` attr, `cl-details cl-disclosure` classes, summary text.
2. `open=false` (default) omits the `open` attribute but retains `phx-update="ignore"` and id.
3. Token-purity: `refute html =~ ~r/#[0-9a-fA-F]{3,6}/`.

### Task 2: `cl_fact_list/1` — label/value definition list (UIC-04 / D-05)

Added to `lib/cairnloop/web/components.ex`. The component:

- `attr(:facts, :list, default: [])` — list of `%{label: string, value: string}` maps.
- Emits `<dl class="cl-fact-list">` with `:for={fact <- @facts}` comprehension; each row is `<div class="cl-fact-list__row"><dt class="cl-fact-list__label">{fact.label}</dt><dd class="cl-fact-list__value">{fact.value}</dd></div>`.
- Optional `slot(:inner_block)` for custom rows rendered after the facts list.
- All text via auto-escaped `{fact.label}` / `{fact.value}` — never `raw/1` (satisfies T-37-05 XSS mitigation).
- Uses dedicated `.cl-fact-list*` classes. **Not** `.cl-details dl` — that is scoped inside `.cl-details` and would only apply when `cl_fact_list` is nested inside a disclosure. `cl_fact_list` is a standalone primitive.

Three tests added:
1. 2-element facts list renders `<dl class="cl-fact-list">`, `dt` labels, `dd` values.
2. `inner_block` custom rows render inside the same `<dl>`.
3. Token-purity: `refute html =~ ~r/#[0-9a-fA-F]{3,6}/`.

## TDD Gate Compliance

All tasks followed RED/GREEN/REFACTOR:

- **Task 1 RED:** `test(37-03): add failing tests for cl_disclosure/1 (RED)` — commit d76306d
- **Task 1 GREEN:** `feat(37-03): implement cl_disclosure/1 patch-safe native disclosure (UIC-03)` — commit d6399b4
- **Task 2 RED:** `test(37-03): add failing tests for cl_fact_list/1 (RED)` — commit 8e71fa9
- **Task 2 GREEN:** `feat(37-03): implement cl_fact_list/1 dedicated label/value list (UIC-04)` — commit c57a651

REFACTOR not needed — implementations are minimal and clean per PATTERNS.md skeletons.

## Verification

- `mix compile --warnings-as-errors` — exits 0
- `mix test test/cairnloop/web/components_test.exs` — 22 tests, 0 failures
- `mix test test/cairnloop/web/brand_token_gate_test.exs` — 1 test, 0 failures
- Combined: 23 tests, 0 failures

Acceptance criteria verified:
- `grep -F 'def cl_disclosure(' lib/cairnloop/web/components.ex` — matches
- `grep -F 'phx-update="ignore"' lib/cairnloop/web/components.ex` — present in disclosure markup
- `grep -F 'phx-click' lib/cairnloop/web/components.ex` inside cl_disclosure — NOT found
- `grep -F 'def cl_fact_list(' lib/cairnloop/web/components.ex` — matches
- `<dl class="cl-fact-list">` with `.cl-fact-list__label` / `.cl-fact-list__value` per fact — verified
- Token-purity gate passes for all new renders

## Deviations from Plan

None. Plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All new surface is pure render HTML. Threat mitigations applied:

- **T-37-05 (XSS):** All caller text rendered via HEEx auto-escaped `{...}`; no `Phoenix.HTML.raw/1` on caller input in either component.
- **T-37-06 (Stale UI):** `phx-update="ignore"` is the accept disposition for the frozen subtree; guardrail recorded in docstring for P41 adopters.
- **T-37-07 (Style drift):** `.cl-*` classes only, no inline style/hex. `refute html =~ ~r/#hex/` assertions enforce token-purity per-test.

## Known Stubs

None. Both components are fully wired — they render caller-supplied data through the correct HTML structures.

## Forward-compat Guardrails Recorded for P41

The `phx-update="ignore"` subtree on `cl_disclosure` **freezes child content** from server diffs after mount. This is the correct behavior for preserving browser-owned open state, but P41 adopters must be aware:

> Any content inside the `inner_block` that needs to update from server PubSub events must be placed **outside** the `<details>` element. Content inside the `<details>` will not update after the initial render.

This guardrail is recorded in:
1. The `cl_disclosure/1` `@doc` docstring in `components.ex`
2. This SUMMARY.md

## Self-Check: PASSED

Files confirmed:
- `lib/cairnloop/web/components.ex` — contains `def cl_disclosure(` and `def cl_fact_list(`
- `test/cairnloop/web/components_test.exs` — contains all 6 new test cases

Commits confirmed:
- d76306d: test(37-03): add failing tests for cl_disclosure/1 (RED)
- d6399b4: feat(37-03): implement cl_disclosure/1 patch-safe native disclosure (UIC-03)
- 8e71fa9: test(37-03): add failing tests for cl_fact_list/1 (RED)
- c57a651: feat(37-03): implement cl_fact_list/1 dedicated label/value list (UIC-04)
