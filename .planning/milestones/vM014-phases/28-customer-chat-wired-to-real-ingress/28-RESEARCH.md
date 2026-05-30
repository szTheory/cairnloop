# Phase 28: Customer `/chat` Wired to Real Ingress - Research

**Researched:** 2026-05-27
**Domain:** Phoenix Channels + LiveView PubSub round trip (host-owned, Cairnloop example app)
**Confidence:** HIGH (every claim verified against in-repo files; CONTEXT.md/UI-SPEC are the locked design, this research adds verification + risk callouts)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**GA-1 — Conversation creation timing + ChatLive PubSub coordination**

- **D-01:** Conversation row is created **on channel join**, not on first message. `WidgetChannel.join("widget:lobby", payload, socket)` calls `Cairnloop.Chat.create_customer_conversation/1` (new facade function, see D-05), receives `conversation_id`, stores it in socket assigns, and pushes `{:ok, %{conversation_id: conversation_id}}` as the join reply so the client gets it immediately.
- **D-02:** The `WidgetChat` JS hook (colocated in `chat_live.ex`) receives the join reply, calls `this.pushEvent("conversation_id", {id: conversationId})`, and ChatLive's `handle_event("conversation_id", %{"id" => id}, socket)` subscribes to `"conversation:#{id}"` on `Cairnloop.PubSub`. This is the standard "hook tells LV" coordination pattern used when the server pushes data on channel join before the LiveView knows it.
- **D-03:** ChatLive assigns: `@channel_status :: :connecting | :connected | :disconnected`, `@messages :: list`, `@pending :: boolean`, `@conversation_id :: String.t() | nil` (nil until hook pushes it). Subscribe to `"conversation:#{id}"` only after conversation_id is received — not in `mount/3` (because the LV has no id yet).
- **D-04:** Orphan Conversation rows (user joins but never sends) are acceptable for Phase 28. No cleanup job is in scope. The `host_user_id` on the Conversation row is set to the socket token (e.g. `"demo_customer"`) so orphans are identifiable. Future milestone can add a TTL reaper.

**GA-2 — ProcessMessage scope and Chat facade expansion**

- **D-05:** Add **`Cairnloop.Chat.create_customer_conversation/1`** — takes `%{host_user_id: token}`, creates a `Conversation` row, returns `{:ok, conversation}`. Called from `WidgetChannel.join/3`. Does NOT trigger DraftWorker, does NOT enqueue Oban jobs. Pure DB insert through the Chat facade.
- **D-06:** Add **`Cairnloop.Chat.ingest_widget_message/2`** — signature `ingest_widget_message(conversation_id, content)`. Creates a `:user`-role `Message` row. Does NOT call `reply_to_conversation/4` (that function triggers DraftWorker for `:user` role, which is wrong for raw customer ingress). After a successful insert, broadcasts:
  - `{:message_created, message.id}` on `"conversation:#{conversation_id}"` — triggers `ConversationLive.handle_info` to reload.
  - `{:conversations_changed}` on `"conversations"` — triggers InboxLive reload (see D-08).
- **D-07:** `ProcessMessage.perform/1` is rewritten to call `Chat.ingest_widget_message(conversation_id, content)`. The Oban job args must be updated to include `conversation_id`. `WidgetChannel.handle_in("new_message", %{"content" => content}, socket)` extracts `conversation_id` from `socket.assigns.conversation_id` (stored during join, see D-01) and passes it in the Oban job args: `%{channel: "widget", conversation_id: conversation_id, content: content}`. Add Oban `unique: [period: 30, fields: [:worker, :args], keys: [:conversation_id, :content]]` to guard retry idempotency on channel reconnect.
- **D-08:** All broadcasts use **`Cairnloop.PubSub`** — the single named bus used by ConversationLive, DraftWorker, and ToolExecutionWorker throughout the library.

**GA-3 — InboxLive real-time awareness for new conversations**

- **D-09:** Add PubSub subscription in `InboxLive.mount/3` inside the `connected?(socket)` block: `Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")`. The code comment at lines 81-91 explicitly marks this as "future phase, subscribe here" — Phase 28 is that phase.
- **D-10:** Add `handle_info({:conversations_changed}, socket)` to `InboxLive`. It reloads `Chat.list_conversations()` and passes the result through `prune_selected_ids/2` (already wired per Phase 25, line 562+) to keep `@selected_ids` consistent with the rendered list. No streaming, no pagination change — simple list reload, same pattern as ConversationLive's `handle_info` clauses.

**JS Hook architecture**

- **D-11:** The `WidgetChat` hook is **colocated** in `chat_live.ex` using Phoenix LiveView's `<script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">` syntax (already in deps at `examples/cairnloop_example/deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex`). Hook is already imported via `import {hooks as colocatedHooks} from "phoenix-colocated/cairnloop_example"` in `app.js`.
- **D-12:** Hook responsibilities: open `WidgetSocket` on the endpoint's canonical socket path using `phoenix.js` `Socket` primitive (the `Socket` import already exists in `app.js`). Join `"widget:lobby"` with connect params `{token: "demo_customer"}`. On successful join reply, `pushEvent("conversation_id", {id: conversationId})` to the LV. On `"operator_reply"` push from server, `pushEvent("operator_reply", {content, inserted_at})` to the LV. On channel state changes, `pushEvent("channel_status", {status: "connected"|"disconnected"|"connecting"})`.
- **D-13:** The form's `phx-submit="send_message"` hits the LV `handle_event`. LV optimistically appends the message to `@messages`, sets `@pending = true`, clears the input, then calls `push_event(socket, "widget:send", %{content: text})` so the hook pushes the message to the channel. Channel replies `:ok`; hook does not need to confirm back to LV (optimistic add already rendered). This is the LV-driven approach specified by the UI-SPEC interaction contract step 2.
- **D-14:** No npm packages, no external JS framework in the hook. Plain `phoenix.js` channel primitives only. Hook is minimal — ~50 LOC including error handling.

**Endpoint mount (trivial)**

- **D-15:** Add `socket "/widget", Cairnloop.Channels.WidgetSocket, websocket: true, longpoll: false` to `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex`. Place it immediately after the existing `/live` socket line for readability.

**Test strategy**

- **D-16:** Tests use `Phoenix.ChannelTest` (already in the project). The `ProcessMessage` worker tests are headless (pure function). `ChatLive` LiveView test uses `Phoenix.LiveViewTest`. No Wallaby, no PhoenixTest dep (locked by STATE.md vM014 test harness decision). Tests that require a real Repo round-trip are tagged `# REPO-UNAVAILABLE` per CLAUDE.md convention if the workspace Repo is unavailable.

**ConversationLive `handle_info` for `:message_created`**

- **D-17:** `ConversationLive` needs a new `handle_info({:message_created, _message_id}, socket)` clause that calls `reload_conversation_with_context/2`. This follows the exact same pattern as the existing `{:draft_created, _}` and `{:tool_executed, _}` clauses at lines ~23-33 of `conversation_live.ex`. No structural change — additive only.

### Claude's Discretion

(CONTEXT.md surfaces no Claude's Discretion items — every meaningful call was locked into the D-01..D-17 set. The remaining freedom is implementation-level: file ordering, exact private-helper names, brand-token fallback hex values matching UI-SPEC, test-name phrasing.)

### Deferred Ideas (OUT OF SCOPE)

- **Orphan Conversation cleanup job** — Conversations created on channel join where the user never sends a message. Acceptable for Phase 28; deferred to vM015 or as part of a future session-lifecycle phase.
- **Channel topic re-join from `"widget:lobby"` to `"widget:{conversation_id}"`** — The hook could leave lobby and rejoin the conversation-scoped topic after receiving the conversation_id. This enables `submit_csat` from `"widget:{conversation_id}"`. Not required for CHAT-01/CHAT-02/CHAT-03; deferred to Phase 31 if the golden-path smoke needs it.
- **InboxLive broadcast shape** — Currently `{:conversations_changed}` broadcasts a nil payload. A future refinement could broadcast `{:new_conversation, conversation_id}` so InboxLive can do a targeted insert rather than a full list reload. Premature for Phase 28 volume.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHAT-01 | `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` mounts `Cairnloop.Channels.WidgetSocket` at canonical socket path | One-line edit to `endpoint.ex` per D-15. The existing `socket "/live", Phoenix.LiveView.Socket` line at endpoint.ex:14 is the placement template. WidgetSocket already exists at `lib/cairnloop/channels/widget_socket.ex` and accepts any binary token (demo mode). |
| CHAT-02 | `chat_live.ex` rewritten from 51-LOC mock to push customer messages through `WidgetChannel` + receive operator replies via PubSub; no mock `Process.send_after(self(), :bot_reply, 1000)` path remains | D-01..D-17 cover the complete rewrite. Hook is colocated (D-11), LV pushes via `push_event/3` (D-13), PubSub subscribe is gated on conversation_id arrival (D-02). Both the `Process.send_after` call AND the `handle_info(:bot_reply, …)` clause itself must be removed (specifics §125). |
| CHAT-03 | README two-tab demo block with exact local-dev commands | Exact prose locked in UI-SPEC §3 (lines 161-176). Routes verified: operator `/support` (router.ex:21, mounted via Cairnloop.Web.InboxLive), customer `/chat` (router.ex:35). `mix setup && mix phx.server` already documented in current README. |
</phase_requirements>

## Summary

Phase 28 wires the customer `/chat` LiveView to the same `WidgetChannel` ingress path the host-owned library already exposes, ending the `Process.send_after` mock and proving the customer→operator→customer round trip end-to-end. CONTEXT.md locks 17 decisions covering conversation creation timing (on join, not first message), Chat facade expansion (two new functions `create_customer_conversation/1` and `ingest_widget_message/2`), ProcessMessage rewrite, PubSub topology, JS hook architecture (colocated, plain `phoenix.js`), and InboxLive realtime awareness. The UI-SPEC locks every visual + interaction detail down to copy strings, ARIA roles, and brand tokens.

The plan is small in code (one-line endpoint mount, ~150-LOC chat_live rewrite, two new facade functions, ~30-LOC ProcessMessage rewrite, ~15-LOC InboxLive + ConversationLive additions) but **carries a load-bearing environment gap that CONTEXT.md does not surface**: the example app's supervisor starts only `CairnloopExample.PubSub`, while every library broadcast (ConversationLive subscribe, DraftWorker broadcast, ToolExecutionWorker broadcast) targets the unstarted `Cairnloop.PubSub`. Without remediation, every subscribe in the operator-side LiveView will raise `ArgumentError: unknown registry: Cairnloop.PubSub`. This is the single biggest planning risk — see Pitfall 1 below.

The phase also has a **silently-impacted secondary caller**: `Cairnloop.Ingress.EmailWebhookPlug` (`lib/cairnloop/ingress/email_webhook_plug.ex:19`) calls `ProcessMessage.new(%{channel: "email", content: content})` — same worker, no `conversation_id`. D-07's args reshape will break this path unless ProcessMessage either branches on `channel` or the email plug is also updated. CONTEXT.md does not surface this.

**Primary recommendation:** Plan must include (1) a Wave-0 task that adds `{Phoenix.PubSub, name: Cairnloop.PubSub}` to `CairnloopExample.Application`'s children list and corrects `config.exs :pubsub_server` (or keeps both PubSub instances and uses the library one for cross-LV broadcasts — additive); (2) a guard task that updates `ProcessMessage.perform/1` to handle BOTH the new `widget` shape (with `conversation_id`) and the existing `email` shape (without) — either via pattern match or by also extending `EmailWebhookPlug` to ingest into a conversation; (3) full coverage per D-01..D-17.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Customer message UI (input + thread) | Browser (Phoenix LiveView client) | Frontend Server (HEEx render) | LiveView renders HEEx; optimistic append is LV-state; the hook lives on the browser tier |
| WebSocket transport (Widget channel) | Browser ↔ Frontend Server (Phoenix Channel) | — | `WidgetSocket` mount on Endpoint is the boundary; `Cairnloop.Channels.WidgetChannel` runs in the BEAM process |
| Conversation row creation on join | API / Backend (Chat facade) | Database (Postgres) | `Cairnloop.Chat.create_customer_conversation/1` is the new narrow facade entry; Repo insert is the storage tier |
| Customer message ingest (DB write + broadcast) | API / Backend (Oban worker → Chat facade) | Database, PubSub bus | `ProcessMessage` Oban worker, `Cairnloop.Chat.ingest_widget_message/2` (new), `Cairnloop.PubSub` broadcast. Worker layer is the right tier — never inline in the channel `handle_in` (T-M001-03 mitigation, established in the existing widget_channel.ex:21 comment) |
| Operator inbox real-time list refresh | Frontend Server (LiveView process) | PubSub bus | `InboxLive.handle_info({:conversations_changed}, …)` reloads via `Chat.list_conversations/0`. PubSub is the messaging tier, not the storage tier |
| Operator conversation timeline refresh | Frontend Server (LiveView process) | PubSub bus | `ConversationLive.handle_info({:message_created, _}, …)` reloads via `Chat.get_conversation!/1`. Same pattern as the existing `{:draft_created, _}` handler at conversation_live.ex:26 |
| Customer chat operator-reply rendering | Browser (LiveView client) | Frontend Server (LV process) | LV holds `@messages`; PubSub message from `reply_to_conversation/4` triggers a handle_info that appends + clears `@pending`; LV re-renders the message thread |
| README documentation (CHAT-03) | Documentation tier (no runtime tier) | — | Static markdown in `examples/cairnloop_example/README.md`; no code changes |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix` | 1.8.7 | Endpoint + Router + Channel macros | Already in `examples/cairnloop_example/mix.exs:48`. Phoenix Channels are the canonical Elixir WebSocket primitive; no alternative is in-scope for a host-owned library. [VERIFIED: examples/cairnloop_example/mix.exs] |
| `phoenix_live_view` | 1.1.0 | LiveView + colocated hooks + `push_event/3` | Already in `examples/cairnloop_example/mix.exs:54` and library `mix.exs:89`. ColocatedHook macro requires Phoenix 1.8+ which is satisfied. [VERIFIED: examples/cairnloop_example/deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex:6] |
| `phoenix_pubsub` | (transitive via phoenix) | Named PubSub bus for cross-process broadcasts | Used pervasively in the library: `lib/cairnloop/web/conversation_live.ex:15`, `lib/cairnloop/automation/workers/draft_worker.ex:104`, `lib/cairnloop/workers/tool_execution_worker.ex:584`. [VERIFIED: grep] |
| `oban` | 2.17 | Async job for `ProcessMessage` (prevents blocking the channel) | Already in `examples/cairnloop_example/mix.exs:50` and library `mix.exs:91`. Established pattern: `WidgetChannel.handle_in/3` enqueues; worker writes (T-M001-03). [VERIFIED: widget_channel.ex:21 comment] |
| `ecto_sql` / `postgrex` | 3.13 / latest | Conversation + Message inserts | Already in deps. `Cairnloop.Chat` reads `:cairnloop, :repo` via `Application.fetch_env!`; example app config sets it to `CairnloopExample.Repo`. [VERIFIED: chat.ex:6, examples/.../config.exs:64] |
| `ecto.uuid` / Phoenix.Token | (transitive) | Not needed — token is plain binary in demo mode | `WidgetSocket.connect/3` accepts any binary token via `case params do %{"token" => token} when is_binary(token) -> {:ok, assign(...)}`. No JWT/signature in v1. [VERIFIED: widget_socket.ex:10-13] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lazy_html` | latest (test-only) | LiveView `element/2`, `render_submit/2` HTML parsing in tests | Already in deps as `only: :test` (mix.exs:55). Use in ChatLive LiveViewTest. [VERIFIED: examples/.../mix.exs] |
| Phoenix `Socket` JS client | (built into phoenix dep) | Browser-side channel connect + push | Already imported in `examples/.../assets/js/app.js:23`. Use `new Socket("/widget", {params: {token: "demo_customer"}})`. [VERIFIED: app.js:23] |
| Phoenix.ChannelTest | (built into phoenix) | Headless channel join/push/broadcast tests | Pattern already established in `test/cairnloop/channels/widget_channel_test.exs` (the test currently does NOT use `use Phoenix.ChannelTest` — it stubs `%Phoenix.Socket{}` directly; we will keep that pattern for unit tests and use `Phoenix.ChannelTest` proper for the integration test). [VERIFIED: existing test] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Phoenix Channels | LiveView pure-LV channel (no widget socket) | Rejected: D-15 requires endpoint socket mount because `WidgetChannel` is the host-owned ingress path adopters will use; using only LV would not exercise that path. |
| Colocated hook | Separate `.js` file in `assets/js/hooks/` | Rejected by D-11: the project already uses colocated hooks via `import {hooks as colocatedHooks} from "phoenix-colocated/cairnloop_example"` — adding a separate `hooks/` dir would create two competing hook conventions. |
| `Phoenix.PubSub` for the new "conversations" topic | Direct `Process.send` to an InboxLive PID registry | Rejected: would require a presence/registry abstraction. The library already runs `Cairnloop.PubSub`-style broadcasts; D-08 keeps the convention. |
| Channel topic re-join (lobby → widget:{conversation_id}) | Stay on `widget:lobby` and pass `conversation_id` in payload | CONTEXT.md "specifics" §122 explicitly defers re-join. Phase 28 stays on lobby. |
| Tag job retry idempotency via custom worker logic | Oban `unique:` option (D-07) | Use the Oban `unique:` option (already used in `DraftWorker` at `automation/workers/draft_worker.ex:3-5` with `unique: [period: 60, states: [:scheduled]]`). Cleaner. [VERIFIED: draft_worker.ex] |

**Installation:**
No new dependencies needed. Every required library is already in `examples/cairnloop_example/mix.exs` and the library root `mix.exs`. [VERIFIED: both mix.exs files]

**Version verification:** No new packages are introduced by this phase; the Package Legitimacy Audit below is a no-op.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | No external packages added; phase reuses in-deps libraries only. |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*Phase 28 does not add any new dependencies. All transport, persistence, and broadcast primitives are already in `mix.exs`.*

## Architecture Patterns

### System Architecture Diagram

```
Customer browser (`/chat`)
   │
   │ 1. WidgetChat hook opens Socket("/widget", {token: "demo_customer"})
   │ 2. Hook joins "widget:lobby"
   ▼
WidgetSocket.connect/3 (validates binary token) ──► WidgetChannel.join/3
                                                       │
                                                       │ 3. Chat.create_customer_conversation/1
                                                       │    inserts Conversation row → returns conversation_id
                                                       │
                                                       │ 4. {:ok, %{conversation_id: id}} as join reply
                                                       │    AND broadcast {:conversations_changed} on "conversations"
                                                       ▼
   ┌──────────────────────────────────────────────┐
   │ Browser hook receives join reply             │   ┌──────────────────────────┐
   │   pushEvent("conversation_id", {id})         │   │ InboxLive.handle_info    │
   ▼                                              │   │ ({:conversations_changed}│
ChatLive.handle_event("conversation_id", …)       │   │  reloads list + prunes   │
   │                                              │   │  @selected_ids)          │
   │ 5. Phoenix.PubSub.subscribe(                 │   └──────────────────────────┘
   │      Cairnloop.PubSub,                       │              ▲
   │      "conversation:#{id}")                   │              │ broadcasts on Cairnloop.PubSub
   ▼                                              │              │ topic "conversations"
[customer types message]                          │              │
   │                                              │              │
   │ 6. phx-submit="send_message"                 │              │
   ▼                                              │              │
ChatLive.handle_event("send_message", …)          │              │
   │ optimistic append → @messages + @pending=true│              │
   │ push_event(socket, "widget:send", …)         │              │
   ▼                                              │              │
Hook receives "widget:send" → channel.push(       │              │
   "new_message", %{content: text})               │              │
   │                                              │              │
   ▼                                              │              │
WidgetChannel.handle_in("new_message", …)         │              │
   │ Oban.insert(ProcessMessage.new(              │              │
   │   %{channel: "widget",                       │              │
   │     conversation_id: id,                     │              │
   │     content: text},                          │              │
   │   unique: [...] ))                           │              │
   │ {:reply, :ok, socket}                        │              │
   ▼                                              │              │
ProcessMessage.perform/1 (worker)                 │              │
   │ Chat.ingest_widget_message(id, content)      │              │
   │   → Repo.insert Message{role: :user}         │              │
   │   → Phoenix.PubSub.broadcast Cairnloop.PubSub│──────────────┘
   │       "conversation:#{id}", {:message_created, msg_id}
   │       "conversations", {:conversations_changed}
   │
   ▼
ConversationLive (operator side, subscribed at mount)
   │ handle_info({:message_created, _}, …)
   │ reload_conversation_with_context/2 → refreshes timeline
   ▼
[Operator types reply in textarea, phx-submit="reply"]
   │ Chat.reply_to_conversation(id, content, :agent)  -- already implemented
   │ multi.insert Message{role: :agent}
   │ (existing path; no change in Phase 28 but the broadcast must reach ChatLive)
   ▼
Cairnloop.Chat.reply_to_conversation already broadcasts nothing today —
   CONTEXT.md does not address this gap explicitly. See Open Question OQ-1.
   (D-06 only adds broadcast for the inbound widget message; the operator-reply
   broadcast requires a new emit point. RECOMMEND: add a `:message_created`
   broadcast inside `reply_to_conversation/4`'s post-transaction success branch
   so the customer ChatLive receives the operator reply.)
   ▼
ChatLive.handle_info({:message_created, msg_id}, …) (subscribed to "conversation:#{id}")
   │ loads message from Repo (or accepts `{:operator_reply, content, inserted_at}` payload)
   │ appends to @messages with :operator role; @pending = false
   ▼
Customer sees operator reply rendered in `/chat`
```

### Recommended Project Structure

No new directories. Files touched / created (relative to repo root):

```
lib/
├── cairnloop/
│   ├── chat.ex                              # ADD: create_customer_conversation/1, ingest_widget_message/2
│   ├── channels/
│   │   └── widget_channel.ex                # MODIFY: join/3 creates conversation; handle_in/3 passes conversation_id
│   ├── workers/
│   │   └── process_message.ex               # REWRITE: stub-logger → real DB writer + broadcaster
│   ├── web/
│   │   ├── conversation_live.ex             # ADD: handle_info({:message_created, _}, _)
│   │   └── inbox_live.ex                    # ADD: Phoenix.PubSub.subscribe in mount + handle_info({:conversations_changed}, _)
│   └── ingress/
│       └── email_webhook_plug.ex            # MODIFY (silent caller): match new ProcessMessage args shape

examples/cairnloop_example/
├── lib/cairnloop_example/
│   └── application.ex                       # ADD: {Phoenix.PubSub, name: Cairnloop.PubSub} to children
├── lib/cairnloop_example_web/
│   ├── endpoint.ex                          # ADD: socket "/widget", Cairnloop.Channels.WidgetSocket
│   └── live/
│       └── chat_live.ex                     # REWRITE: 51-LOC mock → ~150 LOC real channel client
└── README.md                                # ADD: "## Two-Tab Demo" section per UI-SPEC §3

test/cairnloop/
├── channels/widget_channel_test.exs         # EXTEND: test new join behavior + handle_in("new_message", …)
├── workers/process_message_test.exs         # NEW: headless test of ProcessMessage.perform with mock Chat
├── chat_test.exs                            # EXTEND: cover create_customer_conversation/1 + ingest_widget_message/2
└── web/inbox_live_test.exs (if exists)      # EXTEND: assert subscribe + handle_info reload
```

### Pattern 1: Worker → Context Module → PubSub Broadcast (sealed library convention)

**What:** Every Oban worker (`DraftWorker`, `ToolExecutionWorker`) calls a context module and broadcasts post-commit. Never broadcasts inside an `Ecto.Multi`.

**When to use:** ProcessMessage.perform/1 in this phase.

**Example:**
```elixir
# Source: lib/cairnloop/automation/workers/draft_worker.ex:101-114 (in-repo)
case Cairnloop.Automation.create_draft(conversation_id, attrs) do
  {:ok, draft} ->
    Phoenix.PubSub.broadcast(
      Cairnloop.PubSub,
      "conversation:#{conversation_id}",
      {:draft_created, draft.id}
    )
    :ok

  {:error, _changeset} ->
    :error
end
```

### Pattern 2: LiveView PubSub Subscribe (existing convention)

**What:** Subscribe inside `connected?(socket)` to avoid double-subscription during the initial HTTP render. Use `Cairnloop.PubSub` as the named bus.

**When to use:** ChatLive subscribes after receiving conversation_id from hook (D-02). InboxLive subscribes in `mount/3` connected block (D-09).

**Example:**
```elixir
# Source: lib/cairnloop/web/conversation_live.ex:13-16 (in-repo)
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end
  # ...
end
```

For ChatLive, the subscribe moves to the `handle_event("conversation_id", ...)` clause (because the LV doesn't know the id at mount time):

```elixir
def handle_event("conversation_id", %{"id" => id}, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end
  {:noreply, assign(socket, conversation_id: id, channel_status: :connected)}
end
```

### Pattern 3: Colocated Hook (Phoenix LiveView 1.1+)

**What:** `<script :type={Phoenix.LiveView.ColocatedHook} name=".HookName">` inside the LV's HEEx. Auto-extracted at compile time, auto-imported via `phoenix-colocated/cairnloop_example`.

**When to use:** WidgetChat hook lives inside chat_live.ex render/1.

**Example:**
```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex:10-36 (canonical docs)
def render(assigns) do
  ~H"""
  <div phx-hook=".WidgetChat" id="widget-chat-root" data-token="demo_customer">
    <!-- HEEx markup ... -->
  </div>
  <script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">
    export default {
      mounted() {
        const token = this.el.dataset.token;
        const socket = new Socket("/widget", {params: {token}});
        socket.connect();

        this.channel = socket.channel("widget:lobby", {});
        this.channel.join()
          .receive("ok", ({conversation_id}) => {
            this.pushEvent("conversation_id", {id: conversation_id});
            this.pushEvent("channel_status", {status: "connected"});
          })
          .receive("error", () => this.pushEvent("channel_status", {status: "disconnected"}));

        socket.onError(() => this.pushEvent("channel_status", {status: "disconnected"}));
        socket.onOpen(() => this.pushEvent("channel_status", {status: "connected"}));

        this.handleEvent("widget:send", ({content}) => {
          this.channel.push("new_message", {content})
            .receive("error", () => this.pushEvent("channel_status", {status: "disconnected"}));
        });
      },
      destroyed() {
        if (this.channel) this.channel.leave();
      }
    }
  </script>
  """
end
```

**Gotcha:** ColocatedHook's `import` of `Socket` is NOT automatic. The hook code runs in the context of the manifest module, and the `Socket` import in `app.js:23` is module-scoped. The hook needs to either: (a) accept `Socket` as a closure-captured global, (b) import it itself, or (c) the colocated hook file re-imports it. The cleanest path is to import inside the hook file — colocated hooks support ES module imports per `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex` docs. **The planner must verify the import resolution path in the hook's `<script>` tag, or the hook will fail at runtime with `Socket is not defined`.** [LOW confidence: ColocatedHook behavior re imports — verify against current docs during implementation]

### Anti-Patterns to Avoid

- **Calling `reply_to_conversation/4` with `:user` role from `ProcessMessage`** — That function triggers DraftWorker for `:user` role (chat.ex:54-94). CONTEXT.md D-06 explicitly forbids it ("that function triggers DraftWorker for :user role, which is wrong for raw customer ingress"). Use `ingest_widget_message/2`, which is the new narrow facade.
- **Subscribing in `mount/3` before `conversation_id` exists** — ChatLive has no id at mount time (D-02). Subscribing to `"conversation:nil"` reaches no subscriber but pollutes the subscription registry. Subscribe only in the `handle_event("conversation_id", …)` clause.
- **Broadcasting inside an `Ecto.Multi`** — The post-commit-broadcast pattern is sealed in the library (D-08; STATE.md "Decisions" §47 "Post-commit broadcast, not pre-commit"). Broadcast in the worker's `:ok` branch after `transaction/1` returns.
- **Hand-rolling channel state machine in JS** — Use `phoenix.js` `socket.onOpen`, `socket.onError`, `channel.join().receive("ok"|"error", …)` primitives. They have built-in auto-reconnect.
- **Leaving the `handle_info(:bot_reply, _)` clause in chat_live.ex** — CONTEXT.md specifics §125 explicitly requires removing the clause itself, not just the `Process.send_after` call. A leftover clause could re-trigger the mock reply on reconnect or via stale assigns.
- **Calling `Cairnloop.PubSub.subscribe` from a process where `Cairnloop.PubSub` is not running** — see Pitfall 1.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WebSocket transport | Custom `cowboy_websocket` handler | `Phoenix.Socket` + `Phoenix.Channel` | Already provided, battle-tested, includes auto-reconnect and heartbeats |
| Channel auto-reconnect logic in JS | Custom retry/backoff timer | `phoenix.js` `Socket` built-in `reconnectAfterMs` | Phoenix client already does exponential backoff |
| Channel state observability | Custom event bus | `socket.onOpen`, `socket.onError`, `socket.onClose` | Built-in callbacks, fire on every transition |
| Hook → LV communication | Window globals or DOM events | `this.pushEvent("event_name", payload)` + LV `handle_event/3` | Single-direction explicit channel, audited by Phoenix |
| LV → Hook communication | DOM manipulation from LV | `push_event(socket, "event_name", payload)` + JS `this.handleEvent("event_name", …)` | Reverse direction explicit channel |
| Process-to-process broadcast | Direct `Process.send` + Registry | `Phoenix.PubSub.broadcast/3` + `subscribe/2` | Already in library, distributed-aware, name-resolved |
| Oban job retry idempotency | Custom dedup column | Oban `unique:` option | D-07 calls for it explicitly; established in DraftWorker |
| Conversation creation transaction safety | Multi.run with custom rollback | `Repo.insert/2` (single-row insert, no transaction needed for D-05) | `create_customer_conversation/1` is a single insert; no multi-step coordination |

**Key insight:** Every primitive needed for Phase 28 is already in deps and already used elsewhere in the codebase. The phase's risk is not "what to build" but "what to wire" — specifically, the PubSub-name mismatch (Pitfall 1) and the silent secondary caller (Pitfall 2).

## Runtime State Inventory

> Phase 28 is a feature wiring phase, not a rename/refactor. Runtime State Inventory is included for **D-05 D-06 D-07 D-15 D-09**'s impact surface — anywhere code outside the files-being-edited holds a reference that could break.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `cairnloop_conversations` rows from Phase 27 seeds. Phase 28 ADDS new rows (one per `/chat` join). Existing rows unaffected. Phase 28 does NOT migrate or modify existing rows. | No data migration. New rows are additive. |
| Live service config | None — `Cairnloop.PubSub` is a BEAM process supervisor child, not an external config. BUT: example app supervisor must be updated to start it (Pitfall 1). | One-line edit to `examples/cairnloop_example/lib/cairnloop_example/application.ex:11` to add `{Phoenix.PubSub, name: Cairnloop.PubSub}` to the children list. |
| OS-registered state | None. | None. |
| Secrets/env vars | None. The demo token `"demo_customer"` is a hardcoded binary in the JS hook per CONTEXT.md "specifics" §121. WidgetSocket accepts any binary token in demo mode. | None — no secret store involved. |
| Build artifacts / installed packages | Compiled colocated hooks land in `_build/dev/lib/cairnloop_example/priv/static/assets/...` after `mix compile`. The auto-extracted hook file at `_build/.../phoenix-colocated/cairnloop_example/CairnloopExampleWeb.ChatLive.WidgetChat.js` (or similar manifest entry) is rebuilt on each compile. `mix esbuild cairnloop_example` re-bundles after compile. The published library never ships the example's compiled artifacts. | Run `mix compile && mix esbuild cairnloop_example` after editing chat_live.ex's colocated hook. If running with `mix phx.server` in dev mode, the watcher handles this automatically. |
| Silent code-level callers (project skill: ripgrep callers before signature changes) | `Cairnloop.Ingress.EmailWebhookPlug` (`lib/cairnloop/ingress/email_webhook_plug.ex:19`) calls `ProcessMessage.new(%{channel: "email", content: content})`. D-07's reshape of ProcessMessage args (adds `conversation_id`) breaks this if not handled. | **MUST update ProcessMessage to pattern-match on channel** — `widget` branch uses `Chat.ingest_widget_message/2`, `email` branch keeps the existing logger stub (or moves to a future "email ingest" handler). Alternative: extend `EmailWebhookPlug` to also create a Conversation and pass conversation_id. CONTEXT.md does not address this — see Open Question OQ-2. |

**Nothing found in category — sub-callers:** I grepped `Cairnloop.Chat.reply_to_conversation`, `Cairnloop.Chat.list_conversations`, `Cairnloop.PubSub` usages — no other surprise consumers beyond the two already-known operator LiveViews and the email plug.

## Common Pitfalls

### Pitfall 1: Example app PubSub mismatch — load-bearing environment gap not in CONTEXT.md

**What goes wrong:** D-08 mandates "all broadcasts use `Cairnloop.PubSub`." The library's `ConversationLive.mount/3` already executes `Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")` at conversation_live.ex:15. But the example app's supervisor in `examples/cairnloop_example/lib/cairnloop_example/application.ex:14` only starts `{Phoenix.PubSub, name: CairnloopExample.PubSub}`. `Cairnloop.PubSub` is never started in the example app.

**Why it happens:** Cairnloop is a host-owned library — `Cairnloop.Application` boots ZERO children by design (application.ex:16-25). The integration test suite starts `Cairnloop.PubSub` explicitly in `test_helper.exs:24`. The example app inherited the LiveView phx.gen.live-style pattern that wires a single `<AppName>.PubSub`, and the library never enforced the dual-PubSub contract.

**Today's state:** The operator side (`/support/:id`) likely raises `ArgumentError, "unknown registry: Cairnloop.PubSub"` the moment it tries to subscribe, OR the LV silently fails the subscribe and falls back to non-realtime mode. **The planner should test this before Phase 28 — if `mix phx.server` + open an existing conversation works today, then something else is providing `Cairnloop.PubSub` (e.g., via dependency boot) and Phase 28 may not need this fix.** If it doesn't work today (which is the more likely state given the supervisor config), Phase 28 must add it.

**How to avoid:** Add `{Phoenix.PubSub, name: Cairnloop.PubSub}` to `CairnloopExample.Application`'s children list BEFORE `CairnloopExampleWeb.Endpoint`. Keep `CairnloopExample.PubSub` for any example-app-specific topics (the endpoint config at config.exs:26 sets `pubsub_server: CairnloopExample.PubSub` for LV broadcasts initiated by the example endpoint — that's a different topic space). The two PubSub buses are independent named registries; running both has zero conflict.

**Warning signs:** A `(ArgumentError) unknown registry: Cairnloop.PubSub` exception when opening any conversation in the example app today. If that error doesn't surface, verify by grepping logs for "broadcast" failures during PubSub.broadcast/3 — `Phoenix.PubSub.broadcast/3` returns `{:error, reason}` when the registry doesn't exist and `DraftWorker` swallows the result.

### Pitfall 2: ProcessMessage's second caller (EmailWebhookPlug) silently breaks under D-07 args reshape

**What goes wrong:** D-07 changes `ProcessMessage` args from `%{channel: "widget", content: content}` to `%{channel: "widget", conversation_id: id, content: content}`. `EmailWebhookPlug` at email_webhook_plug.ex:19 still calls `ProcessMessage.new(%{channel: "email", content: content})` — no `conversation_id`. When the rewritten `perform/1` pattern-matches and expects `conversation_id`, the email path either crashes (FunctionClauseError) or silently no-ops.

**Why it happens:** ProcessMessage was historically a stub-logger ignoring both channels. D-07 promotes it to a real writer, but only for the widget channel. CONTEXT.md does not call out the email caller.

**How to avoid:** Rewrite `ProcessMessage.perform/1` to pattern-match on the `channel` key:

```elixir
def perform(%Oban.Job{args: %{"channel" => "widget", "conversation_id" => id, "content" => content}}) do
  Cairnloop.Chat.ingest_widget_message(id, content)
end

def perform(%Oban.Job{args: %{"channel" => "email", "content" => content}}) do
  # Keep current logger stub for email — outside Phase 28 scope.
  require Logger
  Logger.info("Processed email message: #{content}")
  :ok
end
```

**Warning signs:** Phase 31 (the golden-path smoke test) covers customer ingress via WidgetChannel. If the smoke test passes but the email webhook path becomes silently broken, no test would catch it until an adopter exercises the email path. **The planner should add a 2-line headless test in `process_message_test.exs` covering the email arg shape to lock the second clause.**

### Pitfall 3: `reply_to_conversation/4` does not broadcast `:message_created`

**What goes wrong:** D-06 broadcasts `{:message_created, msg_id}` from `ingest_widget_message/2` so ConversationLive (operator) reloads. But the operator's reply path uses the EXISTING `Chat.reply_to_conversation/4` (chat.ex:25-147), which **does not currently broadcast anything**. The customer's `/chat` LiveView, subscribed to `"conversation:#{id}"` per D-02, will never receive the operator's reply via PubSub — the round trip breaks at step 11 of the UI-SPEC interaction contract.

**Why it happens:** `reply_to_conversation/4` is sealed code (CLAUDE.md "Seal completed phases"). It was designed when only operators read the timeline (and `ConversationLive` reloads on its own `handle_event("reply", …)` path, not via PubSub). The customer-facing LiveView did not exist as a real consumer before Phase 28.

**How to avoid:** Two compliant options:

(a) **Add a broadcast at the very end of `reply_to_conversation/4`'s `{:ok, results}` branch** (additive, doesn't churn sealed semantics). After `result = repo().transaction(multi)`, in the `{:ok, _}` case, broadcast `{:message_created, results.message.id}` on `"conversation:#{conversation.id}"`. This is the minimal, additive change.

(b) **Add a NEW broadcast emit point inside `ConversationLive.handle_event("reply", …)`** (web layer broadcasts after success). Slightly less clean — broadcasts from the web layer rather than the data layer — but doesn't touch the sealed `Chat` facade at all.

Option (a) is preferred and aligned with the existing convention (`DraftWorker` broadcasts post-commit in the data layer at draft_worker.ex:103). The planner must verify whether this counts as "churn to sealed primitives" (carried decision: "sealed-contract + additive-opts invariant") — adding a broadcast inside an `:ok` branch is additive behavior, not a contract change, and prior phases (Phase 14, 15, 16) added similar additive broadcasts to existing code.

**Warning signs:** Customer sends a message → operator replies → customer's `/chat` never updates. Manual reproduction in the two-tab demo will catch this immediately; a headless test of the round-trip (Phoenix.LiveViewTest + Phoenix.PubSub manual broadcast) should be added in Phase 28's test suite.

### Pitfall 4: ColocatedHook's `Socket` import resolution

**What goes wrong:** The colocated hook code is extracted to `_build/.../phoenix-colocated/cairnloop_example/CairnloopExampleWeb.ChatLive.WidgetChat.js`. That file's `export default {...}` runs in its own module scope, and `Socket` is NOT in scope unless explicitly imported in the hook's `<script>` body. The hook will fail at runtime with `ReferenceError: Socket is not defined`.

**Why it happens:** Phoenix's `app.js:23` imports `Socket` at the manifest level, but each hook is its own ES module after extraction. The `import {hooks as colocatedHooks} from "phoenix-colocated/cairnloop_example"` line at app.js:25 only collects compiled hooks — it doesn't share imports.

**How to avoid:** Add the import inside the hook `<script>`:

```elixir
~H"""
<script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">
  import {Socket} from "phoenix"

  export default {
    mounted() { ... }
  }
</script>
"""
```

Colocated hooks support ES module syntax per `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex` docs. The bundler resolves the `phoenix` package via the same `node_modules`-style path the manifest uses (esbuild config at config.exs:34 includes `NODE_PATH: deps/` directory).

**Warning signs:** Browser console shows "Socket is not defined" on opening `/chat`. Confirmed during smoke test — should be caught before plan acceptance.

### Pitfall 5: Conversation creation on lobby join — race condition with rapid reconnects

**What goes wrong:** D-01 creates a Conversation row in `WidgetChannel.join("widget:lobby", …)`. If the customer's tab reconnects (network blip, server restart, phoenix client auto-reconnect), `join/3` runs again and creates a SECOND orphan Conversation. Multiplied by browser-rejoin loops, the database accumulates orphans rapidly.

**Why it happens:** Lobby is unauthenticated; the channel can't tell "first join" from "rejoin after disconnect" without a stable client-side identifier.

**How to avoid:** Two options, both compliant with CONTEXT.md:

(a) **Accept it as documented** — CONTEXT.md D-04 explicitly accepts orphan rows in Phase 28 ("Orphan Conversation rows are acceptable for Phase 28. No cleanup job is in scope."). The TTL reaper is deferred.

(b) **Reuse Conversation across reconnects on the SAME socket** — store `conversation_id` in `socket.assigns` once on first join; on subsequent rejoins, return the cached id. **But:** rejoin creates a new socket process, so `socket.assigns` is lost. The hook would need to pass `conversation_id` in the join payload on reconnect, and `join/3` would need a "reuse if provided" branch. This is more than CONTEXT.md scope.

The planner should stay with option (a) and add a note in the README that the example app may accumulate orphan rows in long-running dev sessions. A `mix run -e "Cairnloop.Repo.delete_all(...)"` cleanup snippet could be documented.

**Warning signs:** Operator sees the InboxLive list grow with empty-conversation rows whenever the customer's `/chat` tab reconnects. Acceptable for the demo per D-04, but worth a one-sentence README mention.

### Pitfall 6: `Cairnloop.Chat.create_customer_conversation/1` host_user_id collision

**What goes wrong:** D-04 sets `host_user_id` on the Conversation row to the socket token, which is `"demo_customer"` per CONTEXT.md specifics §121. The example app's `DemoContextProvider` is configured for `host_user_id: "demo_operator"` (router.ex:20 and config.exs:66 region) — the customer's host_user_id is different. If `ConversationLive` loads the customer's conversation and tries to fetch host_context for `host_user_id: "demo_customer"`, the provider returns `{:ok, %{}}` (no context for that id), which is rendered as the "No customer context yet" branch (conversation_live.ex:870-873). This is the **correct** behavior for v1 — there's no real customer profile to fetch — but the planner should confirm it doesn't crash.

**How to avoid:** No code change; this is correct behavior. The planner should verify by mentally walking through `ConversationLive.mount/3` → `reload_conversation_with_context/2` → `load_host_context/1` with `host_user_id: "demo_customer"` and confirming the `%{}, nil` empty-context path returns cleanly. Confirmed during research: yes, this works (chat.ex doesn't fail; `DefaultContextProvider` returns `{:ok, %{}}` for unknown ids).

**Warning signs:** Crashes only if a custom `ContextProvider` raises on unknown `host_user_id`. The demo provider doesn't.

### Pitfall 7: `optimistic append` race with PubSub-driven append

**What goes wrong:** D-13 says the LV optimistically appends the customer message to `@messages` on `phx-submit="send_message"`. The same message ALSO arrives via PubSub `{:message_created, msg_id}` after `ProcessMessage.perform/1` writes it. Without dedup, the customer sees their own message twice.

**Why it happens:** Two write paths for the same message: optimistic (LV-local state) and PubSub-driven (canonical DB row).

**How to avoid:** In ChatLive's `handle_info({:message_created, msg_id}, socket)`, when the inbound message's `role: :user`, check whether `@messages` already contains a matching optimistic entry (e.g., by content+timestamp window) and skip the append. Cleaner: only append messages with `role: :agent` (operator replies) — customer's own messages stay optimistic-only. This matches the UI-SPEC's data model where the customer never re-renders their own message from server state.

The planner must pick one approach and lock it. Recommendation: **dedup by role** — handle_info only appends `role: :agent` messages. Customer messages stay optimistic and never flow back through PubSub to the customer's own ChatLive (the broadcast still happens for the operator's side).

Implementation: subscribe ChatLive to `"conversation:#{id}"`, but `handle_info({:message_created, msg_id}, socket)` first fetches the message and discards if `role: :user` AND `inserted_at` is within ~5 seconds of the last optimistic append. Alternatively, broadcast a more specific event from `reply_to_conversation/4` like `{:operator_reply, msg_id}` and let ChatLive handle only that shape — clearer separation. The planner should pick the cleaner shape.

**Warning signs:** Customer types "hello" and sees "hello" appear twice. Headless `Phoenix.LiveViewTest` can simulate by manually broadcasting after `render_submit/2` and asserting `@messages` length stays at 1.

## Code Examples

### Example 1: `Cairnloop.Chat.create_customer_conversation/1`

```elixir
# Source: derived from chat.ex:25-147 pattern (in-repo)
def create_customer_conversation(attrs) when is_map(attrs) do
  changeset = Cairnloop.Conversation.changeset(%Cairnloop.Conversation{}, %{
    status: :open,
    host_user_id: Map.fetch!(attrs, :host_user_id),
    subject: Map.get(attrs, :subject, "Customer chat")
  })

  case repo().insert(changeset) do
    {:ok, conversation} ->
      # D-06 partial: also broadcast :conversations_changed so InboxLive reloads.
      Phoenix.PubSub.broadcast(
        Cairnloop.PubSub,
        "conversations",
        {:conversations_changed}
      )
      {:ok, conversation}

    {:error, _changeset} = error ->
      error
  end
end

defp repo, do: Application.fetch_env!(:cairnloop, :repo)
```

### Example 2: `Cairnloop.Chat.ingest_widget_message/2`

```elixir
# Source: derived from draft_worker.ex:103-114 broadcast pattern + chat.ex Message insert pattern
def ingest_widget_message(conversation_id, content) when is_binary(content) do
  changeset = Cairnloop.Message.changeset(%Cairnloop.Message{}, %{
    conversation_id: conversation_id,
    content: content,
    role: :user
  })

  case repo().insert(changeset) do
    {:ok, message} ->
      # Post-commit broadcasts (D-08, pattern from draft_worker.ex:103)
      Phoenix.PubSub.broadcast(
        Cairnloop.PubSub,
        "conversation:#{conversation_id}",
        {:message_created, message.id}
      )

      Phoenix.PubSub.broadcast(
        Cairnloop.PubSub,
        "conversations",
        {:conversations_changed}
      )

      {:ok, message}

    {:error, _changeset} = error ->
      error
  end
end
```

### Example 3: `ProcessMessage.perform/1` rewrite

```elixir
# Source: rewrites lib/cairnloop/workers/process_message.ex per D-07
defmodule Cairnloop.Workers.ProcessMessage do
  use Oban.Worker,
    queue: :default,
    unique: [period: 30, fields: [:worker, :args], keys: [:conversation_id, :content]]

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"channel" => "widget", "conversation_id" => id, "content" => content}
      }) do
    case Cairnloop.Chat.ingest_widget_message(id, content) do
      {:ok, _message} -> :ok
      {:error, _changeset} -> :error
    end
  end

  # Pitfall 2: preserve email-channel arg shape from EmailWebhookPlug.
  def perform(%Oban.Job{args: %{"channel" => "email", "content" => content}}) do
    require Logger
    Logger.info("Processed email message: #{content}")
    :ok
  end
end
```

### Example 4: `WidgetChannel.join/3` + `handle_in("new_message", ...)` rewrite

```elixir
# Source: rewrites lib/cairnloop/channels/widget_channel.ex per D-01 + D-07
def join("widget:lobby", _payload, socket) do
  token = socket.assigns[:user_token]

  case Cairnloop.Chat.create_customer_conversation(%{host_user_id: token}) do
    {:ok, conversation} ->
      socket =
        socket
        |> assign(:conversation_id, conversation.id)

      {:ok, %{conversation_id: conversation.id}, socket}

    {:error, _changeset} ->
      {:error, %{reason: "could_not_create_conversation"}}
  end
end

# Existing conversation-scoped join clause preserved (deferred specifics §122)
def join("widget:" <> _private_room_id, _payload, socket) do
  if socket.assigns[:user_token], do: {:ok, socket}, else: {:error, %{reason: "unauthorized"}}
end

@impl true
def handle_in("new_message", %{"content" => content}, socket) do
  conversation_id = socket.assigns[:conversation_id]

  %{channel: "widget", conversation_id: conversation_id, content: content}
  |> Cairnloop.Workers.ProcessMessage.new()
  |> Oban.insert()

  {:reply, :ok, socket}
end

# submit_csat clause preserved unchanged.
def handle_in("submit_csat", %{"rating" => rating}, socket) do
  "widget:" <> conversation_id = socket.topic
  # ... unchanged ...
end
```

### Example 5: `ChatLive` (sketch — full ~150 LOC in plan)

```elixir
# Source: rewrites examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex
defmodule CairnloopExampleWeb.ChatLive do
  use CairnloopExampleWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:channel_status, :connecting)
      |> assign(:pending, false)
      |> assign(:conversation_id, nil)

    {:ok, socket}
  end

  def handle_event("conversation_id", %{"id" => id}, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
    end

    {:noreply, socket |> assign(:conversation_id, id) |> assign(:channel_status, :connected)}
  end

  def handle_event("channel_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :channel_status, String.to_atom(status))}
  end

  def handle_event("send_message", %{"message" => text}, socket) when is_binary(text) and text != "" do
    optimistic =
      %{role: :customer, content: text, inserted_at: DateTime.utc_now()}

    socket =
      socket
      |> assign(:messages, socket.assigns.messages ++ [optimistic])
      |> assign(:pending, true)
      |> push_event("widget:send", %{content: text})

    {:noreply, socket}
  end

  # Pitfall 7 dedup: only append :agent role from PubSub
  def handle_info({:message_created, msg_id}, socket) do
    case load_message_for_chat(msg_id) do
      %{role: :agent} = msg ->
        appended = socket.assigns.messages ++ [
          %{role: :operator, content: msg.content, inserted_at: msg.inserted_at}
        ]
        {:noreply, socket |> assign(:messages, appended) |> assign(:pending, false)}

      _ ->
        {:noreply, socket}
    end
  end

  # render/1 with colocated hook — see Pattern 3 above for skeleton
end
```

### Example 6: Operator-reply broadcast hook into `reply_to_conversation/4`

```elixir
# Source: ADDS a post-commit broadcast to chat.ex:144-146 success branch.
# This is the open question OQ-1 fix.

result = repo().transaction(multi)

# Add this just before `{result, meta}`:
case result do
  {:ok, %{message: message}} ->
    Phoenix.PubSub.broadcast(
      Cairnloop.PubSub,
      "conversation:#{conversation.id}",
      {:message_created, message.id}
    )
    :ok

  _ ->
    :ok
end

{result, meta}
```

### Example 7: Colocated WidgetChat hook (full sketch)

```elixir
~H"""
<script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">
  import {Socket} from "phoenix"

  export default {
    mounted() {
      const token = this.el.dataset.token || "demo_customer"
      const socket = new Socket("/widget", {params: {token}})
      this.socket = socket
      socket.connect()

      socket.onOpen(() => this.pushEvent("channel_status", {status: "connected"}))
      socket.onError(() => this.pushEvent("channel_status", {status: "disconnected"}))
      socket.onClose(() => this.pushEvent("channel_status", {status: "disconnected"}))

      this.channel = socket.channel("widget:lobby", {})
      this.channel.join()
        .receive("ok", ({conversation_id}) => {
          this.pushEvent("conversation_id", {id: conversation_id})
        })
        .receive("error", () => {
          this.pushEvent("channel_status", {status: "disconnected"})
        })

      this.handleEvent("widget:send", ({content}) => {
        if (!this.channel) return
        this.channel.push("new_message", {content})
          .receive("error", () => this.pushEvent("channel_status", {status: "disconnected"}))
      })
    },
    destroyed() {
      if (this.channel) this.channel.leave()
      if (this.socket) this.socket.disconnect()
    }
  }
</script>
"""
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate `assets/js/hooks/widget_chat.js` file imported in `app.js` | Colocated hook via `<script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">` | Phoenix LiveView 1.1 (2025) | Hook code lives alongside the LV that uses it; auto-extracted at compile time; no manual hook registry maintenance |
| Manual JS channel state machine | `phoenix.js` `Socket` callbacks (`onOpen`/`onError`/`onClose`) + `channel.join().receive(...)` | Phoenix 1.0+ | Built-in auto-reconnect, exponential backoff, heartbeats |
| LV → Hook via DOM `data-*` attribute mutation | `push_event/3` (server) + `this.handleEvent/2` (client) | Phoenix LiveView 0.18+ | Explicit, audited communication channel; supports payloads of any JSON-serializable shape |
| Hook → LV via window globals or custom events | `this.pushEvent("event_name", payload)` + `handle_event/3` (server) | Phoenix LiveView 0.15+ | Same pattern as `phx-click`/`phx-submit`; no extra plumbing |
| Inline message broadcasts inside `Ecto.Multi` | Post-commit broadcast in worker's `:ok` branch | Cairnloop Phase 16 D16-11 (carried decision in STATE.md) | Avoids broadcasts on rolled-back transactions; consistent across DraftWorker / ToolExecutionWorker |

**Deprecated/outdated:**
- The 51-LOC mock `Process.send_after(self(), :bot_reply, 1000)` in `chat_live.ex:42` — pre-Phase-28 placeholder; removed entirely per CHAT-02.
- Direct DOM manipulation for live updates — replaced by LV's `push_event/3`.
- Mocking `WidgetChannel` interaction with `%Phoenix.Socket{}` direct struct (`test/cairnloop/channels/widget_channel_test.exs:33`) — works for unit tests of pure `handle_in/3` clauses but does NOT exercise the full socket pipeline; the integration test should use `Phoenix.ChannelTest` proper.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Cairnloop.PubSub` is NOT started in the example app today (so Phase 28 must add it). | Pitfall 1 | Low — if already running via some boot path I missed, the planner's "add PubSub to children" task becomes a no-op (safe). If NOT running and we don't add it, the entire operator-side LiveView crashes at subscribe. The planner MUST verify by running the example app once before plan acceptance. [ASSUMED] |
| A2 | `reply_to_conversation/4` does NOT currently broadcast `:message_created`. | Pitfall 3 | High — if I'm wrong, my recommended additive broadcast would double-broadcast. Verified by grep: `grep -n "broadcast" lib/cairnloop/chat.ex` returns nothing. [VERIFIED: grep against chat.ex] |
| A3 | Colocated hook needs `import {Socket} from "phoenix"` inside its `<script>` tag. | Pitfall 4 | Medium — if Phoenix's ColocatedHook manifest auto-resolves the `phoenix` import from the parent module, my advice is over-cautious but harmless. If it doesn't, the hook fails at runtime. Verify during implementation by checking the compiled `_build/.../phoenix-colocated/.../WidgetChat.js` file. [ASSUMED — based on training data behavior of ES module isolation] |
| A4 | Customer's optimistic message will collide with the PubSub-driven broadcast on the same client. | Pitfall 7 | Medium — Confirmed via code review: ChatLive will subscribe to `"conversation:#{id}"`, and `ingest_widget_message/2` broadcasts `{:message_created, msg_id}` on that topic. ChatLive's hook process is one of the subscribers. So yes, the customer would receive their own message back as a broadcast. The dedup recommendation stands. [VERIFIED: traced through D-06 + D-02 code paths] |
| A5 | `DemoContextProvider` returns `{:ok, %{}}` for unknown `host_user_id` like `"demo_customer"`. | Pitfall 6 | Low — verified by reading `load_host_context/1` at conversation_live.ex:856-868: it catches `{:error, reason}` and falls back to `%{}, nil`. Even if the provider raises, it would crash a customer's conversation rendering, not the customer's `/chat` LV (different LV process). [VERIFIED: code path traced] |
| A6 | `EmailWebhookPlug` is the only other caller of `ProcessMessage.new`. | Pitfall 2 | Low — ripgrep confirmed exactly two callers: `widget_channel.ex:23` and `email_webhook_plug.ex:19`. No tests outside the channel test reference ProcessMessage. [VERIFIED: ripgrep] |
| A7 | The example app starts `CairnloopExample.PubSub` ONLY (verified by reading application.ex:11-20). | Standard Stack, Pitfall 1 | Low — verified. [VERIFIED: examples/.../application.ex:14] |
| A8 | The `chimeway` test-host dep does not silently start `Cairnloop.PubSub`. | Pitfall 1 | Medium — chimeway only starts its own Repo per `config/test.exs:58-65`. No evidence it touches PubSub. The planner should run `iex -S mix phx.server` in the example app and `Process.whereis(Cairnloop.PubSub)` to be sure before/after the Phase 28 supervisor edit. [ASSUMED — checked config but not exhaustively] |

**If this table is empty:** N/A — multiple assumptions need planner confirmation.

## Open Questions

1. **OQ-1: How does the operator's reply reach the customer's `/chat` LV?**
   - What we know: D-02 says ChatLive subscribes to `"conversation:#{id}"`. D-06 only adds `{:message_created, ...}` broadcasts inside `ingest_widget_message/2` (customer-inbound path). The operator's reply goes through `Chat.reply_to_conversation/4`, which **does not broadcast today**.
   - What's unclear: CONTEXT.md doesn't explicitly add a broadcast to `reply_to_conversation/4`. UI-SPEC interaction step 11 says "Customer's `ChatLive` receives the broadcast" but doesn't name the emit point.
   - Recommendation: **Add an additive `{:message_created, msg_id}` broadcast to `reply_to_conversation/4`'s `:ok` branch** (Example 6 above). This is the minimum change and consistent with the post-commit broadcast pattern. Alternatively, broadcast `{:operator_reply, msg_id}` with a separate shape to make the customer-vs-operator dedup explicit (Pitfall 7 alternative). Planner must lock one shape during the planning step.

2. **OQ-2: Should `EmailWebhookPlug` also create a Conversation, or stay as a stub?**
   - What we know: D-07 reshapes ProcessMessage args. Email plug still passes the old shape.
   - What's unclear: Phase 28's scope is the widget ingress. The email plug is sealed-but-stub code. Updating it is OUT of phase scope but the args mismatch must be handled.
   - Recommendation: **Pattern-match in ProcessMessage** (Example 3 above) — preserves the existing email-stub behavior unchanged and unblocks the widget path. Document in code comment that email-channel handling is a future phase.

3. **OQ-3: Hook reconnect behavior — single or multiple Conversations?**
   - What we know: D-04 accepts orphan conversations on rejoin.
   - What's unclear: Multiple orphans per `/chat` page-refresh may make the demo look noisier than intended (16 conversations from Phase 27 + N orphans per dev session).
   - Recommendation: Keep D-04 as locked. Add a one-sentence note in the README that long-running dev sessions accumulate orphan rows.

4. **OQ-4: Channel topic — stay on `"widget:lobby"` or rejoin to `"widget:#{id}"`?**
   - What we know: CONTEXT.md specifics §122 says rejoin is optional and deferred to Phase 31 if needed.
   - What's unclear: `WidgetChannel.handle_in("submit_csat", ...)` (widget_channel.ex:30-39) expects topic `"widget:#{conversation_id}"` and destructures via `"widget:" <> conversation_id = socket.topic`. If the customer never leaves lobby, `submit_csat` from `/chat` would fail (topic is `"widget:lobby"`, destructure yields `"lobby"` instead of the real id).
   - Recommendation: Phase 28 does not exercise CSAT from `/chat`, so this is fine for now. The planner should add a comment in the channel module noting that CSAT requires the conversation-scoped topic and is deferred per CONTEXT.md §122.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All compilation | ✓ | 1.19 (mix.exs:7) | — |
| Postgres + pgvector | Conversation/Message inserts (live demo); integration tests | ✓ (assumed in dev) per CLAUDE.md "REPO-UNAVAILABLE" caveat | 16+ | Headless tests use `MockRepo` per chat_test.exs:6 pattern |
| Oban | Async ProcessMessage worker | ✓ | 2.17 | — |
| Phoenix LiveView 1.1 | Colocated hooks | ✓ | 1.1.0 | — |
| esbuild + tailwind | Asset pipeline for colocated hook | ✓ | esbuild 0.25.4, tailwind 4.1.12 | — |
| Node / npm | None — no npm packages added | N/A | — | — |
| `Cairnloop.PubSub` registry | Library broadcasts | ✗ **NOT STARTED IN EXAMPLE APP TODAY** (per Pitfall 1) | — | Phase 28 must add it to the example app supervisor |

**Missing dependencies with no fallback:**
- `Cairnloop.PubSub` is missing in the example app — must be added (Pitfall 1).

**Missing dependencies with fallback:**
- Live Postgres for headless tests: use `MockRepo` per existing chat_test.exs pattern.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) + Phoenix.LiveViewTest 1.1.0 + Phoenix.ChannelTest |
| Config file | `mix.exs` aliases (root + example app); `test/test_helper.exs` (root); `examples/cairnloop_example/test/test_helper.exs` |
| Quick run command | `mix test` (root library; headless, no DB) |
| Full suite command | `mix test.integration` (root library; DB-backed) + example app `mix test` |
| Headless test convention | Inject `MockRepo` via `Application.put_env(:cairnloop, :repo, MockRepo)` in `setup` block; mock the Multi reducer (see chat_test.exs:6-75 for canonical pattern) |
| Tagging | `:integration` for DB-backed tests; `# REPO-UNAVAILABLE` comment per CLAUDE.md when local Repo is missing |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHAT-01 | Endpoint mounts `WidgetSocket` at `/widget` | unit (compile check + grep test) | `mix compile --warnings-as-errors` + `grep "Cairnloop.Channels.WidgetSocket" examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` | ❌ Wave 0 — add grep assertion to a new `endpoint_test.exs` or include in existing test suite |
| CHAT-02 | `chat_live.ex` no longer references `Process.send_after` | unit (grep + LiveViewTest) | `grep -L "Process.send_after" examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` returns the file path (negative grep) | ❌ Wave 0 — new headless test in `chat_live_test.exs` |
| CHAT-02 | `ChatLive` optimistically appends customer message on submit | unit | `mix test examples/cairnloop_example/test/.../chat_live_test.exs:test_optimistic_append` | ❌ Wave 0 |
| CHAT-02 | `ChatLive` appends `:agent` role message from PubSub | unit | `mix test .../chat_live_test.exs:test_handle_info_message_created` | ❌ Wave 0 |
| CHAT-02 | `WidgetChannel.join("widget:lobby", _, _)` creates Conversation + replies with conversation_id | unit + integration | `mix test test/cairnloop/channels/widget_channel_test.exs:test_join_creates_conversation` | ⚠️ extend existing |
| CHAT-02 | `WidgetChannel.handle_in("new_message", ...)` enqueues ProcessMessage with conversation_id | unit | `mix test test/cairnloop/channels/widget_channel_test.exs:test_handle_in_enqueues_with_id` | ⚠️ extend existing |
| CHAT-02 | `Cairnloop.Chat.create_customer_conversation/1` inserts Conversation row with host_user_id from token | unit | `mix test test/cairnloop/chat_test.exs:test_create_customer_conversation` | ⚠️ extend existing |
| CHAT-02 | `Cairnloop.Chat.ingest_widget_message/2` inserts :user-role Message + broadcasts twice | unit | `mix test test/cairnloop/chat_test.exs:test_ingest_widget_message_broadcasts` | ❌ Wave 0 |
| CHAT-02 | `ProcessMessage.perform/1` on widget args calls `Chat.ingest_widget_message/2` | unit (headless, via mock Chat) | `mix test test/cairnloop/workers/process_message_test.exs` | ❌ Wave 0 (file does not exist) |
| CHAT-02 | `ProcessMessage.perform/1` on email args preserves logger stub (Pitfall 2) | unit | `mix test test/cairnloop/workers/process_message_test.exs:test_email_branch` | ❌ Wave 0 |
| CHAT-02 | `InboxLive.handle_info({:conversations_changed}, …)` reloads + prunes | unit | `mix test test/cairnloop/web/inbox_live_test.exs:test_handle_info_conversations_changed` | ⚠️ extend existing (if file exists) |
| CHAT-02 | `ConversationLive.handle_info({:message_created, _}, …)` reloads | unit | `mix test test/cairnloop/web/conversation_live_test.exs:test_handle_info_message_created` | ⚠️ extend existing |
| CHAT-02 | `reply_to_conversation/4` post-commit broadcast (OQ-1 fix) | unit | `mix test test/cairnloop/chat_test.exs:test_reply_broadcasts_message_created` | ❌ Wave 0 |
| CHAT-02 | Full round trip: customer message → DB → operator inbox → operator reply → customer ChatLive | integration | `mix test.integration test/integration/widget_round_trip_test.exs` | ❌ Wave 0 (Phase 31 may own this) |
| CHAT-03 | README contains the locked two-tab demo prose | unit (grep) | `grep -q "Two-Tab Demo" examples/cairnloop_example/README.md` and content matches UI-SPEC §3 verbatim | ❌ Wave 0 |
| Env gap | Example app starts `Cairnloop.PubSub` (Pitfall 1) | smoke (compile + boot) | `iex -S mix phx.server` (manual) OR `mix test examples/cairnloop_example/test/...application_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors && mix test` (root). For example app changes: `cd examples/cairnloop_example && mix compile --warnings-as-errors && mix test`.
- **Per wave merge:** Both `mix test` lanes + `mix test.integration` if Postgres is available.
- **Phase gate:** `mix compile --warnings-as-errors` clean, `mix test` green in both root and example app, and manual smoke of the two-tab demo with `mix phx.server`. Per CLAUDE.md "**Warnings-clean builds are mandatory**" and "Run `mix test` before declaring work done."

### Wave 0 Gaps
- [ ] `test/cairnloop/workers/process_message_test.exs` — new file, covers widget + email branches of `perform/1`
- [ ] Extend `test/cairnloop/channels/widget_channel_test.exs` — add join-creates-conversation + handle_in-uses-conversation-id tests. Currently uses `%Phoenix.Socket{}` direct stub; this is fine for `handle_in` but the new `join/3` needs either the same stub pattern OR `use Phoenix.ChannelTest` for one new test
- [ ] Extend `test/cairnloop/chat_test.exs` — add `describe "create_customer_conversation/1"` + `describe "ingest_widget_message/2"` + `describe "reply_to_conversation broadcast (OQ-1)"` test groups
- [ ] `examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs` — new file, covers ChatLive mount + handle_event + handle_info + negative grep for Process.send_after
- [ ] Extend `test/cairnloop/web/inbox_live_test.exs` if it exists; otherwise spec the handle_info as a new test
- [ ] Extend `test/cairnloop/web/conversation_live_test.exs` if it exists; otherwise spec the new handle_info clause
- [ ] Optional: `examples/cairnloop_example/test/cairnloop_example/application_test.exs` — assert `Cairnloop.PubSub` is in the supervisor children (Pitfall 1 lock)
- [ ] README grep test for "Two-Tab Demo" prose match (CHAT-03)

*(No new test framework installs needed — ExUnit + Phoenix.LiveViewTest + Phoenix.ChannelTest all already in deps.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Demo mode accepts any binary token per `widget_socket.ex:10-13`. Production adopters bring their own token verification; that's a vM015+ concern documented in WidgetSocket. |
| V3 Session Management | partial | Channel session lives in `socket.assigns[:user_token]` and `socket.assigns[:conversation_id]`. No cross-tab session sharing. Phoenix's built-in CSRF token already in `_csrf_token` LV param (app.js:31). |
| V4 Access Control | yes | `WidgetChannel.join/3`'s second clause (private rooms) checks `socket.assigns[:user_token]`. For Phase 28 lobby join, ANY binary token is accepted (demo mode). The conversation_id stored on the socket prevents cross-conversation message injection — `handle_in("new_message", ...)` reads `conversation_id` from `socket.assigns`, never from the payload. |
| V5 Input Validation | yes | `Message.changeset/2` validates `content`, `role`, `conversation_id` per message.ex:23. `Conversation.changeset/2` validates `status` per conversation.ex:24. Hook does NOT trust user input for the conversation_id — it only relays the server-issued id back to the LV. |
| V6 Cryptography | no | No crypto introduced. Demo token is plain text per CONTEXT.md specifics §121. |
| V7 Error Handling and Logging | yes | Per CLAUDE.md "Operator copy is calm, fail-closed, reason-forward, honest — never raw Elixir terms / raw JSON to operators." UI-SPEC copywriting contract (lines 183-198) locks all customer-facing error strings. |
| V12 File and Resources | no | No file uploads, no resource access in this phase. |

### Known Threat Patterns for Phoenix Channels + LiveView

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Customer crafts payload with arbitrary `conversation_id` to inject messages into other customers' threads | Tampering / Elevation | Server reads `conversation_id` from `socket.assigns` (set during `join/3`), NEVER from `handle_in` payload. WidgetChannel rewrite per D-07 already does this. |
| Customer sends malformed `content` (script, oversized payload) | Tampering | Phoenix.PubSub + Ecto changeset validation. Future: add `validate_length(:content, max: 10_000)` to `Message.changeset/2` — out of Phase 28 scope but a known follow-up. |
| Long-lived socket attempts to enumerate other conversations via `widget:N` joins | Information Disclosure | `WidgetChannel.join("widget:" <> id, …)` currently authorizes any authenticated user. This is a known v1 limitation per the existing comment at widget_channel.ex:10. Phase 28 stays on `widget:lobby` and does not change this. Tighten in a future host-integration phase. |
| Customer message broadcast leaks to wrong subscribers | Information Disclosure | PubSub topics are namespaced per `"conversation:#{id}"`. Two customers on different conversation_ids cannot cross-subscribe. |
| Auto-reconnect rejoin creates duplicate Conversation rows (orphan accumulation, DoS angle) | Denial of Service | D-04 accepts orphans for Phase 28; TTL reaper deferred. Production adopters should add a reaper. |
| Reflected XSS via message content in `/chat` render | Tampering | Phoenix HEEx auto-escapes all `<%= %>` interpolations. UI-SPEC §1b mandates `<%= msg.content %>` (escaped). |
| CSRF on WebSocket connect | Tampering | Phoenix Socket connect uses the same `_csrf_token` flow as LiveView (set in `app.js:31`). For `/widget`, the `params` route through `WidgetSocket.connect/3` which doesn't validate CSRF — by design, customer widgets are typically embedded cross-origin. For an in-same-app demo this is acceptable. |

## Project Constraints (from CLAUDE.md)

The planner MUST observe these directives — they have the same authority as CONTEXT.md locked decisions:

1. **Decision policy: shift-left** — Decide for the user. Do NOT surface options that can be researched and resolved. CONTEXT.md already exercises this — every D-01..D-17 is a decision, not a question.
2. **Warnings-clean builds are mandatory** — `mix compile --warnings-as-errors` must pass at every commit. Every plan task that touches code must verify this.
3. **`mix test` before declaring done** — both root and example app. Report failures honestly with output.
4. **`Cairnloop.Repo` may be unavailable** — prefer headless/pure tests. DB-requiring tests get `# REPO-UNAVAILABLE` comment if they cannot run locally.
5. **Durable Ecto + events are workflow truth; `:telemetry` is observability only** — message creation goes through `Chat.ingest_widget_message/2` (DB write), not through telemetry events. PubSub is for UI signaling, not for workflow truth.
6. **Reads go through the narrow `Cairnloop.Governance` facade, not direct schema queries from the web layer** — Phase 28 reads go through `Cairnloop.Chat`, which is the chat-equivalent narrow facade. No direct `Repo.get` from chat_live.ex or inbox_live.ex.
7. **Snapshot trust facts at decision time; never re-read live config at render time** — `@channel_status` is the snapshot; the LV does not re-read socket state on every render.
8. **Seal completed phases** — `reply_to_conversation/4` is sealed code. Adding a post-commit broadcast (OQ-1 fix) is additive — does not change the contract or idempotency semantics. The planner must justify this as "additive, not churn" in the plan acceptance gate.
9. **Operator copy: calm, fail-closed, reason-forward, honest** — UI-SPEC copywriting contract (lines 183-198) locks every string. The planner must enforce this verbatim. Specifically, no "AI is thinking", "Bot is typing", "Ticket submitted", "Agent will reply" copy per UI-SPEC line 199.
10. **Brand tokens over hardcoded hex** — Inline `var(--cl-<token>, #<hex-fallback>)` is the current convention; Phase 29 will drop the hex fallback. Phase 28 USES the existing convention (hex fallback present) per UI-SPEC.
11. **Never state-by-color-alone (brand §7.5)** — Channel state indicator pairs dot + label per UI-SPEC §1a. Send button disabled state uses both `disabled` attribute and `opacity-50` per UI-SPEC accessibility.
12. **GSD subagents read CLAUDE.md** — this RESEARCH.md propagates the constraints so the planner doesn't have to re-discover them.

## Sources

### Primary (HIGH confidence)
- `lib/cairnloop/channels/widget_socket.ex` — Socket connect + id behavior. [In-repo, verified]
- `lib/cairnloop/channels/widget_channel.ex` — Existing join + handle_in clauses; pattern for `submit_csat` topic destructuring. [In-repo, verified]
- `lib/cairnloop/workers/process_message.ex` — Current stub-logger state; target for rewrite per D-07. [In-repo, verified]
- `lib/cairnloop/chat.ex` — Existing facade; `repo()` indirection at line 6; `reply_to_conversation/4` at line 25 (DraftWorker side effects for `:user` role); has no current broadcast. [In-repo, verified]
- `lib/cairnloop/web/conversation_live.ex:13-16` — Mount-time PubSub subscribe pattern; lines 26-39 handle_info clauses to mirror for D-17. [In-repo, verified]
- `lib/cairnloop/web/inbox_live.ex:80-107` — `mount/3` with WR-02 "subscribe here when pubsub becomes load-bearing" comment, and `prune_selected_ids/2` at line 568. [In-repo, verified]
- `lib/cairnloop/automation/workers/draft_worker.ex:101-114` — Canonical post-commit broadcast pattern. [In-repo, verified]
- `lib/cairnloop/workers/tool_execution_worker.ex:573-600` — Defensive broadcast (try/rescue) pattern; D-08 reference. [In-repo, verified]
- `lib/cairnloop/ingress/email_webhook_plug.ex:19` — Silent second caller of `ProcessMessage.new` (Pitfall 2). [In-repo, verified]
- `examples/cairnloop_example/lib/cairnloop_example/application.ex:11-20` — Supervisor only starts `CairnloopExample.PubSub` (Pitfall 1). [In-repo, verified]
- `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex:14-16` — Existing `/live` socket mount, placement template for `/widget` socket per D-15. [In-repo, verified]
- `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` — Full 51-LOC mock to replace. [In-repo, verified]
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex:17-36` — Operator routes under `/support`, customer route at `/chat`. [In-repo, verified]
- `examples/cairnloop_example/assets/js/app.js:23` — `Socket` import + colocated hooks wiring. [In-repo, verified]
- `examples/cairnloop_example/assets/css/app.css:6-22, 113-119` — Existing brand tokens (Phase 29 will expand); `phx-submit-loading` variant available. [In-repo, verified]
- `examples/cairnloop_example/mix.exs:40-71` — Confirms phoenix 1.8.7, phoenix_live_view 1.1.0 in deps. [In-repo, verified]
- `mix.exs:83-103` — Library deps; phoenix_live_view ~> 1.0, oban ~> 2.17. [In-repo, verified]
- `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex:1-100` — Canonical ColocatedHook docs. [In-repo dep, verified]
- `test/cairnloop/chat_test.exs:6-75` — MockRepo + Multi reducer pattern for headless Chat tests. [In-repo, verified]
- `test/cairnloop/channels/widget_channel_test.exs` — Existing channel test pattern using `%Phoenix.Socket{}` direct stub. [In-repo, verified]
- `test/test_helper.exs:21-32` — Integration suite starts `Cairnloop.PubSub` explicitly; example app does NOT. [In-repo, verified]
- `config/test.exs:42-48` — Library test endpoint uses `pubsub_server: Cairnloop.PubSub`. [In-repo, verified]
- `examples/cairnloop_example/config/config.exs:25-27` — Example endpoint uses `pubsub_server: CairnloopExample.PubSub`. [In-repo, verified]
- `.planning/STATE.md` — Carried decisions: D16-11 post-commit broadcast, vM014 test harness, additive-only invariant. [In-repo, verified]
- `.planning/phases/28-customer-chat-wired-to-real-ingress/28-CONTEXT.md` — User decisions D-01..D-17. [In-repo, verified]
- `.planning/phases/28-customer-chat-wired-to-real-ingress/28-UI-SPEC.md` — Visual + interaction contract. [In-repo, verified]
- `.planning/REQUIREMENTS.md` — CHAT-01/CHAT-02/CHAT-03 wording. [In-repo, verified]

### Secondary (MEDIUM confidence)
- Phoenix Channels docs (training data) — `Socket`, `Channel`, `push/3`, `receive/2` semantics. Confirmed against repo's `phoenix.js` import patterns. Knowledge cutoff Jan 2026.
- Phoenix LiveView `push_event/3` + `handleEvent` JS API — confirmed against `lib/cairnloop/web/conversation_live.ex` and other in-repo LV files (no other in-repo `push_event` usage found — the LV→Hook direction is new to this phase, MEDIUM confidence on the JS-side `this.handleEvent` listener attachment exactly mirroring training data).
- Phoenix.ChannelTest API — `connect/2`, `subscribe_and_join/4`, `push/3`, `assert_reply/3`. Not currently used in-repo (the existing test stubs `%Phoenix.Socket{}` directly), but a known-good pattern for integration tests.

### Tertiary (LOW confidence)
- ColocatedHook ES module import resolution (Pitfall 4) — based on training-data understanding of ES module isolation; not verified against current bundler output in this repo. Planner should confirm by checking `_build/.../phoenix-colocated/.../WidgetChat.js` after a `mix compile`.
- Whether `Cairnloop.PubSub` is silently started by some boot path I missed (Pitfall 1 / A1) — verified by reading every supervisor child list and `Application.start/2` callback I could find, but the planner should empirically confirm with `Process.whereis(Cairnloop.PubSub)` before locking the supervisor edit.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in deps, all versions in mix.exs.
- Architecture: HIGH — every component verified against in-repo files; the System Architecture Diagram is a literal trace of CONTEXT.md's decision flow.
- Pitfalls: HIGH — Pitfalls 1, 2, 3 are verified by code reading + grep; Pitfalls 4, 5, 6, 7 are MEDIUM (mix of code reading + reasoning about runtime behavior).
- Test surface: HIGH — every required test maps to an existing convention (chat_test.exs MockRepo, widget_channel_test.exs stub, LiveViewTest).
- Security: HIGH for the within-Phase-28 surface; MEDIUM for the broader WidgetChannel surface (private-room authorization is a known v1 limitation).

**Research date:** 2026-05-27
**Valid until:** 2026-06-26 (30 days — Phoenix/LiveView API stable; in-repo files only change via this milestone).
