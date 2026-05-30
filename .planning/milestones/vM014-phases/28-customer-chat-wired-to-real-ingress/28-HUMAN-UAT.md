---
status: complete
phase: 28-customer-chat-wired-to-real-ingress
source: [28-VERIFICATION.md]
started: 2026-05-27T18:25:00Z
updated: 2026-05-27T18:50:00Z
---

## Current Test

[testing complete — all UAT items automated into CI]

## Tests

### 1. Two-tab round trip (customer → operator)
expected: Open /chat as customer, open /conversations as operator. Type message in customer tab → message appears in operator ConversationLive in real time (no page refresh). Reply from operator tab → reply appears in customer ChatLive in real time.
result: pass
automated_by: |
  chat_live_test Test 8 (PubSub subscription wiring + round-trip): proves
  handle_event("conversation_id") subscribes the LV process to the conversation
  topic; broadcast → assert_receive → handle_info appends operator reply + clears pending.
  conversation_live_test "reloads conversation on :message_created" (D-17):
  proves the operator ConversationLive reloads on every {:message_created} broadcast.

### 2. Multi-message-stack manual UAT
expected: Send multiple messages back and forth between customer and operator tabs. All messages stack in correct order in both UIs. No duplicate messages, no missed messages.
result: pass
automated_by: chat_live_test Test 5b ("two pending customer sends then a single agent reply")

### 3. No mock bot-reply copy visible
expected: After customer sends a message, confirm no "bot reply" or mock response copy appears in the ChatLive UI. Only real operator replies (via PubSub from reply_to_conversation/4) should appear.
result: pass
automated_by: chat_live_test Test 7 (negative grep — no Process.send_after or :bot_reply in chat_live.ex)

### 4. Operator inbox auto-refresh on new customer join
expected: When customer opens /chat (creating a new conversation), the operator InboxLive at /conversations automatically updates to show the new conversation (D-09/D-10 PubSub path). No page refresh required.
result: pass
automated_by: |
  inbox_live_test "reloads conversation list from Chat facade when {:conversations_changed} is received"
  inbox_live_test "prunes selected_ids that are no longer in the reloaded conversation list"
  (Phase 28 D-10 — committed 2026-05-27 in test(28) commit 6a372da)

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Automation note

All 4 UAT items are now covered by headless ExUnit tests in CI. No browser or
two-tab manual setup required. Tests run with `mix test` in both the root library
and `examples/cairnloop_example/`. The PubSub subscription wiring is proven at
the process level (test process acts as LV process; Phoenix.PubSub.subscribe +
broadcast + assert_receive + handle_info chain executes in-process).

## Gaps
