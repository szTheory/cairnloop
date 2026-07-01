---
phase: 44-motion
plan: 03
subsystem: ui
tags: [motion, components, flash, liveview]
requirements_completed: [MOTION-01, MOTION-02]
completed: 2026-06-26
---

# Phase 44 / Plan 03: Hero entrance and reusable flash toast

Wired the component-layer motion surfaces.

## What Changed

- Added `alias Phoenix.LiveView.JS` to `Cairnloop.Web.Components`.
- Added a one-shot `phx-mounted={JS.transition("cl-motion-enter", time: 140)}` entrance to `cl_hero/1`'s `.cl-hero__count`.
- Added reusable `cl_flash/1`, rendering a token-driven `.cl-toast` with distinct info/error icons, escaped message content, enter/exit transitions, and `lv:clear-flash` dismiss wiring.
- Updated the example shell `flash_group/1` to use `cl_flash/1` for normal info/error flashes while leaving Phoenix reconnect flashes untouched.

## Decisions

- Elevated toast treatment into the library component layer, not the example app, so host apps can reuse the branded operator flash surface.
- Kept reconnection flashes on the generated example core component because they carry existing disconnected/connected behavior and are not ordinary user-action flashes.

## Verification

- `mix test test/cairnloop/web/motion_css_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/brand_token_gate_test.exs` - 42 tests, 0 failures.
- `cd examples/cairnloop_example && mix compile --warnings-as-errors` - clean.
