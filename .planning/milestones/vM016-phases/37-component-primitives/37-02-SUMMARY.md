---
phase: 37-component-primitives
plan: "02"
subsystem: web-components
tags: [components, ui, primitives, cl_page, cl_hero, cl_stat, phoenix-component]
dependency_graph:
  requires: []
  provides: [cl_page/1, cl_hero/1, cl_stat-integer-contract]
  affects: [lib/cairnloop/web/components.ex, test/cairnloop/web/components_test.exs]
tech_stack:
  added: []
  patterns: [phoenix-component-slots, tdd-red-green, slot-emptiness-guard, named-slot-cta]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/components.ex
    - test/cairnloop/web/components_test.exs
decisions:
  - "cl_hero CTA uses <.link navigate=...> with cl-button--primary classes (not cl_button navigate attr — button wraps <button>, not <a>)"
  - "cl_hero CTA override uses explicit :cta_slot named slot (not inner_block) to avoid Phoenix whitespace-capture false-positive"
metrics:
  duration: "~25 minutes"
  completed: "2026-06-03"
  tasks_completed: 3
  files_modified: 2
---

# Phase 37 Plan 02: Component Primitives — Shell + Hero + Stat Narrowing Summary

**One-liner:** `cl_stat` narrowed to `count :integer`, `cl_page/1` inner page-shell with enum width + named slots, and `cl_hero/1` copper Fraunces count primitive with `:detail` slot + attrs-or-slot CTA — all token-pure with headless render tests.

## What Was Built

### Task 1: cl_stat de-polymorphization (D-01)

Changed `attr(:count, :any, required: true)` → `attr(:count, :integer, required: true)` in `cl_stat/1` (components.ex). This is the API-contract narrowing ratified in D-01: `cl_stat` is a numeric tile; health strings route through `cl_chip` in P39. No markup change; Phoenix validates attr types at compile time for literal assigns — a literal non-integer would now surface as a `--warnings-as-errors` failure, providing early detection of callers passing the wrong type.

Added 2 render tests: integer count renders in `.cl-stat__count`, `calm?` variant + job/href preserved, `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` token-purity.

### Task 2: cl_page/1 (UIC-01 / D-08)

Added `cl_page/1` — the inner page frame that renders inside `cl_shell`'s `.cl-main`. Follows the `cl_card` slot-emptiness-guard idiom (`:if={@slot != []}`):

- **attrs:** `title :string required`, `subtitle :string default: nil`, `width :string values: ~w(wide reading) default: "wide"` (single enum attr per D-08, not two booleans)
- **slots:** `:breadcrumb` (optional, above h1), `:actions` (optional, right-aligned in header row via `.cl-row.cl-row--between`), `:subnav` (optional, between header and body), `:inner_block required`
- **markup:** `<div class={["cl-page", "cl-page--#{@width}"]}>`  with `.cl-page__header`, `.cl-page__title`, `.cl-page__subtitle`, `.cl-page__subnav`, `.cl-page__body`
- Renders caller text via auto-escaped `{...}` interpolation — no `raw/1`
- Token-only: no inline style/hex

Added 4 render tests: wide default (h1 + cl-page--wide), reading width (cl-page--reading), all slots + subtitle, token-purity.

### Task 3: cl_hero/1 (UIC-02 / D-02)

Added `cl_hero/1` as a **distinct component** (not a `cl_stat variant="hero"` — D-02 prohibits re-polymorphizing the just-narrowed stat):

- **attrs:** `count :integer required`, `job :string required`, `href :string default: nil`, `cta :string default: nil`, `calm? :boolean default: false`
- **slots:** `:detail` (optional quiet sub-line, generic enough for P39 Recover-resolved), `:cta_slot` (explicit named CTA slot override), `:inner_block`
- **CTA precedence:** `:cta_slot` wins; else `cta`/`href` attrs render `<.link navigate=... class="cl-button cl-button--primary">`
- **markup:** `<section class="cl-hero">` with `.cl-hero__job`, `.cl-hero__count` (copper Fraunces count), `.cl-hero__count--calm` when `calm?`, `.cl-hero__detail`, `.cl-hero__cta`
- Token-only; auto-escaped `{...}` interpolation

Added 4 render tests: count+job, calm state, attrs CTA + detail slot, token-purity.

## Verification

- `mix compile --warnings-as-errors`: exits 0
- `mix test test/cairnloop/web/components_test.exs`: 16 tests, 0 failures (6 pre-existing + 10 new)
- `mix test test/cairnloop/web/brand_token_gate_test.exs`: 1 test, 0 failures

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] cl_hero CTA: navigate attr not valid on cl_button**

- **Found during:** Task 3 GREEN phase
- **Issue:** The plan's action step said to render `<.cl_button variant="primary" navigate={@href}>` — but `cl_button` wraps a `<button>` element, not a `<.link>`. The `navigate` attr is a Phoenix Link attribute not accepted by `<button>`, producing a compile-time `--warnings-as-errors` failure.
- **Fix:** Used `<.link navigate={@href} class="cl-button cl-button--primary">` instead. This produces identical visual output (a primary-styled link button) and is the correct Phoenix pattern for navigation CTAs.
- **Files modified:** `lib/cairnloop/web/components.ex`
- **Commit:** f0c442d

**2. [Rule 1 - Bug] cl_hero CTA slot detection: inner_block != [] unreliable with named slots**

- **Found during:** Task 3 GREEN phase, test failure
- **Issue:** The plan used `slot(:inner_block)` as the explicit CTA override slot, checking `@inner_block != []`. In Phoenix Component, when a caller provides only named slots (like `<:detail>`) inside the component tags, whitespace/newlines in the body can cause `@inner_block != []` to be `true` even with no actual CTA content — causing the attrs-based CTA to be suppressed.
- **Fix:** Replaced `slot(:inner_block)` CTA pattern with a dedicated `slot(:cta_slot)` named slot. The `:cta_slot != []` check is unambiguous (no whitespace capture). The `inner_block` slot is retained as documented for forward-compat.
- **Files modified:** `lib/cairnloop/web/components.ex`, `test/cairnloop/web/components_test.exs`
- **Commit:** f0c442d

## Known Stubs

None. All components are fully implemented with no placeholder data or TODOs.

## Threat Flags

No new security surface introduced. Components are pure presentational render functions with no auth/session/data-access surface. XSS mitigations from threat model T-37-03 and T-37-04 are confirmed:

- All caller-supplied strings rendered via HEEx auto-escaped `{...}` — `raw/1` not used in `cl_page` or `cl_hero`
- Token-purity confirmed by `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` in all new tests and brand gate green

## Commits

| Task | Commit | Message |
|------|--------|---------|
| Task 1 — cl_stat :integer | 181d756 | feat(37-02): de-polymorphize cl_stat count attr to :integer |
| Task 2 — cl_page/1 | e4da6d5 | feat(37-02): add cl_page/1 page-shell component (UIC-01 / D-08) |
| Task 3 — cl_hero/1 | f0c442d | feat(37-02): add cl_hero/1 copper primary-count component (UIC-02 / D-02) |

## Self-Check: PASSED

- `lib/cairnloop/web/components.ex` — exists, contains `def cl_page(`, `def cl_hero(`, `attr(:count, :integer` (x2)
- `test/cairnloop/web/components_test.exs` — exists, 16 tests
- All 3 task commits verified in git log
- `mix compile --warnings-as-errors` exits 0
- All tests green
