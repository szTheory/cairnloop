---
phase: 44-motion
plan: 01
subsystem: ui
tags: [motion, tests, playwright, e2e, css, reduced-motion]
requirements_completed: [MOTION-01, MOTION-02]
completed: 2026-06-26
---

# Phase 44 / Plan 01: Motion guardrails

Created the Phase 44 motion guardrails in the fast ExUnit lane and the gated Playwright lane.

## What Changed

- Added `test/cairnloop/web/motion_css_test.exs`.
- Added `examples/cairnloop_example/test/e2e/motion_test.exs`.
- The fast test pins motion tokens/classes/keyframes, count-tick no-transition, reduced-motion behavior, source wiring, and the example app stylesheet import strategy.
- The E2E verifies rendered computed styles for `.cl-motion-state`, `.cl-list-stagger`, and reduced-motion behavior in a real browser.

## Deviations

- The original plan expected duplicated motion CSS in `examples/cairnloop_example/priv/static/assets/css/app.css`, but the actual app path is `examples/cairnloop_example/assets/css/app.css` and it imports `../../../../priv/static/cairnloop.css`. The guardrail now enforces that import and rejects a forked motion copy, which is the lower-drift implementation.
- The E2E focuses on persistent computed styles and reduced-motion. Ephemeral `phx-mounted` transition classes for hero/rail/toasts are pinned by source tests because LiveView removes transition classes after completion.

## Verification

- `mix test test/cairnloop/web/motion_css_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/brand_token_gate_test.exs` - 42 tests, 0 failures.
- `cd examples/cairnloop_example && mix test.e2e test/e2e/motion_test.exs` - 2 tests, 0 failures.
