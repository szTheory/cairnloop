---
phase: 44-motion
plan: 04
subsystem: ui
tags: [motion, liveview, inbox, rail, reduced-motion]
requirements_completed: [MOTION-01, MOTION-02]
completed: 2026-06-26
---

# Phase 44 / Plan 04: Inbox, rail, and state motion wiring

Wired the remaining LiveView attach points for the Phase 44 motion layer.

## What Changed

- Added `cl-list-stagger` to the inbox `<ul>` while preserving the existing list structure and bulk-bar clearance class.
- Added `phx-mounted={JS.transition("cl-motion-reveal", time: 260)}` to the real `.evidence-rail` container, leaving the RailDensity hook and id intact.
- Added `cl-motion-state` to outbound message status chips, preserving class order so existing `"message-status-chip status-*"` render assertions stay valid.

## Decisions

- Interpreted the "rail/drawer reveal" as a one-shot `.evidence-rail` mount reveal because no `.cl-drawer` surface exists in this implementation.
- Accepted the bounded `nth-child` inbox stagger instead of converting the list to streams; it may replay on full navigation back, but not on simple attribute patches, and remains limited to the first five rows.
- Confirmed status chips already render distinct visible text: `Pending`, `Sent`, `Failed`; motion supplements text and color, never replaces them.
- Kept the reply-send path motion-class-free.

## Verification

- `mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/responsive_markup_test.exs` - 161 tests, 0 failures.
- `cd examples/cairnloop_example && mix test.e2e test/e2e/motion_test.exs` - 2 tests, 0 failures.
