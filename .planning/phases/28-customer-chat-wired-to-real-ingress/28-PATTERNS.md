# Phase 28: customer-chat-wired-to-real-ingress — Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 14 (8 production code, 1 endpoint, 1 supervisor, 1 README, 3 test surfaces aggregated as one entry each)
**Analogs found:** 13 / 14 (one file — the colocated JS hook block — has no prior in-repo analog; closest is `phoenix.js` doc + the LiveView `app.js` Socket import)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/chat.ex` (ADD `create_customer_conversation/1` + `ingest_widget_message/2`, MODIFY `reply_to_conversation/4` post-commit broadcast — OQ-1) | context-facade | CRUD + post-commit PubSub broadcast | `lib/cairnloop/chat.ex` (self — `reply_to_conversation/4` pattern lines 25-147) + `lib/cairnloop/automation/workers/draft_worker.ex:101-114` (post-commit broadcast canonical) | exact (self-pattern + sibling-worker broadcast pattern) |
| `lib/cairnloop/channels/widget_channel.ex` (MODIFY `join/3` lobby clause + `handle_in("new_message")`) | channel | event-driven (request-reply over WebSocket) | `lib/cairnloop/channels/widget_channel.ex` (self — `submit_csat` clause at line 30, existing `handle_in("new_message")` at line 20) | exact (self-pattern; topic destructure + Oban enqueue already established) |
| `lib/cairnloop/workers/process_message.ex` (REWRITE — D-07, multi-clause `perform/1`) | Oban worker | event-driven (queue consumer → context facade → PubSub) | `lib/cairnloop/automation/workers/draft_worker.ex:101-114` (post-commit broadcast); `lib/cairnloop/workers/process_message.ex` (self — current stub for `:email` branch shape) | exact (canonical "worker → context facade → broadcast" pattern) |
| `lib/cairnloop/web/conversation_live.ex` (ADD `handle_info({:message_created, _}, …)` clause — D-17) | LiveView (server) | pub-sub (PubSub → reload helper) | `lib/cairnloop/web/conversation_live.ex:26-39` (self — existing `{:draft_created, _}` / `{:tool_executed, _}` clauses) | exact (self-pattern; D-17 explicitly says "mirror exactly") |
| `lib/cairnloop/web/inbox_live.ex` (MODIFY `mount/3` to subscribe + ADD `handle_info({:conversations_changed}, …)` — D-09/D-10) | LiveView (server) | pub-sub (PubSub → list reload + prune) | `lib/cairnloop/web/conversation_live.ex:13-16` (subscribe in `connected?` block); `lib/cairnloop/web/inbox_live.ex:568-571` (`prune_selected_ids/2` already wired) | exact (subscribe pattern + already-wired prune helper) |
| `lib/cairnloop/ingress/email_webhook_plug.ex` (UNCHANGED — silent caller; ProcessMessage's email clause must preserve its existing args shape — Pitfall 2 / OQ-2) | plug | request-response | `lib/cairnloop/ingress/email_webhook_plug.ex` (self — line 18 is the args shape ProcessMessage must keep matching) | exact (no edit; pattern-match guard added in ProcessMessage) |
| `examples/cairnloop_example/lib/cairnloop_example/application.ex` (ADD `{Phoenix.PubSub, name: Cairnloop.PubSub}` — Pitfall 1) | supervisor | startup config | `examples/cairnloop_example/lib/cairnloop_example/application.ex:10-20` (self — existing `CairnloopExample.PubSub` child) | exact (one-line additive child) |
| `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` (ADD `socket "/widget", Cairnloop.Channels.WidgetSocket` — D-15) | endpoint | startup config | `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex:14-16` (self — existing `/live` socket) | exact (one-line, placed right after `/live` per D-15) |
| `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` (REWRITE 51-LOC mock → ~150-LOC real channel client + colocated hook) | LiveView (server) + colocated JS hook | event-driven (LV ↔ JS hook ↔ Phoenix channel ↔ PubSub) | `lib/cairnloop/web/conversation_live.ex:13-16` (PubSub subscribe); `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` (self — assigns shape + render scaffold); `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex` (canonical hook docs) | role-match (no prior colocated hook in this repo — see "No Analog Found") |
| `examples/cairnloop_example/README.md` (ADD "## Two-Tab Demo" block — CHAT-03) | docs | static | UI-SPEC §3 lines 161-176 (locked prose, verbatim) | exact (copy from spec; no code analog) |
| `test/cairnloop/chat_test.exs` (EXTEND — cover D-05, D-06, OQ-1 broadcast) | test | unit/headless | `test/cairnloop/chat_test.exs:1-120` (self — MockRepo + Multi reducer + `describe "reply_to_conversation/3"` block) | exact (self-pattern) |
| `test/cairnloop/channels/widget_channel_test.exs` (EXTEND — cover join-creates-conversation + handle_in passes conversation_id) | test | unit | `test/cairnloop/channels/widget_channel_test.exs:1-48` (self — MockRepo + `%Phoenix.Socket{}` direct stub) | exact (self-pattern) |
| `test/cairnloop/workers/process_message_test.exs` (NEW) | test | unit/headless | `test/cairnloop/workers/sla_countdown_worker_test.exs` / `test/cairnloop/workers/outbound_worker_test.exs` (sibling worker tests, same test/cairnloop/workers/ directory) | role-match (sibling worker test directory) |
| `examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs` (NEW) | test | unit (LiveViewTest) | `test/cairnloop/web/inbox_live_test.exs:1-65` (LiveViewTest + render_html + describe-block test layout) | role-match (LV test, but in example app rather than lib) |

---

## Pattern Assignments

### `lib/cairnloop/chat.ex` — ADD `create_customer_conversation/1` + `ingest_widget_message/2`, MODIFY `reply_to_conversation/4` post-commit broadcast

**Analog:** `lib/cairnloop/chat.ex` (self, lines 25-147) + `lib/cairnloop/automation/workers/draft_worker.ex` (lines 101-114) + `lib/cairnloop/workers/tool_execution_worker.ex` (lines 578-600 — defensive try/rescue broadcast).

**`repo()` indirection pattern** (chat.ex:6-8):
```elixir
defp repo do
  Application.fetch_env!(:cairnloop, :repo)
end
```
New facade functions MUST use this — no direct `Cairnloop.Repo` references. Same indirection lets `MockRepo` substitution work in headless tests.

**Post-commit broadcast pattern** (draft_worker.ex:101-114):
```elixir
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
Apply to:
- `create_customer_conversation/1`: after successful `repo().insert(changeset)`, broadcast `{:conversations_changed}` on topic `"conversations"`.
- `ingest_widget_message/2`: after successful `repo().insert(message_changeset)`, broadcast TWO messages — `{:message_created, message.id}` on `"conversation:#{conversation_id}"` AND `{:conversations_changed}` on `"conversations"`.
- `reply_to_conversation/4` (OQ-1): inside the existing `Telemetry.span` closure, after `result = repo().transaction(multi)`, pattern-match on `result`; for `{:ok, %{message: message}} = result`, broadcast `{:message_created, message.id}` on `"conversation:#{conversation.id}"` BEFORE `{result, meta}` returns. Additive to the sealed function, does not change the contract.

**Defensive broadcast variant** (tool_execution_worker.ex:580-588) — use when broadcast failure must not block the calling path:
```elixir
defp broadcast_executed(approval_id, proposal) do
  topic = "conversation:#{proposal.conversation_id}"

  try do
    Phoenix.PubSub.broadcast(Cairnloop.PubSub, topic, {:tool_executed, approval_id})
  rescue
    _ -> :ok
  end
end
```
**Recommendation for OQ-1 broadcast in `reply_to_conversation/4`:** wrap in `try/rescue _ -> :ok` so that any PubSub-missing-registry crash in dev/test does not roll back the message insert (which has already committed). DraftWorker does NOT wrap (line 103) because the worker boundary tolerates errors; sealed Chat facade should not propagate broadcast failures back to its `:ok` branch.

**Changeset shape pattern** for `create_customer_conversation/1` — use `Cairnloop.Conversation.changeset/2`. Cite the existing call site at `chat.ex:42-48` (Message changeset inside Multi):
```elixir
Message.changeset(%Message{}, %{
  conversation_id: conversation.id,
  content: content,
  role: role
})
```
Mirror that style for the new Conversation insert (status: `:open`, host_user_id from `attrs`, subject default `"Customer chat"`).

**`:user`-role Message vs `reply_to_conversation/4`** — IMPORTANT: D-06 explicitly forbids calling `reply_to_conversation/4` with `:user` role from ProcessMessage because that path triggers DraftWorker via the `if role == :user do` branch at chat.ex:53-94. The new `ingest_widget_message/2` is a plain `repo().insert(Message.changeset(...))` — no Multi, no Oban, no SLA logic — exactly because it is the raw customer ingress writer.

---

### `lib/cairnloop/channels/widget_channel.ex` — MODIFY `join/3` lobby + `handle_in("new_message")`

**Analog:** `lib/cairnloop/channels/widget_channel.ex` (self).

**Topic destructure pattern** (widget_channel.ex:30-32) — for the `submit_csat` clause:
```elixir
def handle_in("submit_csat", %{"rating" => rating}, socket) do
  "widget:" <> conversation_id = socket.topic
  ...
```
Do NOT use this pattern for `handle_in("new_message")` after Phase 28 — D-07 says read `conversation_id` from `socket.assigns.conversation_id` (stored during join) because Phase 28 stays on `widget:lobby` per CONTEXT.md specifics §122. The `"widget:" <> _` destructure only works when the channel has rejoined to a conversation-scoped topic (deferred).

**Oban enqueue pattern** (widget_channel.ex:20-27) — existing handle_in to mirror, just add `conversation_id`:
```elixir
def handle_in("new_message", %{"content" => content}, socket) do
  # T-M001-03 Mitigation: Enqueueing to Oban prevents channel blocking.
  %{channel: "widget", content: content}
  |> Cairnloop.Workers.ProcessMessage.new()
  |> Oban.insert()

  {:reply, :ok, socket}
end
```
New shape per D-07:
```elixir
def handle_in("new_message", %{"content" => content}, socket) do
  conversation_id = socket.assigns[:conversation_id]

  %{channel: "widget", conversation_id: conversation_id, content: content}
  |> Cairnloop.Workers.ProcessMessage.new()
  |> Oban.insert()

  {:reply, :ok, socket}
end
```

**Join pattern** (new — derived from D-01 + chat.ex `repo()` pattern):
```elixir
def join("widget:lobby", _payload, socket) do
  token = socket.assigns[:user_token]

  case Cairnloop.Chat.create_customer_conversation(%{host_user_id: token}) do
    {:ok, conversation} ->
      socket = assign(socket, :conversation_id, conversation.id)
      {:ok, %{conversation_id: conversation.id}, socket}

    {:error, _changeset} ->
      {:error, %{reason: "could_not_create_conversation"}}
  end
end
```
**Preserve the existing private-room join clause** (widget_channel.ex:9-17) unchanged. The pattern-match on `"widget:" <> _private_room_id` is the second clause and stays exactly as it is (deferred per CONTEXT.md §122).

**Imports/auth** — no auth changes. `socket.assigns[:user_token]` is set by `WidgetSocket.connect/3` at widget_socket.ex:13 — Phase 28 uses it as `host_user_id`.

---

### `lib/cairnloop/workers/process_message.ex` — REWRITE

**Analog:** `lib/cairnloop/automation/workers/draft_worker.ex:1-8` (Oban.Worker header with `unique:` option) + `lib/cairnloop/workers/process_message.ex` (self — current 12-LOC stub, preserve email-channel arg shape per Pitfall 2).

**Oban.Worker header pattern** (draft_worker.ex:1-5):
```elixir
defmodule Cairnloop.Automation.Workers.DraftWorker do
  use Oban.Worker,
    queue: :default,
    unique: [period: 60, states: [:scheduled]],
    replace: [scheduled: [:scheduled_at]]
```
Apply per D-07:
```elixir
use Oban.Worker,
  queue: :default,
  unique: [period: 30, fields: [:worker, :args], keys: [:conversation_id, :content]]
```

**Multi-clause `perform/1` pattern** (sibling — common in Oban workers; pattern-match on args shape):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"channel" => "widget", "conversation_id" => id, "content" => content}}) do
  case Cairnloop.Chat.ingest_widget_message(id, content) do
    {:ok, _message} -> :ok
    {:error, _changeset} -> :error
  end
end

# Pitfall 2: preserve email-channel arg shape from EmailWebhookPlug
# (lib/cairnloop/ingress/email_webhook_plug.ex:18).
def perform(%Oban.Job{args: %{"channel" => "email", "content" => content}}) do
  require Logger
  Logger.info("Processed email message: #{content}")
  :ok
end
```

**Worker → context-facade → broadcast pattern** (draft_worker.ex:101-114) — the broadcast lives INSIDE `Chat.ingest_widget_message/2`, not in the worker, because Chat is the boundary that owns the post-commit emit. Worker just returns `:ok | :error`.

**Note on `:email` clause:** preserve the existing logger stub (current process_message.ex:8-9). Comment must explicitly cite "email-channel handling is a future phase; see Phase 28 Pitfall 2" per OQ-2 resolution.

---

### `lib/cairnloop/web/conversation_live.ex` — ADD `handle_info({:message_created, _}, …)`

**Analog:** `lib/cairnloop/web/conversation_live.ex` (self, lines 26-39).

**Mirror-exactly pattern** (conversation_live.ex:26-39):
```elixir
def handle_info({:draft_created, _draft_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end

# Phase 16: execution-outcome PubSub handlers (D16-11, D16-12).
# Mirror {:draft_created, _} exactly — plain-assign reload via reload_conversation_with_context/2.
# No Phoenix.LiveView.stream (D16-12); no manual retry (D16-07 — retries are automatic).
# PubSub topic is "conversation:#{id}" (broadcast by ToolExecutionWorker after co-commit).
def handle_info({:tool_executed, _approval_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end

def handle_info({:tool_execution_failed, _approval_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end
```
New clause for D-17 — add immediately after `{:tool_execution_failed, _}` to keep the chronologically-ordered cluster of `handle_info` clauses contiguous:
```elixir
# Phase 28 D-17: customer-side message-created PubSub handler.
# Mirror {:draft_created, _} exactly — additive only, no contract change.
# Topic: "conversation:#{id}" (broadcast by Chat.ingest_widget_message/2 + Chat.reply_to_conversation/4).
def handle_info({:message_created, _message_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end
```

**Subscribe is already in place** (conversation_live.ex:13-16) — mount/3 already subscribes to `"conversation:#{id}"`. No mount change needed.

---

### `lib/cairnloop/web/inbox_live.ex` — MODIFY `mount/3` to subscribe + ADD `handle_info({:conversations_changed}, …)`

**Analog:** `lib/cairnloop/web/conversation_live.ex:13-16` (subscribe in `connected?` block) + `lib/cairnloop/web/inbox_live.ex` (self — comment at lines 80-91 marks "subscribe here" + `prune_selected_ids/2` at 568-571).

**Subscribe pattern** (conversation_live.ex:13-16):
```elixir
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end
  ...
```
Apply to InboxLive — replace the dead WR-02 comment block (inbox_live.ex:80-91) with:
```elixir
def mount(_params, session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
  end

  conversations = Chat.list_conversations()

  {:ok,
   assign(socket,
     conversations: conversations,
     host_user_id: Map.get(session, "host_user_id"),
     selected_ids: MapSet.new(),
     bulk_modal_open: false,
     bulk_preview: nil,
     bulk_refusal: nil
   )}
end
```

**`prune_selected_ids/2` is already wired** (inbox_live.ex:568-571):
```elixir
@doc false
def prune_selected_ids(selected_ids, conversations) when is_list(conversations) do
  visible_ids = conversations |> Enum.map(& &1.id) |> MapSet.new()
  MapSet.intersection(selected_ids, visible_ids)
end
```
Call it from the new handle_info:
```elixir
# Phase 28 D-10: reload list + prune @selected_ids to stay in lockstep with what's rendered.
# Topic: "conversations" (broadcast by Chat.ingest_widget_message/2 + create_customer_conversation/1).
def handle_info({:conversations_changed}, socket) do
  conversations = Chat.list_conversations()
  selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)
  {:noreply, assign(socket, conversations: conversations, selected_ids: selected_ids)}
end
```

---

### `examples/cairnloop_example/lib/cairnloop_example/application.ex` — ADD `Cairnloop.PubSub` child (Pitfall 1)

**Analog:** `examples/cairnloop_example/lib/cairnloop_example/application.ex` (self, lines 10-20).

**Existing children list pattern** (application.ex:10-20):
```elixir
children = [
  CairnloopExampleWeb.Telemetry,
  CairnloopExample.Repo,
  {DNSCluster, query: Application.get_env(:cairnloop_example, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: CairnloopExample.PubSub},
  {Oban, Application.fetch_env!(:cairnloop_example, Oban)},
  # Start a worker by calling: CairnloopExample.Worker.start_link(arg)
  # {CairnloopExample.Worker, arg},
  # Start to serve requests, typically the last entry
  CairnloopExampleWeb.Endpoint
]
```
Add `{Phoenix.PubSub, name: Cairnloop.PubSub}` IMMEDIATELY after the existing `{Phoenix.PubSub, name: CairnloopExample.PubSub}` line so the two PubSub registrations live adjacent (visual clarity for adopters):
```elixir
{Phoenix.PubSub, name: CairnloopExample.PubSub},
{Phoenix.PubSub, name: Cairnloop.PubSub},
```
Both registries are independent named-process registries — running both has zero conflict. The example app keeps using `CairnloopExample.PubSub` for endpoint-issued LV broadcasts (config.exs:26 `pubsub_server: CairnloopExample.PubSub`); the library uses `Cairnloop.PubSub` for cross-LV / worker broadcasts.

---

### `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` — ADD WidgetSocket mount (D-15)

**Analog:** `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex:14-16` (self — existing `/live` socket).

**Existing socket mount pattern** (endpoint.ex:14-16):
```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]],
  longpoll: [connect_info: [session: @session_options]]
```
Add IMMEDIATELY AFTER per D-15 (preserves "all socket mounts colocated at the top of the endpoint" readability convention):
```elixir
socket "/widget", Cairnloop.Channels.WidgetSocket,
  websocket: true,
  longpoll: false
```
Note: WidgetSocket does NOT need session connect_info — it uses the binary token in connect params (widget_socket.ex:10-13). `longpoll: false` matches CONTEXT.md D-15 verbatim — Phoenix Channels WebSocket-only for the widget transport.

---

### `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` — REWRITE

**Analogs:**
1. `lib/cairnloop/web/conversation_live.ex:1-40` — LiveView mount + PubSub subscribe + handle_info structure.
2. `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` (self) — assigns shape baseline + render scaffold to extend.
3. `examples/cairnloop_example/assets/js/app.js:23-33` — `Socket` import + `colocatedHooks` import (existing wiring the new hook plugs into).
4. `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex` — canonical ColocatedHook docs.
5. UI-SPEC §1, §2 — exact HEEx markup, ARIA, brand tokens, copy.

**Mount pattern** (no subscribe — conversation_id is unknown at mount time per D-02/D-03):
```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:messages, [])
    |> assign(:channel_status, :connecting)
    |> assign(:pending, false)
    |> assign(:conversation_id, nil)

  {:ok, socket}
end
```

**Handle-event pattern for hook-pushed events** (NEW; no in-repo analog — derived from CONTEXT.md D-02 + Phoenix.LiveView `push_event/3` docs):
```elixir
def handle_event("conversation_id", %{"id" => id}, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end

  {:noreply,
   socket
   |> assign(:conversation_id, id)
   |> assign(:channel_status, :connected)}
end

def handle_event("channel_status", %{"status" => status}, socket) do
  {:noreply, assign(socket, :channel_status, String.to_atom(status))}
end
```
Note: `connected?(socket)` is still gating the subscribe even inside `handle_event` — defensive, matches the `mount` convention. Inside a `handle_event` invoked by the JS hook, the socket IS connected, but the gate is harmless and consistent.

**Send-message pattern** (extends self chat_live.ex:36-45, removes the mock `Process.send_after`):
```elixir
def handle_event("send_message", %{"message" => text}, socket)
    when is_binary(text) and text != "" do
  optimistic = %{role: :customer, content: text, inserted_at: DateTime.utc_now()}

  socket =
    socket
    |> assign(:messages, socket.assigns.messages ++ [optimistic])
    |> assign(:pending, true)
    |> push_event("widget:send", %{content: text})

  {:noreply, socket}
end

def handle_event("send_message", _params, socket), do: {:noreply, socket}
```

**Handle-info pattern for operator replies** (dedup by role per Pitfall 7 — only append `:agent` messages):
```elixir
def handle_info({:message_created, msg_id}, socket) do
  case load_operator_reply(msg_id) do
    %{role: :agent} = msg ->
      appended =
        socket.assigns.messages ++
          [%{role: :operator, content: msg.content, inserted_at: msg.inserted_at}]

      {:noreply, socket |> assign(:messages, appended) |> assign(:pending, false)}

    _ ->
      {:noreply, socket}
  end
end

defp load_operator_reply(msg_id) do
  # Narrow facade-style read. The chat facade may need a get_message/1 helper;
  # alternately scope this lookup via Cairnloop.Chat.get_conversation!/1 and
  # find the message in the preloaded list.
  Cairnloop.Chat.get_message(msg_id)
rescue
  _ -> nil
end
```
**Planner note:** the `Cairnloop.Chat.get_message/1` helper does NOT exist yet. Either add it as a tiny additive facade function (~3 LOC: `Conversation.Message |> repo().get(id)`) or look up via the existing `get_conversation!/1` preload. The PATTERNS recommendation is to add `get_message/1` because re-loading the entire conversation just to read one message is wasteful for the customer side.

**Colocated hook pattern** — no in-repo analog exists; this is the first colocated hook in the project. Closest canonical reference is `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex` (already in deps). Use exactly the shape from RESEARCH.md Example 7 (lines 729-769):
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
**The `import {Socket} from "phoenix"` line is load-bearing — Pitfall 4.** Colocated hooks are extracted to standalone ES modules; the `Socket` import in `app.js:23` is module-scoped and is NOT inherited by the extracted hook file.

**Existing JS wiring** (app.js:23-33, no change needed):
```javascript
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/cairnloop_example"
// ...
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})
```
The colocated hook is automatically picked up via `phoenix-colocated/cairnloop_example` after `mix compile`. No edit to `app.js` required.

**Render markup** — defer to UI-SPEC §1 (locked HEEx) including:
- `role="log" aria-live="polite"` on message-thread div (CONTEXT.md specifics §124).
- Brand tokens `var(--cl-primary, #A94F30)` etc. (CLAUDE.md arch invariant).
- No typing indicator (brand book §15.3).
- Send button disabled state pairs `disabled` attribute + `opacity-50` (never color-alone, brand §7.5).

---

### `examples/cairnloop_example/README.md` — ADD "## Two-Tab Demo" block (CHAT-03)

**Analog:** UI-SPEC §3 lines 161-176 (locked prose; copy verbatim).

No code analog. The prose is locked design. Planner must include the grep test `grep -q "Two-Tab Demo" examples/cairnloop_example/README.md` plus a verbatim-match assertion against the UI-SPEC §3 text.

---

### `test/cairnloop/chat_test.exs` — EXTEND

**Analog:** `test/cairnloop/chat_test.exs:1-120` (self — MockRepo + Multi reducer + `describe "reply_to_conversation/3"` blocks).

**MockRepo + setup pattern** (chat_test.exs:6-86):
```elixir
defmodule MockRepo do
  def get!(Cairnloop.Conversation, id) do
    if id in [1, 2] do
      %Cairnloop.Conversation{id: id, status: :open, ...}
    else
      raise Ecto.NoResultsError, queryable: Cairnloop.Conversation
    end
  end

  def transaction(multi), do: execute_multi(multi, %{})
  # ... defp execute_multi handles {:insert, :update, :run, :merge} ...
  def update(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  # ...
end

setup do
  Application.put_env(:cairnloop, :repo, MockRepo)

  on_exit(fn ->
    Application.delete_env(:cairnloop, :repo)
  end)

  :ok
end
```

**Test-block describe pattern** (chat_test.exs:88-118):
```elixir
describe "reply_to_conversation/3" do
  test "inserts message and job when role is :user" do
    assert {:ok, results} = Chat.reply_to_conversation(1, "hello", :user)
    assert %{content: "hello", role: :user, conversation_id: 1} = results.message
    # ...
  end
end
```

**New test blocks to add:**
- `describe "create_customer_conversation/1"` — assert returns `{:ok, %Conversation{}}` with `host_user_id: "demo_customer"`, status `:open`; assert `Phoenix.PubSub.broadcast` receives `{:conversations_changed}` on `"conversations"` (use `Phoenix.PubSub.subscribe` in test setup to capture).
- `describe "ingest_widget_message/2"` — assert returns `{:ok, %Message{role: :user}}`; assert TWO broadcasts received: `{:message_created, _}` on `"conversation:#{id}"` AND `{:conversations_changed}` on `"conversations"`.
- `describe "reply_to_conversation broadcast (OQ-1)"` — assert that after a successful `reply_to_conversation/4` call, `{:message_created, _}` is broadcast on `"conversation:#{id}"`.

**PubSub-in-test pattern:** start `Cairnloop.PubSub` in `test_helper.exs` (already done at test_helper.exs:24 per RESEARCH.md A7). Tests subscribe with `Phoenix.PubSub.subscribe(Cairnloop.PubSub, topic)` and assert with `assert_receive {:message_created, _}, 200`.

---

### `test/cairnloop/channels/widget_channel_test.exs` — EXTEND

**Analog:** `test/cairnloop/channels/widget_channel_test.exs:1-48` (self — MockRepo + `%Phoenix.Socket{}` direct stub).

**Existing direct-stub pattern** (widget_channel_test.exs:33-46):
```elixir
test "replies :ok when rating is successful" do
  socket = %Phoenix.Socket{topic: "widget:123"}
  payload = %{"rating" => "positive"}

  assert {:reply, :ok, ^socket} = WidgetChannel.handle_in("submit_csat", payload, socket)
end
```

**New test blocks to add:**
- `describe "join/3 widget:lobby"` — stub `Cairnloop.Chat.create_customer_conversation/1` (either via `Application.put_env(:cairnloop, :repo, MockRepo)` so the real Chat facade calls hit MockRepo, OR introduce a `:chat_module` indirection — recommend the MockRepo path for consistency with chat_test.exs). Assert `{:ok, %{conversation_id: id}, socket}` reply shape and `socket.assigns.conversation_id == id`.
- `describe "handle_in/3 with new_message"` — stub a `Phoenix.Socket{}` with `assigns: %{conversation_id: 42}`, send `%{"content" => "hi"}`, assert `Oban.insert` was called with args including `conversation_id: 42`. **Caveat:** the existing test does NOT use `use Phoenix.ChannelTest` — for the Oban-insert assertion, either use `Oban.Testing` (`assert_enqueued worker: ..., args: %{...}`) OR stub `Oban` via `Application.get_env(:cairnloop, :oban_module, Oban)` indirection. Recommend `Oban.Testing` since Oban is already in deps and supports test mode out of the box. The example app's `config/test.exs` may need `config :cairnloop_example, Oban, testing: :manual` if not already set (verify in plan).

---

### `test/cairnloop/workers/process_message_test.exs` — NEW

**Analog:** `test/cairnloop/workers/sla_countdown_worker_test.exs` (sibling worker test in same directory — same headless / pure-function test convention).

**Pattern:** stub `Cairnloop.Chat.ingest_widget_message/2` via `Application.put_env(:cairnloop, :repo, MockRepo)` (so the real Chat function calls hit MockRepo and returns a fake `%Message{}`). Then call `ProcessMessage.perform/1` directly with a hand-rolled `%Oban.Job{args: ...}`.

**Tests to add:**
- `test "widget channel ingests via Chat.ingest_widget_message/2"` — pass `%{"channel" => "widget", "conversation_id" => 1, "content" => "hi"}`, assert returns `:ok`, assert PubSub receives `{:message_created, _}` AND `{:conversations_changed}`.
- `test "email channel preserves logger stub (Pitfall 2)"` — pass `%{"channel" => "email", "content" => "hello"}`, assert returns `:ok` (and optionally use `ExUnit.CaptureLog.capture_log/1` to assert the log line).

---

### `examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs` — NEW

**Analog:** `test/cairnloop/web/inbox_live_test.exs:1-65` (LiveViewTest convention — `import Phoenix.LiveViewTest`, `defmodule EmptyRepo`, mount + assigns assertion).

**LiveViewTest pattern** (inbox_live_test.exs:36-65):
```elixir
describe "mount/3 (Task 1 — D-04 selection assign)" do
  defmodule EmptyRepo do
    def all(_query), do: []
  end

  test "Test 1: mount populates selected_ids with an empty MapSet" do
    prior = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, EmptyRepo)

    try do
      {:ok, socket} = InboxLive.mount(%{}, %{"host_user_id" => "u1"}, build_socket())
      assert socket.assigns.selected_ids == MapSet.new()
      # ...
    after
      if prior do
        Application.put_env(:cairnloop, :repo, prior)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end
  end
end
```

**Tests to add:**
- `test "mount initializes :messages [], :channel_status :connecting, :pending false, :conversation_id nil"` — pure mount test (no DB, no PubSub).
- `test "handle_event/3 \"conversation_id\" subscribes and sets :channel_status :connected"` — mock PubSub subscription, assert assigns shape.
- `test "handle_event/3 \"send_message\" optimistically appends + sets :pending true + push_event"` — assert `socket.assigns.messages` length grew by 1 with `role: :customer`, `:pending` is true, and a `push_event` was enqueued for `"widget:send"`.
- `test "handle_info/2 {:message_created, _} appends :agent message and clears :pending"` — stub `Chat.get_message/1` to return `%Message{role: :agent}`, assert appended message has `role: :operator` and `:pending` is false.
- `test "handle_info/2 {:message_created, _} skips :user role (Pitfall 7 dedup)"` — stub `Chat.get_message/1` to return `%Message{role: :user}`, assert `@messages` unchanged.
- **Negative grep test:** `test "chat_live.ex no longer references Process.send_after"` — `assert File.read!("lib/cairnloop_example_web/live/chat_live.ex") !~ "Process.send_after"`. Also assert `!~ "handle_info(:bot_reply"` per CONTEXT.md specifics §125.

---

## Shared Patterns

### Authentication / Socket Token

**Source:** `lib/cairnloop/channels/widget_socket.ex:7-18`
**Apply to:** WidgetChannel.join/3 (reads `socket.assigns[:user_token]`); ChatLive colocated hook (passes token in connect params).

```elixir
def connect(params, socket, _connect_info) do
  case params do
    %{"token" => token} when is_binary(token) ->
      {:ok, assign(socket, :user_token, token)}

    _ ->
      {:error, :unauthorized}
  end
end
```
Phase 28 demo: token is hardcoded `"demo_customer"` in the JS hook per CONTEXT.md specifics §121. The library accepts any binary token in demo mode.

---

### PubSub Broadcast (post-commit, defensive)

**Source:** `lib/cairnloop/automation/workers/draft_worker.ex:101-114` (canonical) + `lib/cairnloop/workers/tool_execution_worker.ex:580-588` (defensive variant).
**Apply to:** All three new broadcast emit points — `Chat.create_customer_conversation/1`, `Chat.ingest_widget_message/2`, `Chat.reply_to_conversation/4` (OQ-1 fix).
**Bus:** `Cairnloop.PubSub` (D-08; must be started in example app per Pitfall 1).
**Topics:** `"conversation:#{id}"` for per-conversation events; `"conversations"` for list-level events.

Canonical (in worker post-commit branch):
```elixir
Phoenix.PubSub.broadcast(
  Cairnloop.PubSub,
  "conversation:#{conversation_id}",
  {:draft_created, draft.id}
)
```

Defensive variant (when broadcast failure must NOT block the calling path — recommended for the sealed `Chat.reply_to_conversation/4`):
```elixir
defp broadcast_executed(approval_id, proposal) do
  topic = "conversation:#{proposal.conversation_id}"

  try do
    Phoenix.PubSub.broadcast(Cairnloop.PubSub, topic, {:tool_executed, approval_id})
  rescue
    _ -> :ok
  end
end
```

---

### LiveView PubSub Subscribe (gated on `connected?`)

**Source:** `lib/cairnloop/web/conversation_live.ex:13-16`
**Apply to:** InboxLive.mount/3 (subscribe to `"conversations"`); ChatLive.handle_event("conversation_id", …) (subscribe to `"conversation:#{id}"` after hook delivers the id).

```elixir
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end
  ...
end
```

---

### LiveView handle_info → reload helper (additive only)

**Source:** `lib/cairnloop/web/conversation_live.ex:26-39`
**Apply to:** ConversationLive.handle_info({:message_created, _}, _) (D-17); InboxLive.handle_info({:conversations_changed}, _) (D-10).

The handle_info clause is a one-liner — reload via the context facade + assign. No streams, no manual retry, no churn to sealed reload helpers.

---

### Oban worker → context facade (never raw Repo)

**Source:** `lib/cairnloop/automation/workers/draft_worker.ex:101` (worker → `Cairnloop.Automation.create_draft/2`) + `lib/cairnloop/workers/tool_execution_worker.ex` (worker → `Cairnloop.Governance.*`).
**Apply to:** ProcessMessage.perform/1 → `Cairnloop.Chat.ingest_widget_message/2` (D-07). Never call `Repo.insert` from the worker — go through the Chat facade so MockRepo substitution works and the post-commit broadcast lives at the right boundary.

---

### Error handling / fail-closed operator copy

**Source:** `CLAUDE.md` "Operator copy is calm, fail-closed, reason-forward, honest — never raw Elixir terms / raw JSON to operators"; UI-SPEC §1d copywriting contract (locked strings).
**Apply to:** ChatLive disconnected-state badge text, send-button disabled state, "Waiting on operator" line (UI-SPEC §1c).
- No "AI is thinking" / "Bot is typing" / "Ticket submitted" / "Agent will reply" strings (UI-SPEC §1d).
- Channel state pairs dot + label (brand §7.5 never state-by-color-alone).
- Failure modes (channel disconnect, send-error) render the locked UI-SPEC strings — never raw exception terms.

---

### Brand tokens (no hardcoded hex without var)

**Source:** `lib/cairnloop/web/inbox_live.ex:30-46` (canonical token vocabulary) + UI-SPEC §1 (locked tokens for ChatLive).
**Apply to:** All HEEx in chat_live.ex render.

```css
var(--cl-primary, #A94F30)
var(--cl-text-muted, rgba(47, 36, 29, 0.62))
var(--cl-surface, #FBF5EE)
var(--cl-border, rgba(47, 36, 29, 0.12))
```

---

### Test harness — MockRepo + Application.put_env

**Source:** `test/cairnloop/chat_test.exs:6-86` (MockRepo + Multi reducer); `test/cairnloop/web/inbox_live_test.exs:36-65` (test-local Repo stub + try/after restore).
**Apply to:** All new tests in this phase (chat_test.exs extensions, widget_channel_test.exs extensions, process_message_test.exs new, chat_live_test.exs new).

```elixir
setup do
  Application.put_env(:cairnloop, :repo, MockRepo)
  on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
  :ok
end
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Colocated JS hook block inside `chat_live.ex` (the `<script :type={Phoenix.LiveView.ColocatedHook}>` element) | colocated-hook | event-driven (JS Socket → LV `pushEvent` / LV `push_event` → JS `handleEvent`) | No prior colocated hook exists in this repo. The pattern is in deps at `deps/phoenix_live_view/lib/phoenix_live_view/colocated_hook.ex` and is referenced from `RESEARCH.md` Example 7. Planner should treat RESEARCH.md Example 7 + the in-deps docs as authoritative. The `import {Socket} from "phoenix"` line is load-bearing (Pitfall 4). |

---

## Metadata

**Analog search scope:**
- `lib/cairnloop/chat.ex`
- `lib/cairnloop/channels/widget_channel.ex`
- `lib/cairnloop/channels/widget_socket.ex`
- `lib/cairnloop/workers/process_message.ex`
- `lib/cairnloop/workers/tool_execution_worker.ex` (broadcast variant)
- `lib/cairnloop/automation/workers/draft_worker.ex` (canonical broadcast)
- `lib/cairnloop/web/conversation_live.ex` (LV subscribe + handle_info)
- `lib/cairnloop/web/inbox_live.ex` (mount comment + prune_selected_ids)
- `lib/cairnloop/ingress/email_webhook_plug.ex` (silent ProcessMessage caller)
- `examples/cairnloop_example/lib/cairnloop_example/application.ex` (supervisor child list)
- `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` (existing /live socket)
- `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` (mock to replace)
- `examples/cairnloop_example/assets/js/app.js` (Socket import + colocated hooks wiring)
- `test/cairnloop/chat_test.exs` (MockRepo + Multi reducer + describe blocks)
- `test/cairnloop/channels/widget_channel_test.exs` (direct %Phoenix.Socket{} stub)
- `test/cairnloop/web/inbox_live_test.exs` (LiveViewTest + try/after restore)

**Files scanned:** 16

**Pattern extraction date:** 2026-05-27

**Key observations:**
- 100% of the new functions have either a direct self-analog (same file extends) or a same-tier sibling analog (worker → worker, LV → LV, channel → channel).
- The colocated JS hook is the single "no in-repo analog" surface; deps + RESEARCH.md Example 7 cover it.
- All shared patterns (subscribe-gated, post-commit broadcast, worker → facade, brand tokens, MockRepo test harness) are well-established carried decisions per `.planning/STATE.md`.
- Pitfall 1 (PubSub mismatch) and Pitfall 2 (silent EmailWebhookPlug caller) are environmental — not pattern questions — but the pattern map flags them to the planner.
