---
phase: 31-golden-path-jtbd-smoke-test
status: reviewed
reviewed_at: 2026-05-28
reviewer: gsd-code-review
findings_count: 6
severity_counts:
  high: 1
  medium: 2
  low: 3
---

# Code Review — Phase 31: Golden Path JTBD Smoke Test

## Scope

Files changed in this phase:
- `test/integration/golden_path_test.exs` (new — 340 lines)
- `test/integration/widget_channel_test.exs` (new — 96 lines)

## Findings

```json
[
  {
    "file": "test/integration/golden_path_test.exs",
    "line": 338,
    "summary": "Stage 9 system_outbound assertion is tautological — satisfied by Stage 8's message, not the bulk fan-out",
    "failure_scenario": "Stage 8 (trigger_recovery_follow_up) already created ≥1 :system_outbound message for this conversation. Stage 9's `assert length(system_outbound_messages) >= 1` passes trivially from Stage 8's row even if confirm_bulk_send's bulk fan-out creates ZERO new messages. A broken Outbound.bulk_trigger/2 that inserts the BulkEnvelope but fails to fan out per-recipient messages goes completely undetected."
  },
  {
    "file": "test/integration/widget_channel_test.exs",
    "line": 94,
    "summary": "Inbox HTML assertion `html =~ to_string(conversation_id)` is too broad — passes if the integer id appears anywhere in the DOM",
    "failure_scenario": "The conversation_id integer (e.g. 42) will appear in link hrefs (/governance/42, /inbox/42), data-* attributes, hidden inputs, and debug output. If InboxLive fails to add the conversation to the VISIBLE inbox list but still renders it in a non-visible context (e.g. a hidden pre-fetch row, a stylesheet href, or a JS variable), the assertion passes while the operator-facing feature is broken."
  },
  {
    "file": "test/integration/widget_channel_test.exs",
    "line": 66,
    "summary": "Direct ProcessMessage.perform call hand-constructs args that may not match what WidgetChannel.handle_in actually enqueues",
    "failure_scenario": "The test asserts the channel reply is :ok (line 66), then manually constructs the Oban job args from scratch (lines 74-80). If WidgetChannel.handle_in changes how it packs args — e.g. adds a `host_user_id` field, changes key names, or stringifies the conversation_id — the manual perform call will succeed because it still matches ProcessMessage's pattern, but the test never verified the ACTUAL job args the channel enqueued. The channel's arg-packing contract is entirely untested."
  },
  {
    "file": "test/integration/golden_path_test.exs",
    "line": 193,
    "summary": "Stage 3 fires activate_result but not open_active_result — citation-chip navigation path is untested",
    "failure_scenario": "The plan (31-01-PLAN.md) specifies firing both activate_result and open_active_result to simulate the citation-chip click. The test omits open_active_result (the comment on line 193 explicitly notes this). A regression in set_active_result → ensure_preview_state → open_active_result (the internal preview-load chain) would not be caught. Currently only the result title appearing in HTML is verified, not that the preview pane loads or that the citation chip is usable."
  },
  {
    "file": "test/integration/golden_path_test.exs",
    "line": 308,
    "summary": "Two concurrent InboxLive mounts are alive simultaneously — doubles PubSub subscriptions for the duration of Stage 9",
    "failure_scenario": "Stage 2 (line 152) mounts inbox_view and never closes it. Stage 9 (line 308) mounts a second InboxLive. Both processes remain alive and both subscribe to 'conversations' PubSub. Any broadcast between Stages 2 and 9 (including the multiple :conversations_changed events from Stages 4-8) is handled by BOTH instances. While this doesn't cause a test failure currently, it silently doubles process overhead and means the Stage-2 inbox_view accumulates many handle_info reloads, making the test harder to reason about and potentially flaky under load."
  },
  {
    "file": "test/integration/golden_path_test.exs",
    "line": 100,
    "summary": "on_exit env restore repeats an identical nil-check pattern three times — error-prone when adding future env keys",
    "failure_scenario": "The on_exit callback has three identical `if is_nil(prior_x) do delete_env else put_env end` blocks (lines 100-118). When a future stage needs a fourth env key (e.g. :feature_flags), the pattern must be copied again. Developers copying the block have repeatedly introduced subtle bugs (wrong key name, wrong prior variable). A helper `restore_env(key, prior_value)` would eliminate all three instances."
  }
]
```

## Refuted Candidates (for traceability)

- **Integer conversation_id in ProcessMessage** — REFUTED. ProcessMessage passes the value directly to `Chat.ingest_widget_message/2` with no type guard; Ecto's cast handles both integer and string foreign keys.
- **send_update timing before render_keydown** — REFUTED. GenServer.call FIFO ordering guarantees InboxLive processes the send_update message before responding to render_keydown.
- **InboxLive render stale after PubSub** — REFUTED. `render/1` uses `GenServer.call`, so InboxLive processes the queued `{:conversations_changed}` handle_info before it responds to the render call.
- **InboxLive bulk select on resolved conversation** — REFUTED. The `toggle_select` checkbox is rendered specifically FOR `:resolved` conversations (line 140 of inbox_live.ex), so the element exists in Stage 9.

## Summary

One confirmed correctness gap (Stage 9 assertion is tautological), two plausible coverage gaps (inbox HTML too broad; direct perform bypasses channel arg verification), one coverage miss (open_active_result not fired), one efficiency/brittleness issue (dual concurrent inbox mounts), and one simplification opportunity (repetitive on_exit pattern).

The most actionable fix is Stage 9's system_outbound assertion — change `>= 1` to `>= outbound_after + 1` (where `outbound_after` is the count after Stage 8's trigger) to specifically prove bulk fan-out created new rows.
