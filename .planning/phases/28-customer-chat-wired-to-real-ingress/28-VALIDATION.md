---
phase: 28
slug: customer-chat-wired-to-real-ingress
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-27
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --warnings-as-errors` |
| **Full suite command** | `mix compile --warnings-as-errors && mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --warnings-as-errors`
- **After every plan wave:** Run `mix compile --warnings-as-errors && mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-W0-01 | W0 | 0 | CHAT-02 | — | Cairnloop.PubSub starts in example supervisor | unit | `mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 28-W0-02 | W0 | 0 | CHAT-02 | — | ProcessMessage email-channel branch preserved | unit | `mix test test/cairnloop/automation/process_message_test.exs` | ❌ W0 | ⬜ pending |
| 28-01-01 | 01 | 1 | CHAT-02 | — | Chat.create_customer_conversation/1 returns {:ok, conversation} | unit | `mix test test/cairnloop/chat_test.exs` | ❌ W0 | ⬜ pending |
| 28-01-02 | 01 | 1 | CHAT-02 | — | Chat.ingest_widget_message/2 broadcasts on conversation topic | unit | `mix test test/cairnloop/chat_test.exs` | ❌ W0 | ⬜ pending |
| 28-01-03 | 01 | 1 | CHAT-02 | — | WidgetChannel join/handle_in pushes via Chat facade | unit | `mix test test/cairnloop/channels/widget_channel_test.exs` | ❌ W0 | ⬜ pending |
| 28-01-04 | 01 | 1 | CHAT-02 | — | reply_to_conversation/4 broadcasts {:message_created, id} | unit | `mix test test/cairnloop/chat_test.exs` | ❌ W0 | ⬜ pending |
| 28-02-01 | 02 | 2 | CHAT-01 | — | Endpoint mounts WidgetSocket at /socket/widget | integration | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 28-02-02 | 02 | 2 | CHAT-02 | — | ChatLive sends message via channel push, no Process.send_after | unit | `mix test test/cairnloop_example_web/live/chat_live_test.exs` | ❌ W0 | ⬜ pending |
| 28-03-01 | 03 | 3 | CHAT-03 | — | README two-tab demo section present with exact commands | manual | inspect `examples/cairnloop_example/README.md` | ✅ | ⬜ pending |
| 28-03-02 | 03 | 3 | CHAT-02 | — | Full suite green, no warnings | suite | `mix compile --warnings-as-errors && mix test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/chat_test.exs` — stubs for Chat.create_customer_conversation/1, Chat.ingest_widget_message/2, and reply_to_conversation/4 broadcast
- [ ] `test/cairnloop/channels/widget_channel_test.exs` — stubs for WidgetChannel join + handle_in
- [ ] `test/cairnloop_example_web/live/chat_live_test.exs` — stub for ChatLive send-message flow (no Process.send_after)
- [ ] `test/cairnloop/automation/process_message_test.exs` — email-channel branch preserved

*Note: ExUnit is already installed. Wave 0 only needs test stubs — no new framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Two-tab round trip (customer sends, operator sees, operator replies, customer sees) | CHAT-02 | Requires two browser tabs and live Phoenix socket | Open `/chat` in Tab 1, `/inbox` in Tab 2; send message from Tab 1; reply from Tab 2; verify message appears in Tab 1 without page reload |
| No mock bot reply appears | CHAT-02 | Runtime channel behavior | Confirm no "Bot reply" message appears after 1 second in customer tab |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
