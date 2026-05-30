# Phase 28: Customer `/chat` Wired to Real Ingress - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 28-customer-chat-wired-to-real-ingress
**Areas discussed:** Conversation lifecycle, ProcessMessage scope, InboxLive real-time awareness

---

## Conversation Lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| A. Create on channel join | `WidgetChannel.join/3` creates Conversation row, pushes conversation_id back via join reply, JS hook relays to ChatLive via `pushEvent`. ProcessMessage only inserts Message. | ✓ |
| C. Client-generated UUID | ChatLive generates UUID on mount, threads through hook join params, ChatLive subscribes immediately — zero timing gap, no orphan risk | |

**User's choice:** Delegated to Claude ("research deeply, one-shot a perfect recommendation, so I don't have to think")
**Notes:** User's profile is `minimal_decisive` — requested full research + single coherent recommendation across all three areas. Advisor subagents spawned in parallel for all three gray areas. Option A selected because UI-SPEC interaction contract step 6 says ProcessMessage "creates a `Cairnloop.Chat` message" (not a Conversation), confirming Conversation must pre-exist when ProcessMessage runs. Orphan rows (join without send) accepted as non-blocking for Phase 28.

---

## ProcessMessage Scope

| Option | Description | Selected |
|--------|-------------|----------|
| A. New Chat facade function `Chat.ingest_widget_message/2` | Mirrors established pattern (DraftWorker → Automation, ToolExecutionWorker → Governance). Broadcasts on `"conversation:#{id}"` and `"conversations"`. Oban unique key guards retry idempotency. | ✓ |
| B. Inline Repo writes in ProcessMessage | ProcessMessage directly calls Repo.insert! and PubSub.broadcast. Fewer files but violates context-module authority boundary. | |
| C. Extend `reply_to_conversation/4` with `skip_draft_worker: true` | Reuse existing function with a safety opt. Semantically wrong — entangles customer ingress with agent-reply semantics. | |

**User's choice:** Delegated to Claude
**Notes:** Option A is the only option consistent with the project's pattern of workers calling into context modules, not raw Repo. Option C was eliminated because `reply_to_conversation/4` for `:user` role triggers DraftWorker — incorrect for raw customer ingress. Also noted: `WidgetChannel.handle_in("new_message", ...)` currently does NOT pass `conversation_id` in Oban job args; this must be fixed as part of GA-1 (socket.assigns.conversation_id set on join, then included in job args).

---

## InboxLive Real-Time Awareness

| Option | Description | Selected |
|--------|-------------|----------|
| A. PubSub `"conversations"` subscription | Subscribe in mount connected? block; handle_info reloads list + calls prune_selected_ids/2. Broadcast {conversations_changed} from ProcessMessage. | ✓ |
| B. Periodic polling via Process.send_after | 5s timer, no PubSub needed. Up-to-5s staleness, not idiomatic, misleads adopters. | |
| C. No change — accept manual refresh | Zero cost but breaks the two-tab demo. Fails CHAT-02 success criterion. | |

**User's choice:** Delegated to Claude
**Notes:** Option A was obvious — `prune_selected_ids/2` is literally wired-but-unused with a code comment at lines 81-91 saying "subscribe here when pubsub becomes load-bearing." Phase 28 is that phase. Use `Cairnloop.PubSub` for consistency with ConversationLive and all workers.

---

## Claude's Discretion

All three areas were decided by Claude after parallel advisor-researcher subagent analysis. User profile (`minimal_decisive`, technical) explicitly delegates gray-area decisions to Claude with a request for coherent, cohesive single recommendations.

Additional decisions made without user question:
- **JS Hook location:** Colocated in `chat_live.ex` via `Phoenix.LiveView.ColocatedHook` (already imported in `app.js`).
- **Hook send flow:** LV-driven — LV `handle_event("send_message")` → optimistic update → `push_event("widget:send", ...)` → hook pushes to channel. (UI-SPEC interaction contract step 2 specifies this.)
- **Endpoint socket path:** `/widget` for WidgetSocket mount (distinct from `/live` for LiveView).
- **Oban idempotency:** `unique: [period: 30, fields: [:worker, :args], keys: [:conversation_id, :content]]` on ProcessMessage.
- **PubSub bus name:** `Cairnloop.PubSub` throughout — same as ConversationLive, DraftWorker, ToolExecutionWorker.
- **ConversationLive handle_info extension:** Add `{:message_created, _message_id}` clause following the exact pattern of `{:draft_created, _}` and `{:tool_executed, _}`.

---

## Deferred Ideas

- Orphan Conversation cleanup job — deferred to vM015 (users who connect but never send create orphan rows)
- Channel topic re-join from `"widget:lobby"` to `"widget:{conversation_id}"` after join — deferred; `submit_csat` feature in `WidgetChannel` depends on it but CHAT-01/02/03 don't require it
- Targeted `{:new_conversation, conversation_id}` broadcast vs. coarse `{:conversations_changed}` — premature for Phase 28 volume
