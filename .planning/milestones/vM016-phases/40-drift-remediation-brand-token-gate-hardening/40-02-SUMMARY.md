---
phase: 40-drift-remediation-brand-token-gate-hardening
plan: "02"
subsystem: web-ui
tags: [drift-remediation, brand-tokens, search-modal, cl_chip]
dependency_graph:
  requires: []
  provides: [on-palette search modal, chip-based source/trust badges]
  affects: [lib/cairnloop/web/search_modal_component.ex]
tech_stack:
  added: []
  patterns: [cl_chip variant=success|info, token-valued inline style, cl-text-muted class]
key_files:
  created: []
  modified:
    - lib/cairnloop/web/search_modal_component.ex
decisions:
  - "cl_chip over cl_source_card for inline search badges — chip matches the inline-pill silhouette; plan explicitly selected cl_chip (§F gap #4)"
  - "trust badges collapsed onto same chip variant as source badge (success/info), differentiated by label only — faint trust tier was part of dropped glass aesthetic (D-01)"
  - "result_row_style returns token-valued string (var(--cl-*)) — no cl-primary-surface/border token exists; active row uses var(--cl-primary) border + var(--cl-surface-sunken) bg per plan"
  - "Added import Cairnloop.Web.Components — SearchModalComponent had no prior import; needed for <.cl_chip> function component calls"
metrics:
  duration: "~25 minutes"
  completed: "2026-06-04"
  tasks: 2
  files: 1
---

# Phase 40 Plan 02: Search Modal Drift Remediation Summary

On-palette search modal with chip-based source/trust badges: zero off-palette hex/rgba in search_modal_component.ex; rgba badge helpers deleted; result-row styles are token-valued; cl_chip variant=success|info renders source and trust badges.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Snap render-body rgba to solid tokens | 60f0b91 | lib/cairnloop/web/search_modal_component.ex |
| 2 | Replace rgba badge/row helpers with cl_chip variants + token-valued row styles | 6fe4039 | lib/cairnloop/web/search_modal_component.ex |

## What Was Built

**Task 1 — Render-body rgba snapped to solid tokens:**
- Form border `rgba(64,51,43,0.08)` → `var(--cl-border)`
- Empty-state panel `rgba(255,255,255,0.72)` bg → `var(--cl-surface-raised)`; `rgba(47,36,29,0.68)` text → `cl-text-muted` class
- Preview pane `rgba(255,255,255,0.76)` bg → `var(--cl-surface-raised)`; `rgba(64,51,43,0.08)` border → `var(--cl-border)`
- Six basalt text steps in the 0.62–0.76 muted band → `cl-text-muted` class (section count, row snippet, row recency, preview recency, open-action fallback, empty preview prose)
- `rgba(47,36,29,0.84)` (>=0.82 tier) → `var(--cl-text)` inline (preview body blocks)
- Layout-only styles and `color:var(--cl-primary)` / `color:white` keyword left unchanged (already gate-PASS)

**Task 2 — Badge helpers replaced with cl_chip; row styles token-valued:**
- Added `import Cairnloop.Web.Components` to enable `<.cl_chip>` in template
- 4 `source_badge_style` call sites → `<.cl_chip variant={source_chip_variant(...)} label={...} />`
- 4 `trust_badge_style` call sites → `<.cl_chip variant={trust_chip_variant(...)} label={...} />`
- `source_chip_variant/1`: `:knowledge_base` → `"success"`, `:resolved_case` → `"info"`, catch-all → `"neutral"`
- `trust_chip_variant/1`: `:canonical` → `"success"`, `:assistive` → `"info"`, catch-all → `"neutral"`
- `source_badge_style/1` and `trust_badge_style/1` helpers deleted entirely (no dead clauses remain)
- `result_row_style(true)` → `border: 1px solid var(--cl-primary); background: var(--cl-surface-sunken)`
- `result_row_style(false)` → `border: 1px solid var(--cl-border); background: var(--cl-surface-raised)`
- Non-color layout props (width/text-align/padding/border-radius/cursor) preserved in result_row_style

## Verification

- `grep -nE '#[0-9a-fA-F]{3,6}|rgba\(|hsl\(' lib/cairnloop/web/search_modal_component.ex` → 0 matches (CLEAN)
- `grep -c '\.cl_chip variant=' lib/cairnloop/web/search_modal_component.ex` → 4 (>= 2 required)
- `grep -c 'source_badge_style\|trust_badge_style' lib/cairnloop/web/search_modal_component.ex` → 0
- `mix compile --warnings-as-errors` → exit 0 (no unused-function warnings from deleted helpers)
- `mix test test/cairnloop/web/brand_token_gate_test.exs` → 1 test, 0 failures (gate GREEN)
- `git diff priv/static/cairnloop.css` → empty (cairnloop.css untouched, D-01)
- Full `mix test`: 940 tests, 2 pre-existing baseline failures (SettingsLive order-flake + OutboundWorkerTest) — not regressions

## Deviations from Plan

None — plan executed exactly as written.

The plan's recorded decisions were honored:
- cl_chip (not cl_source_card) for inline pills — plan explicitly resolved gap #4
- Trust badges collapsed to same variant as source badge — plan explicitly resolved the faint-tier question
- Token-valued return strings for result_row_style — plan explicitly resolved gap #5

## Known Stubs

None. All call sites wired to real data; no hardcoded empty values or placeholder text in the modified path.

## Threat Flags

No new threat surface. This plan is a render-layer CSS-string migration only: no new network endpoints, auth paths, file access patterns, or schema changes. The `cl_chip` primitive carries icon+text (brand §7.5 never-color-alone preserved).

## Self-Check: PASSED

- `lib/cairnloop/web/search_modal_component.ex` — FOUND (modified)
- Commit `60f0b91` — FOUND (Task 1)
- Commit `6fe4039` — FOUND (Task 2)
- Brand token gate — GREEN
- `mix compile --warnings-as-errors` — exit 0
- `cairnloop.css` unchanged — CONFIRMED
