---
phase: 37-component-primitives
verified: 2026-06-03T20:05:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  note: "Initial verification. A code review (37-REVIEW.md) found 0 Critical / 3 Warning / 4 Info; all 3 Warnings resolved in commits 66e59bc + 6ba7fa1 (confirmed against codebase)."
---

# Phase 37: Component Primitives Verification Report

**Phase Goal:** The component library has all primitives required by the iteration — `cl_page`, `cl_hero`/`cl_stat` (de-polymorphized), `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch` — plus the layout tokens, inert-utility CSS definitions, and `.cl-table` scroll-wrappers that blocked earlier screens.
**Verified:** 2026-06-03T20:05:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | An operator screen can render a full page via `<.cl_page title="…">` with breadcrumb, actions slot, and both `:wide`/`:reading` width variants producing visibly different inner framing. | ✓ VERIFIED | `cl_page/1` at components.ex:329-346: single enum `width` attr (values `~w(wide reading)`, default "wide"), `:breadcrumb`/`:actions`/`:subnav` slots all guarded with `:if`, required `title` rendered as `<h1 class="cl-page__title">`. CSS: `.cl-page--wide { max-width: var(--cl-content-max) /*1200px*/ }` vs `.cl-page--reading { max-width: var(--cl-rail-width) /*352px*/ }` (cairnloop.css:689-690) — visibly different framing (1200px vs 352px). Tests assert both classes render (components_test.exs:147,162). UIC-01. |
| 2 | `cl_stat` accepts only `count :integer` (de-polymorphized); `cl_hero` renders ~2–3× the weight of a standard stat with a `:detail` slot. | ✓ VERIFIED | `cl_stat` declares `attr(:count, :integer, required: true)` (components.ex:128) — `:any` gone. `cl_hero/1` (components.ex:167-179) is a SEPARATE component (no `variant="hero"` path), with `slot(:detail)` rendered at line 172. CSS: `.cl-hero__count` = 48px Fraunces display copper (cairnloop.css:718-721) vs `.cl-stat__count` = 32px (line 420); 48px display weight is the ~2–3× visual-weight target. Tests assert `cl-hero__count` and `cl-hero__count--calm` (components_test.exs:211,226). UIC-02. |
| 3 | `<.cl_disclosure>` wraps native `<details>`/`<summary>` with NO server assigns for open state; a LiveView PubSub reload does not snap shut. | ✓ VERIFIED | `cl_disclosure/1` (components.ex:198-204): `<details class="cl-details cl-disclosure" id={@id} phx-update="ignore" open={@open}>`. `open` is a static-at-mount attr (default false), never bound to a server-toggle assign; no `phx-click`/`JS` in the component. Required stable `id`. Tests assert `phx-update="ignore"`, stable id, open-present when true / absent when false (components_test.exs:260-299). UIC-03. |
| 4 | `cl_fact_list`, `cl_source_card` (with `source_variant`), `cl_status_cell`, and `cl_switch` (role="switch") each render token-only (no inline hex). | ✓ VERIFIED | `cl_fact_list/1` (components.ex:217-226) `<dl class="cl-fact-list">` label/value rows. `cl_source_card/1` (components.ex:274-289) `source_variant` enum → `.cl-source-card--{variant}` + icon from `status_icon/1`. `cl_status_cell/1` (components.ex:305-310) delegates to `<.cl_chip>` (no `action_tone` — confirmed absent). `cl_switch/1` (components.ex:247-253) `<button role="switch" aria-checked={to_string(@checked)}>` with always-visible label + `:rest` allowlist incl. `phx-value-*`. All primitive CSS blocks (cairnloop.css:685-805) are token-only — zero hex confirmed by grep. Every render test asserts `refute html =~ ~r/#[0-9a-fA-F]{3,6}/`. UIC-04. |
| 5 | `mix compile --warnings-as-errors` passes; `cl-gap-2`/`cl-align-center`/`cl-justify-between` defined; every `.cl-table` has an overflow-x:auto wrapper with role="region". | ✓ VERIFIED | `mix compile --warnings-as-errors` exits 0 (run by verifier). Utilities at cairnloop.css:436-438. Layout tokens at 138-140. `.cl-table-scroll { overflow-x: auto; ... }` at 448-449. All 4 `.cl-table` instances (audit_log_live:130, kb index:79, suggestion_review:221, settings:247) sit inside a `<div :if={...} class="cl-table-scroll" role="region" tabindex="0" aria-label="…">` wrapper with call-site-specific labels; settings preserves `cl-mb-7`. UIC-05. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/web/components.ex` | 8 primitives + cl_stat narrowing | ✓ VERIFIED | cl_page, cl_hero, cl_disclosure, cl_fact_list, cl_source_card, cl_status_cell, cl_switch all `def`'d; cl_stat `count :integer`. Substantive, token-only, no `raw/1` on caller input. |
| `priv/static/cairnloop.css` | tokens, utilities, table-scroll, primitive CSS | ✓ VERIFIED | 3 layout tokens, 3 inert utilities, `.cl-table-scroll` (+focus ring), all primitive blocks (lines 685-805) token-only, zero hex. |
| `test/cairnloop/web/components_test.exs` | render tests for all primitives | ✓ VERIFIED | 31 tests; structural assertions for each primitive (classes, ARIA, slots) + token-purity refute on every test. |
| `test/cairnloop/web/cairnloop_css_test.exs` | CSS-presence machine-verification | ✓ VERIFIED | 11 tests asserting tokens/utilities/table-scroll/primitive class literals. |
| 4 LiveViews (audit_log, kb index, suggestion_review, settings) | `.cl-table-scroll` wrappers | ✓ VERIFIED | All 4 wrapped, guard moved to wrapper div (WR-01 fix), `cl-mb-7` preserved on settings table. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| cl_page | `.cl-page--wide`/`.cl-page--reading` | `cl-page--#{@width}` class | ✓ WIRED | Class emitted per enum (components.ex:331); CSS resolves to distinct max-widths. |
| cl_hero | `.cl-hero__count` | copper count numeral | ✓ WIRED | components.ex:171 → CSS 718-721. |
| cl_disclosure | browser-owned open state | `phx-update="ignore"` + stable id | ✓ WIRED | components.ex:200; no server assign owns open. |
| cl_switch | WAI-ARIA switch pattern | `aria-checked={to_string(@checked)}` | ✓ WIRED | components.ex:249 — string, not boolean attr. |
| cl_status_cell | cl_chip | `<.cl_chip>` delegation | ✓ WIRED | components.ex:308 — no re-authored chip markup. |
| 4 LiveView `.cl-table` sites | `.cl-table-scroll` CSS | wrapping div role=region tabindex=0 | ✓ WIRED | grep-confirmed all 4; CSS class exists. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Warnings-clean build | `mix compile --warnings-as-errors` | exit 0 | ✓ PASS |
| Phase-37 tests | `mix test components_test.exs cairnloop_css_test.exs` | 42 tests, 0 failures | ✓ PASS |
| Brand token gate | `mix test brand_token_gate_test.exs` | 1 test, 0 failures | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UIC-01 | 37-02 | `cl_page` shell with slots + width options | ✓ SATISFIED | cl_page/1 + truth 1 |
| UIC-02 | 37-02 | `cl_stat` numeric-only + `cl_hero` primary count | ✓ SATISFIED | cl_stat narrowing + cl_hero + truth 2 |
| UIC-03 | 37-03 | `cl_disclosure` patch-safe native details | ✓ SATISFIED | cl_disclosure/1 + truth 3 |
| UIC-04 | 37-03, 37-04 | fact_list, source_card, status_cell, switch token-pure | ✓ SATISFIED | 4 primitives + truth 4 |
| UIC-05 | 37-01, 37-05 | layout tokens, utilities, table scroll wrappers | ✓ SATISFIED | CSS + 4 wrappers + truth 5 |

All 5 declared requirement IDs (UIC-01..UIC-05) are present in plan frontmatter AND mapped to Phase 37 in REQUIREMENTS.md (lines 103-107). No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX in any phase-37-modified file | — | Clean |

Hex matches found in cairnloop.css lines 430-720 are PRE-EXISTING rules (`.cl-divider`, `.cl-breadcrumb`, `.cl-tabs`, context-field/quick-fix/governed-action families) using `var(--cl-token, #fallback)` forms — not phase-37 primitive lines. The phase-37 primitive blocks (685-805) are bare-token, zero hex.

### Code Review Resolution (37-REVIEW.md)

| Finding | Status | Verification |
|---------|--------|--------------|
| WR-01: empty focusable `.cl-table-scroll` region | ✓ RESOLVED | commit 66e59bc — `:if` guard moved to wrapper div in all 4 LiveViews (confirmed). |
| WR-02: cl_hero drops `inner_block` slot | ✓ RESOLVED | commit 6ba7fa1 — dead `inner_block` removed; `:cta_slot` is the rendered override (components.ex:165,173-176). |
| WR-03: cl_hero moduledoc contradiction | ✓ RESOLVED | commit 6ba7fa1 — moduledoc (components.ex:155-157) now references `:cta_slot` and the `<.link>` fallback. |
| IN-01..IN-04 | Deferred (Info) | API-consistency nits (bracket access, `:class`/`:rest` escape hatches, fact shape doc, scroll-shadow). Non-blocking; deferred per review disposition. |

### Pre-Existing Test Failures (NOT phase-37 gaps)

Confirmed the full-suite failures are unrelated to phase 37:
- `Cairnloop.Workers.OutboundWorkerTest` — file last touched by formatting commit 831dd64, never by phase 37 (known baseline, M005/Phase-25 drift).
- `SettingsLiveTest` "mount/3 stores host_user_id" — order-dependent async global-state flake; passes in isolation. Phase 37's settings_live edit is an additive table-wrap (markup only), not mount logic.

Neither is caused by phase-37 logic.

### Human Verification Required

None. All success criteria are verifiable in the codebase + automated tests. Visual weight (~2–3×) and rendered framing are grounded in concrete CSS values (48px vs 32px; 1200px vs 352px max-width) and do not require human confirmation for goal achievement at the primitive-library level. (Visual adoption polish is downstream P38/P39/P43 scope.)

### Gaps Summary

No gaps. All 8 primitives exist, are substantive, token-pure, and structurally wired; cl_stat is de-polymorphized; layout tokens, inert utilities, and `.cl-table-scroll` wrappers are present across all 4 operator screens. Build is warnings-clean and all 42 phase-37 tests pass. All 3 code-review warnings were resolved and confirmed against the codebase. Requirement IDs UIC-01..UIC-05 are fully accounted for.

---

_Verified: 2026-06-03T20:05:00Z_
_Verifier: Claude (gsd-verifier)_
