---
phase: 28-customer-chat-wired-to-real-ingress
plan: "01"
subsystem: chat
tags: [elixir, phoenix, liveview, pubsub, chat-facade, ecto]

# Dependency graph
requires:
  - phase: 27-realistic-demo-fixtures
    provides: seeded conversation/message data that chat facade reads from
provides:
  - Chat.create_customer_conversation/1 — single-row conversation insert with PubSub broadcast
  - Chat.ingest_widget_message/2 — :user-role message insert with two PubSub broadcasts
  - Chat.reply_to_conversation/4 OQ-1 additive broadcast — {:message_created} on conversation topic
  - Chat.broadcast_safely/2 — defensive try/rescue PubSub helper
  - ConversationLive handle_info({:message_created, _}) — D-17 operator view refresh
  - InboxLive PubSub subscribe on "conversations" + handle_info({:conversations_changed}) — D-09/D-10
  - Example app Cairnloop.PubSub registry in supervisor — Pitfall 1 closed
affects:
  - 28-02 (WidgetChannel calls Chat.ingest_widget_message/2 — this plan provides the function)
  - 28-03 (ChatLive subscribes to conversation topic — this plan provides the broadcasts)
  - 31-golden-path-e2e (integration test exercises this data path end-to-end)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "broadcast_safely/2: defensive try/rescue PubSub broadcast — prevents missing registry from corrupting committed :ok branch (mirrors tool_execution_worker.ex:580-588)"
    - "OQ-1 sealed additive broadcast: case-as-side-effecting-statement between result= and {result,meta} — {result,meta} MUST remain Telemetry.span lambda trailing expression"
    - "InboxLive handle_info: reload via Chat.list_conversations/0 + prune via prune_selected_ids/2 after {:conversations_changed}"

key-files:
  created: []
  modified:
    - examples/cairnloop_example/lib/cairnloop_example/application.ex
    - lib/cairnloop/chat.ex
    - lib/cairnloop/web/conversation_live.ex
    - lib/cairnloop/web/inbox_live.ex
    - test/cairnloop/chat_test.exs

key-decisions:
  - "broadcast_safely/2 uses try/rescue (not a case match) so a missing Cairnloop.PubSub registry never propagates back into a committed :ok branch — consistent with tool_execution_worker.ex defensive variant"
  - "OQ-1 broadcast inserted as a standalone side-effecting statement before {result, meta} inside Telemetry.span lambda — preserves sealed reply_to_conversation/4 contract; locked by Test 3 return-shape guard"
  - "ingest_widget_message/2 does NOT call reply_to_conversation/4 — avoids triggering DraftWorker for raw customer ingress (D-06 explicit prohibition)"

patterns-established:
  - "broadcast_safely/2 pattern: all new Phase 28 PubSub emit points route through this helper"
  - "handle_info({:conversations_changed}) always calls prune_selected_ids/2 before assign — keeps @selected_ids consistent with rendered list"

requirements-completed: [CHAT-02]

# Metrics
duration: 35min
completed: 2026-05-27
---

# Phase 28 Plan 01: Customer Chat Wired to Real Ingress — Data Tier Summary

**Cairnloop.PubSub registered in example app supervisor + two new Chat facade functions (create_customer_conversation/1, ingest_widget_message/2) + additive OQ-1 broadcast inside sealed reply_to_conversation/4 + ConversationLive D-17 and InboxLive D-09/D-10 PubSub wiring + 9 new headless tests**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-05-27T17:25:00Z
- **Completed:** 2026-05-27T17:35:30Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Closed Pitfall 1: `examples/cairnloop_example/application.ex` now starts `{Phoenix.PubSub, name: Cairnloop.PubSub}` adjacent to the example PubSub — library broadcasts no longer crash with "unknown registry: Cairnloop.PubSub"
- Shipped `Chat.create_customer_conversation/1` (D-05) and `Chat.ingest_widget_message/2` (D-06) with defensive post-commit broadcasts via `broadcast_safely/2`
- Added OQ-1 additive broadcast inside sealed `reply_to_conversation/4` — `{:message_created, msg_id}` fires post-commit on the conversation topic; `{result, meta}` remains the Telemetry.span lambda trailing expression (locked by Test 3 return-shape guard)
- Wired `ConversationLive` D-17: new `handle_info({:message_created, _message_id}, socket)` clause mirrors existing `:draft_created`/`:tool_executed` pattern
- Wired `InboxLive` D-09/D-10: real `Phoenix.PubSub.subscribe` in `mount/3` (replacing dead WR-02 comment block) + `handle_info({:conversations_changed}, socket)` that reloads + prunes selected_ids
- 9 new headless tests covering D-05, D-06, OQ-1 broadcast, and the return-shape invariant guard — all green

## Task Commits

1. **Task 1: Pitfall 1 fix + ConversationLive D-17** - `0566d56` (feat)
2. **Task 2: Chat facade + OQ-1 broadcast + headless tests** - `a176e0c` (feat)
3. **Task 3: InboxLive PubSub subscribe + handle_info** - `a6a1998` (feat)

**Plan metadata:** (docs commit — created below)

## Files Created/Modified
- `examples/cairnloop_example/lib/cairnloop_example/application.ex` - Added `{Phoenix.PubSub, name: Cairnloop.PubSub}` after CairnloopExample.PubSub; closes Pitfall 1
- `lib/cairnloop/chat.ex` - Added `create_customer_conversation/1`, `ingest_widget_message/2`, `broadcast_safely/2`; OQ-1 additive broadcast inside `reply_to_conversation/4` :ok branch
- `lib/cairnloop/web/conversation_live.ex` - Added `handle_info({:message_created, _message_id}, socket)` clause (D-17); mirrors existing handle_info cluster
- `lib/cairnloop/web/inbox_live.ex` - Replaced dead WR-02 comment with real `Phoenix.PubSub.subscribe` (D-09); added `handle_info({:conversations_changed}, socket)` with reload + prune (D-10)
- `test/cairnloop/chat_test.exs` - MockRepo.insert/1 top-level clause; setup_all starts Cairnloop.PubSub; 9 new tests across 3 describe blocks (D-05, D-06, OQ-1)

## Decisions Made
- `broadcast_safely/2` uses `try/rescue _ -> :ok` (not `{:ok, _} = Phoenix.PubSub.broadcast(...)`) — consistent with `tool_execution_worker.ex:580-588` defensive variant; a missing registry in test/dev never corrupts committed :ok branches
- OQ-1 broadcast is a standalone `case result do ... end` statement (side-effecting statement only), NOT the trailing expression of the Telemetry.span lambda — `{result, meta}` MUST remain last; OQ-1 Test 3 locks this invariant
- `ingest_widget_message/2` uses `repo().insert/1` directly and does NOT call `reply_to_conversation/4` — D-06 explicit prohibition (calling it would trigger DraftWorker for the :user branch, which is wrong for raw customer ingress)

## Deviations from Plan

None — plan executed exactly as written.

**Note on acceptance grep for `ingest_widget_message`:** The plan's negative-check grep `grep -A 25 "def ingest_widget_message" lib/cairnloop/chat.ex | grep -c "reply_to_conversation"` returns `1` rather than `0` because `def reply_to_conversation` (the next function declaration) falls within the 25-line window after `def ingest_widget_message`. The function body itself does NOT call `reply_to_conversation` — confirmed via: `awk '/def ingest_widget_message/,/^  end$/' lib/cairnloop/chat.ex | grep -c "reply_to_conversation"` returns `0`. This is a false positive in the plan criteria.

## Issues Encountered

**Mix test path for worktree:** The plan's verify commands use `cd /Users/jon/projects/cairnloop && mix test`, but in worktree mode the source files are in the worktree (not the main repo). Used `MIX_BUILD_PATH=/Users/jon/projects/cairnloop/_build MIX_DEPS_PATH=/Users/jon/projects/cairnloop/deps mix test` from the worktree directory to use shared build artifacts while testing against worktree source. This is standard worktree behavior — not a regression.

## Test Results

- `mix test test/cairnloop/chat_test.exs --warnings-as-errors`: 19 tests, 0 failures (9 new + 10 existing)
- `mix test test/cairnloop/web/inbox_live_test.exs --warnings-as-errors`: 39 tests, 0 failures
- `mix test --warnings-as-errors` (full suite): 691 tests + 1 doctest, 1 failure (baseline DraftTest M005 drift — pre-existing, not a regression per CLAUDE.md memory)
- `mix compile --warnings-as-errors`: clean in root library
- `mix compile --warnings-as-errors`: clean in `examples/cairnloop_example/`

## Open Items Handed to Plan 02

- `WidgetChannel.handle_in("customer_message", ...)` still calls the old stub logger — Plan 02 will rewrite it to call `Chat.ingest_widget_message/2`
- `WidgetChannel.join/3` does not yet call `Chat.create_customer_conversation/1` — Plan 02 will wire the join path
- `Cairnloop.Web.ChatLive` is not yet wired to subscribe to the conversation PubSub topic — Plan 03 will add the subscription and render loop

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 02 (WidgetChannel + JS hook) has all data-tier prerequisites: `Chat.create_customer_conversation/1`, `Chat.ingest_widget_message/2`, `broadcast_safely/2`, and `Cairnloop.PubSub` registered in the example app supervisor. No blockers.

---
*Phase: 28-customer-chat-wired-to-real-ingress*
*Completed: 2026-05-27*
