# Phase 28: Customer `/chat` Wired to Real Ingress - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewire `/chat` (51-LOC mock) to the real `WidgetChannel` ingress path so the two-tab demo proves a live customer→operator→customer round trip. Three active changes: (1) mount `Cairnloop.Channels.WidgetSocket` in the example endpoint, (2) rewrite `ChatLive` to push through `WidgetChannel` + receive operator replies via PubSub — removing `Process.send_after/3` mock, (3) add a two-tab README doc block. Two supporting changes unlock the round trip: expand `ProcessMessage` from stub-logger to a real DB writer + broadcaster, and add PubSub subscription to `InboxLive` so new conversations surface without manual refresh. No operator-side template changes (ConversationLive PubSub is already wired at line 15).

</domain>

<decisions>
## Implementation Decisions

### GA-1 — Conversation creation timing + ChatLive PubSub coordination

- **D-01:** Conversation row is created **on channel join**, not on first message. `WidgetChannel.join("widget:lobby", payload, socket)` calls `Cairnloop.Chat.create_customer_conversation/1` (new facade function, see D-05), receives `conversation_id`, stores it in socket assigns, and pushes `{:ok, %{conversation_id: conversation_id}}` as the join reply so the client gets it immediately.
- **D-02:** The `WidgetChat` JS hook (colocated in `chat_live.ex`) receives the join reply, calls `this.pushEvent("conversation_id", {id: conversationId})`, and ChatLive's `handle_event("conversation_id", %{"id" => id}, socket)` subscribes to `"conversation:#{id}"` on `Cairnloop.PubSub`. This is the standard "hook tells LV" coordination pattern used when the server pushes data on channel join before the LiveView knows it.
- **D-03:** ChatLive assigns: `@channel_status :: :connecting | :connected | :disconnected`, `@messages :: list`, `@pending :: boolean`, `@conversation_id :: String.t() | nil` (nil until hook pushes it). Subscribe to `"conversation:#{id}"` only after conversation_id is received — not in `mount/3` (because the LV has no id yet).
- **D-04:** Orphan Conversation rows (user joins but never sends) are acceptable for Phase 28. No cleanup job is in scope. The `host_user_id` on the Conversation row is set to the socket token (e.g. `"demo_customer"`) so orphans are identifiable. Future milestone can add a TTL reaper.

### GA-2 — ProcessMessage scope and Chat facade expansion

- **D-05:** Add **`Cairnloop.Chat.create_customer_conversation/1`** — takes `%{host_user_id: token}`, creates a `Conversation` row, returns `{:ok, conversation}`. Called from `WidgetChannel.join/3`. Does NOT trigger DraftWorker, does NOT enqueue Oban jobs. Pure DB insert through the Chat facade.
- **D-06:** Add **`Cairnloop.Chat.ingest_widget_message/2`** — signature `ingest_widget_message(conversation_id, content)`. Creates a `:user`-role `Message` row. Does NOT call `reply_to_conversation/4` (that function triggers DraftWorker for `:user` role, which is wrong for raw customer ingress). After a successful insert, broadcasts:
  - `{:message_created, message.id}` on `"conversation:#{conversation_id}"` — triggers `ConversationLive.handle_info` to reload.
  - `{:conversations_changed}` on `"conversations"` — triggers InboxLive reload (see D-08).
- **D-07:** `ProcessMessage.perform/1` is rewritten to call `Chat.ingest_widget_message(conversation_id, content)`. The Oban job args must be updated to include `conversation_id`. `WidgetChannel.handle_in("new_message", %{"content" => content}, socket)` extracts `conversation_id` from `socket.assigns.conversation_id` (stored during join, see D-01) and passes it in the Oban job args: `%{channel: "widget", conversation_id: conversation_id, content: content}`. Add Oban `unique: [period: 30, fields: [:worker, :args], keys: [:conversation_id, :content]]` to guard retry idempotency on channel reconnect.
- **D-08:** All broadcasts use **`Cairnloop.PubSub`** — the single named bus used by ConversationLive, DraftWorker, and ToolExecutionWorker throughout the library.

### GA-3 — InboxLive real-time awareness for new conversations

- **D-09:** Add PubSub subscription in `InboxLive.mount/3` inside the `connected?(socket)` block: `Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")`. The code comment at lines 81-91 explicitly marks this as "future phase, subscribe here" — Phase 28 is that phase.
- **D-10:** Add `handle_info({:conversations_changed}, socket)` to `InboxLive`. It reloads `Chat.list_conversations()` and passes the result through `prune_selected_ids/2` (already wired per Phase 25, line 562+) to keep `@selected_ids` consistent with the rendered list. No streaming, no pagination change — simple list reload, same pattern as ConversationLive's `handle_info` clauses.

### JS Hook architecture

- **D-11:** The `WidgetChat` hook is **colocated** in `chat_live.ex` using Phoenix LiveView's `<script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">` syntax (already in deps at `examples/cairnloop_example/deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex`). Hook is already imported via `import {hooks as colocatedHooks} from "phoenix-colocated/cairnloop_example"` in `app.js`.
- **D-12:** Hook responsibilities: open `WidgetSocket` on the endpoint's canonical socket path using `phoenix.js` `Socket` primitive (the `Socket` import already exists in `app.js`). Join `"widget:lobby"` with connect params `{token: "demo_customer"}`. On successful join reply, `pushEvent("conversation_id", {id: conversationId})` to the LV. On `"operator_reply"` push from server, `pushEvent("operator_reply", {content, inserted_at})` to the LV. On channel state changes, `pushEvent("channel_status", {status: "connected"|"disconnected"|"connecting"})`.
- **D-13:** The form's `phx-submit="send_message"` hits the LV `handle_event`. LV optimistically appends the message to `@messages`, sets `@pending = true`, clears the input, then calls `push_event(socket, "widget:send", %{content: text})` so the hook pushes the message to the channel. Channel replies `:ok`; hook does not need to confirm back to LV (optimistic add already rendered). This is the LV-driven approach specified by the UI-SPEC interaction contract step 2.
- **D-14:** No npm packages, no external JS framework in the hook. Plain `phoenix.js` channel primitives only. Hook is minimal — ~50 LOC including error handling.

### Endpoint mount (trivial)

- **D-15:** Add `socket "/widget", Cairnloop.Channels.WidgetSocket, websocket: true, longpoll: false` to `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex`. Place it immediately after the existing `/live` socket line for readability.

### Test strategy

- **D-16:** Tests use `Phoenix.ChannelTest` (already in the project). The `ProcessMessage` worker tests are headless (pure function). `ChatLive` LiveView test uses `Phoenix.LiveViewTest`. No Wallaby, no PhoenixTest dep (locked by STATE.md vM014 test harness decision). Tests that require a real Repo round-trip are tagged `# REPO-UNAVAILABLE` per CLAUDE.md convention if the workspace Repo is unavailable.

### ConversationLive `handle_info` for `:message_created`

- **D-17:** `ConversationLive` needs a new `handle_info({:message_created, _message_id}, socket)` clause that calls `reload_conversation_with_context/2`. This follows the exact same pattern as the existing `{:draft_created, _}` and `{:tool_executed, _}` clauses at lines ~23-33 of `conversation_live.ex`. No structural change — additive only.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UI Design Contract (locked)
- `.planning/phases/28-customer-chat-wired-to-real-ingress/28-UI-SPEC.md` — Complete visual + interaction contract for Phase 28. Locks colors, spacing, typography, component inventory, copywriting, motion, accessibility. Agents MUST NOT deviate from this contract. Includes: channel connect flow, message send flow, `@channel_status` / `@messages` / `@pending` assign shapes, exact README copy.

### Requirements + Roadmap
- `.planning/REQUIREMENTS.md` — CHAT-01 (endpoint socket mount), CHAT-02 (chat_live rewrite), CHAT-03 (README two-tab block).
- `.planning/ROADMAP.md` §Phase 28 — Goal, success criteria (3 items), depends-on Phase 27.

### Architecture posture
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Host-owned architecture posture; operator authority model; why ProcessMessage routes through Oban rather than inline.
- `prompts/cairnloop_brand_book.md` — Copy register (§5.2 end-user widget tone), color rules (§7.3, §7.5), spacing (§16.2 touch targets), no typing indicator (§15.3).
- `CLAUDE.md` — Build/test conventions, arch invariants (Governance facade for reads, snapshot at decision time, sealed-contract posture, brand tokens).

### Existing implementation (read before modifying)
- `lib/cairnloop/channels/widget_socket.ex` — Token validation, `id/1` function shape.
- `lib/cairnloop/channels/widget_channel.ex` — Existing `join/3` clauses, `handle_in/3` for `"new_message"` + `"submit_csat"`. The `submit_csat` handler shows the pattern for extracting `conversation_id` from `socket.topic`.
- `lib/cairnloop/workers/process_message.ex` — Current stub; will be replaced per D-07.
- `lib/cairnloop/chat.ex` — Existing facade functions: `list_conversations/0`, `get_conversation!/1`, `reply_to_conversation/4`. New functions D-05 + D-06 go here.
- `lib/cairnloop/web/conversation_live.ex` — Lines 14-16 (PubSub subscribe pattern), lines 23-33 (handle_info clauses pattern to mirror for D-17), lines ~80+ (`reload_conversation_with_context/2` helper).
- `lib/cairnloop/web/inbox_live.ex` — Lines 80-105 (mount/3 + comment about future PubSub), line 562 (`prune_selected_ids/2` already wired).
- `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` — Current endpoint; socket mount goes here (D-15).
- `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` — Current 51-LOC mock to replace.
- `examples/cairnloop_example/assets/js/app.js` — `Socket` import already present; colocated hooks already wired via `{...colocatedHooks}`.
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` — `live "/chat", ChatLive` already mounted.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Cairnloop.PubSub`** — Named PubSub bus already started; used by ConversationLive, DraftWorker, ToolExecutionWorker. Use for all three broadcasts in this phase.
- **`ConversationLive` PubSub subscribe pattern** (line 14-16) — `if connected?(socket) do Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}") end` — copy exactly for ChatLive's second subscription (after hook pushes conversation_id) and for InboxLive's `"conversations"` subscription.
- **`ConversationLive` handle_info pattern** (line 23-33) — One-liner `reload_conversation_with_context/2` call. Mirror for D-17.
- **`InboxLive.prune_selected_ids/2`** (line 562+) — Already implemented; call after reloading conversations in handle_info.
- **`WidgetSocket`** — Any binary token is accepted; `socket.assigns.user_token` holds the token value.
- **`phoenix.js Socket` import** — Already in `assets/js/app.js`. Hook can use `new Socket("/widget", {params: {token: "demo_customer"}})` without adding npm deps.
- **Colocated hook pattern** — `<script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">` in `chat_live.ex`; already auto-imported via `{...colocatedHooks}` in `app.js`.
- **`Oban.Worker` unique constraint** — Established in `DraftWorker`; use same syntax for ProcessMessage idempotency guard.

### Established Patterns
- **Worker → context module → PubSub broadcast** — Every Oban worker calls a context module (DraftWorker → Automation, ToolExecutionWorker → Governance). ProcessMessage must call `Chat.ingest_widget_message/2`, not raw Repo.
- **Post-commit broadcast, not pre-commit** — Broadcasts happen after the successful Repo transaction in the worker (D16-11 pattern). Never broadcast inside a Multi.
- **`submit_csat` pattern for conversation_id extraction** — `"widget:" <> conversation_id = socket.topic` — use the same destructuring in `handle_in("new_message", ...)` once the topic is `"widget:{conversation_id}"` after join.
- **Additive only** — CLAUDE.md arch invariant: sealed code paths (`propose/3`, `reply_to_conversation/4` semantics, idempotency) must not be churned. New functions D-05 + D-06 are additive.

### Integration Points
- `WidgetChannel.join/3` → new `Chat.create_customer_conversation/1` → returns conversation_id stored in socket assigns
- `WidgetChannel.handle_in("new_message", ...)` → extracts conversation_id from `socket.assigns.conversation_id` → enqueues ProcessMessage with conversation_id in args
- `ProcessMessage.perform/1` → `Chat.ingest_widget_message(conversation_id, content)` → broadcasts on `Cairnloop.PubSub`
- `ChatLive` hook `pushEvent("conversation_id", ...)` → `ChatLive.handle_event("conversation_id", ...)` → `Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")`
- `ChatLive.handle_info({:message_created, _}, ...)` OR `{:new_message, _}` (match ConversationLive's existing broadcast shape) → append operator reply to `@messages`, set `@pending = false`
- `InboxLive.mount/3` `connected?` block → `subscribe(Cairnloop.PubSub, "conversations")` → `handle_info({:conversations_changed}, socket)` → reload + prune

</code_context>

<specifics>
## Specific Ideas

- **Demo token is `"demo_customer"`** — hardcoded in the example app JS hook connect params. WidgetSocket accepts any binary token (demo mode). This is the intentional pattern for the example app.
- **Channel topic transitions** — The channel starts on `"widget:lobby"` (unauthenticated) and the server joins the socket to `"widget:lobby"`. After conversation creation (D-01), the conversation_id is pushed back to the hook via the join reply (not a channel push event). The hook can optionally leave lobby and rejoin `"widget:{conversation_id}"` — but this is optional for the demo since the `:ok` join reply already carries the id and `socket.assigns.conversation_id` is set.
- **No typing indicator** — Brand book §15.3 explicitly forbids typing indicators unless streaming a real response. "Waiting on operator." row appears as plain text (not a bubble), 13px, `var(--cl-text-muted)`. This is already specified in the UI-SPEC copywriting contract.
- **`role="log" aria-live="polite"`** on message thread div — already in UI-SPEC accessibility contract. Planner must include it in the HEEx template.
- **Remove entire `handle_info(:bot_reply, ...)` clause** — not just the `Process.send_after` call. The clause itself must go to avoid any path that could re-trigger the mock reply on reconnect.

</specifics>

<deferred>
## Deferred Ideas

- **Orphan Conversation cleanup job** — Conversations created on channel join where the user never sends a message. Acceptable for Phase 28; deferred to vM015 or as part of a future session-lifecycle phase.
- **Channel topic re-join from `"widget:lobby"` to `"widget:{conversation_id}"`** — The hook could leave lobby and rejoin the conversation-scoped topic after receiving the conversation_id. This enables `submit_csat` from `"widget:{conversation_id}"`. Not required for CHAT-01/CHAT-02/CHAT-03; deferred to Phase 31 if the golden-path smoke needs it.
- **InboxLive broadcast shape** — Currently `{:conversations_changed}` broadcasts a nil payload. A future refinement could broadcast `{:new_conversation, conversation_id}` so InboxLive can do a targeted insert rather than a full list reload. Premature for Phase 28 volume.

</deferred>

---

*Phase: 28-customer-chat-wired-to-real-ingress*
*Context gathered: 2026-05-27*
