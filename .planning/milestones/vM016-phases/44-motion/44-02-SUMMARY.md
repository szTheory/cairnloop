---
phase: 44-motion
plan: 02
subsystem: ui
tags: [motion, css, tokens, reduced-motion]
requirements_completed: [MOTION-01, MOTION-02]
completed: 2026-06-26
---

# Phase 44 / Plan 02: Motion CSS foundation

Shipped the shared CSS motion primitives in `priv/static/cairnloop.css`.

## What Changed

- Added keyframes: `cl-enter-up`, `cl-reveal-x`, `cl-toast-enter`, `cl-toast-exit`.
- Added utility classes: `.cl-motion-enter`, `.cl-motion-reveal`, `.cl-motion-state`, `.cl-list-stagger`, `.cl-toast-enter`, `.cl-toast-exit`.
- Added the branded `.cl-toast` surface and child styles.
- Extended reduced-motion coverage to `.cl-toast`, because the example layout renders flash notices outside `.cl-app`.

## Decisions

- Kept the example app as an importer of canonical library CSS instead of duplicating motion CSS. This avoids a second motion source of truth.
- Preserved the existing reduced-motion model: movement is removed globally and `.cl-motion-state` survives as the meaning-bearing 120ms cross-fade.
- Did not add count transitions to `.cl-hero__count` or `.cl-stat__count`.

## Verification

- `mix test test/cairnloop/web/motion_css_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/brand_token_gate_test.exs` - 42 tests, 0 failures.
- `mix compile --warnings-as-errors` - clean.
