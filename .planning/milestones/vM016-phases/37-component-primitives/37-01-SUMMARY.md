---
phase: 37-component-primitives
plan: "01"
subsystem: css-design-system
tags: [css, design-tokens, layout, primitives, accessibility]
dependency_graph:
  requires: []
  provides:
    - layout-tokens-cl-content-max-cl-rail-width-cl-page-gutter
    - inert-utilities-cl-gap-2-cl-align-center-cl-justify-between
    - cl-table-scroll-accessible-wrapper
    - primitive-css-cl-page-cl-hero-cl-fact-list-cl-source-card-cl-switch
    - cairnloop-css-test-machine-verification-uic-05
  affects:
    - priv/static/cairnloop.css
    - test/cairnloop/web/cairnloop_css_test.exs
tech_stack:
  added: []
  patterns:
    - BEM .cl-block__element--modifier CSS convention (existing, extended)
    - bare var(--cl-*) token-only CSS — zero hardcoded hex
    - ExUnit File.read!/1 CSS presence test (headless, Repo-free)
key_files:
  created:
    - test/cairnloop/web/cairnloop_css_test.exs
  modified:
    - priv/static/cairnloop.css
decisions:
  - "Layout tokens placed in :root near control-sizing block (D-09); var() is illegal in @media, so tokens drive max-width values only — breakpoints stay literal"
  - "Inert utilities placed adjacent to .cl-row/.cl-stack family; exactly three (D-10) — no utility framework growth"
  - ".cl-table-scroll:focus-visible mirrors the existing .cl-focusable:focus-visible convention with bare var(--cl-focus-ring) and var(--cl-radius-xs)"
  - ".cl-source-card variant triplets use the identical surface/border/text shape as .cl-chip variants for design-system coherence"
  - ".cl-switch uses [aria-checked=true] attribute selector to drive track fill — never color alone (brand §7.5)"
  - "cl_fact_list gets dedicated .cl-fact-list CSS (not reusing .cl-details dl) because .cl-details dl/dt/dd is scoped inside .cl-details (standalone use would be unstyled)"
  - "CSS presence test uses File.read!/1 from File.cwd!() — simple, Repo-free, works in fast headless suite"
metrics:
  duration: "4m"
  completed: "2026-06-03T23:05:20Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 1
---

# Phase 37 Plan 01: CSS Token and Primitive Classes Summary

Three layout tokens, three inert utility classes, `.cl-table-scroll` accessible wrapper, full BEM visual CSS for five primitive families, and a machine-verification CSS presence test — all bare `var(--cl-*)` tokens, zero hardcoded hex.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add layout tokens + inert utilities + .cl-table-scroll | af45388 | priv/static/cairnloop.css (+15 lines) |
| 2 | Add primitive visual CSS (cl_page, cl_hero, cl_fact_list, cl_source_card, cl_switch) | ffca08e | priv/static/cairnloop.css (+126 lines) |
| 3 | Add CSS-presence test (machine-verify UIC-05's CSS half) | 4af11f9 | test/cairnloop/web/cairnloop_css_test.exs (new, 68 lines) |

## What Was Built

### Task 1 — Layout tokens + inert utilities + .cl-table-scroll

Added to `priv/static/cairnloop.css`:

**Three layout tokens** in `:root` near the control-sizing block (D-09/UIC-05):
- `--cl-content-max: 1200px` — matches existing `.cl-main` max-width; drives `.cl-page--wide`
- `--cl-rail-width: 352px` — matches existing `.evidence-rail` width; drives `.cl-page--reading`
- `--cl-page-gutter: var(--cl-space-5)` — 16px inner padding for `cl_page` shell

**Three inert utility escape hatches** adjacent to `.cl-row`/`.cl-stack` family (D-10/UIC-05):
- `.cl-gap-2 { gap: var(--cl-space-2); }`
- `.cl-align-center { align-items: center; }`
- `.cl-justify-between { justify-content: space-between; }`

**Accessible table scroll wrapper** (D-11/UIC-05):
- `.cl-table-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; }`
- `.cl-table-scroll:focus-visible { box-shadow: var(--cl-focus-ring); border-radius: var(--cl-radius-xs); }` — mirrors `.cl-focusable:focus-visible` convention

### Task 2 — Primitive visual CSS

Added a new `PRIMITIVE COMPONENTS` section at the end of `cairnloop.css`:

**`.cl-page` family (UIC-01/D-08):** `.cl-page--wide` references `var(--cl-content-max)`; `.cl-page--reading` references `var(--cl-rail-width)`; both use `var(--cl-page-gutter)`. Subparts: `.cl-page__header`, `.cl-page__title` (28px/600), `.cl-page__subtitle` (body/muted), `.cl-page__subnav`, `.cl-page__body`.

**`.cl-hero` family (UIC-02/D-02):** `.cl-hero__count` at Fraunces 48px / `var(--cl-primary)` (copper) — ~2-3x the visual weight of `.cl-stat__count` at 32px. `.cl-hero__count--calm` switches to `var(--cl-success)`. Subparts: `.cl-hero__job` (18px/600), `.cl-hero__detail` (13px/muted), `.cl-hero__cta`.

**`.cl-fact-list` family (UIC-04/D-05):** Dedicated CSS (not scoped under `.cl-details`). `.cl-fact-list__label` at 12px/500/muted; `.cl-fact-list__value` at 13px/400/text with `margin: 0`.

**`.cl-source-card` family (UIC-04/D-06):** Base surface + six variant triplets matching chip shape: `.cl-source-card--{success,info,warning,danger,ai,neutral}` each with `background: var(--cl-{v}-surface); border-color: var(--cl-{v}-border); color: var(--cl-{v}-text)`. Subparts: `.cl-source-card__header`, `.cl-source-card__icon` (16px), `.cl-source-card__body` (13px/muted), `.cl-source-card__meta` (12px/muted).

**`.cl-switch` family (UIC-04/D-04):** `.cl-switch` with `min-height: 44px; min-width: 44px` (preemptive RESP-02 tap target). `.cl-switch:disabled` mirrors `.cl-button:disabled` (`opacity: 0.5; cursor: not-allowed`). `.cl-switch__track` uses `[aria-checked="true"]` attribute selector to drive `var(--cl-primary)` fill — never color alone (brand §7.5). `.cl-switch__thumb` transitions `translateX(20px)` with `var(--cl-dur-instant)` ease-out. `.cl-switch__label` at 13px/500/text.

### Task 3 — CSS presence test

Created `test/cairnloop/web/cairnloop_css_test.exs` with 11 headless assertions organized in 4 describes:
- `layout tokens` — asserts `--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter`
- `inert utility escape hatches` — asserts `.cl-gap-2`, `.cl-align-center`, `.cl-justify-between`
- `accessible table scroll wrapper` — asserts `.cl-table-scroll`
- `primitive visual CSS classes` — asserts `.cl-hero__count`, `.cl-fact-list`, `.cl-source-card--success`, `.cl-switch__track`

Uses `File.read!/1` from `File.cwd!()` — pure file-content test, no DB, no Repo, runs in the fast default headless suite.

## Verification Results

- `mix compile --warnings-as-errors` — exit 0, no warnings
- `mix test test/cairnloop/web/cairnloop_css_test.exs` — 11 tests, 0 failures
- `mix test test/cairnloop/web/brand_token_gate_test.exs` — 1 test, 0 failures
- Hex scan on new primitive CSS section — CLEAN (zero `#rrggbb` in any added line)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All CSS classes are fully defined; no placeholder values or hardcoded empty outputs.

## Threat Flags

No new threat surface introduced. This plan adds static CSS text and a File.read! test only. No endpoints, no auth paths, no schema changes. Existing threat model (T-37-01 style drift mitigated by token-purity, T-37-02 file-read accepted) covers the full surface.

## Self-Check

### Created files exist:
- `test/cairnloop/web/cairnloop_css_test.exs` — FOUND (confirmed by successful test run)
- `priv/static/cairnloop.css` — FOUND (existing file extended)

### Commits exist:
- af45388 — FOUND
- ffca08e — FOUND
- 4af11f9 — FOUND

## Self-Check: PASSED
