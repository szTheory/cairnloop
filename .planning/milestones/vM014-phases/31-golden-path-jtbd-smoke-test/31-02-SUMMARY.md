---
phase: 31-golden-path-jtbd-smoke-test
plan: "02"
subsystem: integration-tests
tags: [e2e, channel-test, widget-channel, inbox-live, pubsub]
dependency_graph:
  requires:
    - "28-customer-chat-wired-to-real-ingress (WidgetChannel + ProcessMessage + Chat.ingest_widget_message/2)"
    - "29-brand-token-css-extraction (ConnCase patterns, test infrastructure)"
  provides:
    - "test/integration/widget_channel_test.exs (E2E-02)"
  affects: []
tech_stack:
  added: []
  patterns:
    - "Phoenix.ChannelTest.socket/3 bypasses test endpoint socket mount (Pitfall 7)"
    - "ConnCase + inline import Phoenix.ChannelTest for mixed LiveView + Channel tests (D-05)"
    - "ProcessMessage.perform/1 direct call — never Oban.drain_queue (D-09)"
    - "async: false shared sandbox — all spawned PIDs share sandbox automatically (D-07)"
key_files:
  created:
    - test/integration/widget_channel_test.exs
  modified: []
decisions:
  - "D-05: import Phoenix.ChannelTest inline — ConnCase does not include it"
  - "D-07: async: false so DataCase.setup_sandbox sets shared: true for all spawned PIDs"
  - "D-09: ProcessMessage.perform/1 called directly with Oban.Job struct — never drain_queue"
  - "Pitfall 7: socket/3 helper used directly — test endpoint has no WidgetSocket mount"
  - "Pitfall 6: @endpoint from ConnCase inherited — not redeclared in test module"
  - "Dual-proof: both assert_receive {:conversations_changed} and render(inbox_view) =~ id"
metrics:
  duration: "3 minutes"
  completed_date: "2026-05-28"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 1
---

# Phase 31 Plan 02: Widget Channel Test Summary

WidgetChannelTest integration test covering the customer-ingress JTBD round trip via `Phoenix.ChannelTest` + `Phoenix.LiveViewTest` — no browser driver, no new dependency.

## What Was Built

Single file: `test/integration/widget_channel_test.exs` — `Cairnloop.Integration.WidgetChannelTest` module using `ConnCase` (async: false), inline `import Phoenix.ChannelTest`, and a single test that exercises:

1. Mount `InboxLive` at `/inbox` (connects and subscribes to `"conversations"` PubSub topic)
2. Subscribe test process to `"conversations"` for direct assert_receive proof
3. `socket/3` + `subscribe_and_join/3` → `WidgetChannel` on `"widget:lobby"` with token `"demo_customer"` — asserts `%{conversation_id: conversation_id}` join reply
4. `push/3` `"new_message"` → `assert_reply ref, :ok`
5. `ProcessMessage.perform/1` inline with `%Oban.Job{args: %{"channel"/"conversation_id"/"content"}}` — asserts `:ok`
6. `assert_receive {:conversations_changed}` — proves `Chat.ingest_widget_message/2` broadcast fired
7. `render(inbox_view) =~ to_string(conversation_id)` — proves `InboxLive` re-rendered with the new conversation

Closes **E2E-02**. Contributes to **E2E-03** (lives in `test/integration/`, runs under `mix test.integration`).

## Commits

| Task | Description | Hash | Files |
|------|-------------|------|-------|
| Task 1 | Module skeleton, imports, setup block | 561de90 | test/integration/widget_channel_test.exs |
| Task 2 | Test body — join/push/process/operator-delivery | 561cc59 | test/integration/widget_channel_test.exs |

## Acceptance Criteria Verification

- [x] File `test/integration/widget_channel_test.exs` exists — 89 lines (min: 50)
- [x] `defmodule Cairnloop.Integration.WidgetChannelTest do` as first defmodule
- [x] `use Cairnloop.ConnCase, async: false` and `import Phoenix.ChannelTest` present
- [x] `grep -c "REPO-UNAVAILABLE"` returns 1
- [x] `grep -c "Oban.drain_queue"` returns 0
- [x] No `socket "/widget"` mount in `test/support/endpoint.ex` (no modification)
- [x] `subscribe_and_join(Cairnloop.Channels.WidgetChannel, "widget:lobby", %{})` present
- [x] `push(` with `"new_message"` and `assert_reply ref, :ok` present
- [x] `ProcessMessage.perform(%Oban.Job{args: %{"channel" => "widget", "conversation_id" => conversation_id, "content" => ...}})` and asserts `:ok` present
- [x] `live(conn, "/inbox")` and `render(inbox_view)` assertion proving operator-side delivery present
- [x] No flash assertion; no `Oban.drain_queue`
- [x] `mix compile --warnings-as-errors` exits 0

## Test Execution Status

`mix test.integration test/integration/widget_channel_test.exs` could NOT be run in this workspace due to the local environment missing pgvector (`vector.control` extension missing on the local PostgreSQL@14 installation). This matches the documented CLAUDE.md caveat: "Cairnloop.Repo may be unavailable in this workspace." The test file is tagged `# REPO-UNAVAILABLE` and is structurally correct per compilation verification and API alignment with RESEARCH.md verified contracts. CI with dockerized Postgres + pgvector is the correct validation environment.

## Deviations from Plan

None — plan executed exactly as written.

All pitfalls from RESEARCH.md were honored:
- Pitfall 6: `@endpoint` inherited from ConnCase (line 14 of conn_case.ex); not redeclared
- Pitfall 7: `socket/3` bypasses test endpoint — no WidgetSocket mount needed on test endpoint
- D-05: `import Phoenix.ChannelTest` added inline
- D-07: `async: false` enables `shared: true` sandbox automatically
- D-09: `ProcessMessage.perform/1` direct call — no `Oban.drain_queue`

## Known Stubs

None — the test file exercises real production code paths (WidgetChannel, ProcessMessage, Chat.ingest_widget_message/2, InboxLive). No stub modules required for this test.

## Threat Flags

None — test-only file; no new production code paths, no new network endpoints or auth paths.

## Self-Check: PASSED

- [x] `test/integration/widget_channel_test.exs` exists at correct path
- [x] Commit 561de90 exists in worktree log
- [x] Commit 561cc59 exists in worktree log
- [x] No modifications to STATE.md, ROADMAP.md (orchestrator owns those)
- [x] No modifications to mix.exs or test/support/endpoint.ex
