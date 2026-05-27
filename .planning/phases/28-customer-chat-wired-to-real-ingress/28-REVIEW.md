---
phase: 28-customer-chat-wired-to-real-ingress
reviewed: 2026-05-27T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - examples/cairnloop_example/README.md
  - examples/cairnloop_example/lib/cairnloop_example/application.ex
  - examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex
  - examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex
  - examples/cairnloop_example/mix.exs
  - examples/cairnloop_example/test/cairnloop_example/widget_channel_oban_test.exs
  - examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs
  - lib/cairnloop/channels/widget_channel.ex
  - lib/cairnloop/chat.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/inbox_live.ex
  - lib/cairnloop/workers/process_message.ex
  - test/cairnloop/chat_test.exs
  - test/cairnloop/workers/process_message_test.exs
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-05-27
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 28 wires the customer chat widget (`ChatLive` + `WidgetChannel`) to real ingress through `Chat.create_customer_conversation/1`, `Chat.ingest_widget_message/2`, and a new `ProcessMessage` Oban worker. The additive `reply_to_conversation/4` broadcast (OQ-1) enables operator replies to appear in the customer tab in real time. `InboxLive` gains a PubSub subscription so new conversations surface without a page refresh.

The implementation is structurally sound and the security-critical invariant (conversation_id read from server state, never from the inbound payload) is correctly implemented and well-tested. The main concerns are: an unguarded `String.to_existing_atom/1` call that crashes the LiveView process on adversarial or unexpected input; a deferred `submit_csat` clause that crashes with an unhandled pattern match when called on `widget:lobby`; and Oban returning `:error` (retryable) for what are fundamentally permanent changeset failures. Several quality issues around silent discards and missing test coverage round out the findings.

## Critical Issues

### CR-01: `String.to_existing_atom/1` raises unhandled `ArgumentError` in `ChatLive`

**File:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex:213`

**Issue:** `handle_event("channel_status", ...)` calls `String.to_existing_atom(status)` with no `rescue` around it. If the JS hook (or a tampered client / XSS payload) pushes a status string that is not already in the BEAM atom table — for example `"error"` or any string that Erlang/Elixir hasn't interned — `ArgumentError` is raised, the LiveView process crashes, and Phoenix restarts it (wiping session state and the `conversation_id` assign). The comment acknowledges this is a DoS mitigation, but the mitigation itself introduces a crash surface.

The three currently-emitted JS values (`"connected"`, `"disconnected"`, and the LV-local `:connecting`) are all pre-existing atoms, so the normal path never triggers this. The issue is the abnormal path: any unexpected string terminates the customer's session.

**Fix:**

```elixir
def handle_event("channel_status", %{"status" => status}, socket) do
  atom =
    case status do
      "connecting" -> :connecting
      "connected" -> :connected
      "disconnected" -> :disconnected
      _ -> socket.assigns.channel_status  # unknown status: preserve current state
    end

  {:noreply, assign(socket, :channel_status, atom)}
end
```

Replace `String.to_existing_atom/1` with a closed `case` over the known strings. This eliminates the crash surface entirely and is more explicit than relying on atom-table internment.

---

### CR-02: Deferred `submit_csat` clause crashes on `widget:lobby` with unhandled pattern / type error

**File:** `lib/cairnloop/channels/widget_channel.ex:61-71`

**Issue:** The `handle_in("submit_csat", ...)` clause is documented as deferred and is not intended to fire in Phase 28. However, it is live code: a client sending `submit_csat` on `widget:lobby` causes:

1. The destructure `"widget:" <> conversation_id = socket.topic` succeeds with `conversation_id = "lobby"`.
2. `Chat.submit_csat("lobby", rating)` calls `repo().get!(Conversation, "lobby")`.
3. Ecto raises `Ecto.Query.CastError` (cannot cast `"lobby"` to integer) — an unrescued exception that crashes the channel process.

Even though this is "deferred", leaving a crash-path clause in production code that terminates the channel on any `submit_csat` push (rather than returning a structured error reply) violates the fail-closed error-handling posture established throughout the codebase.

**Fix:** Replace the deferred clause with a clean error reply until the channel re-join flow is implemented:

```elixir
def handle_in("submit_csat", _payload, socket) do
  # CSAT deferred per CONTEXT.md OQ-4 — channel re-join not yet implemented.
  # Returns a structured error instead of crashing on "widget:lobby" pattern mismatch.
  {:reply, {:error, %{reason: "csat_not_available"}}, socket}
end
```

---

## Warnings

### WR-01: `Oban.insert/1` result silently discarded in `WidgetChannel.handle_in/3`

**File:** `lib/cairnloop/channels/widget_channel.ex:48-52`

**Issue:** The result of `Oban.insert/1` is piped and then discarded; `{:reply, :ok, socket}` follows unconditionally. If `Oban.insert/1` returns `{:error, changeset}` (e.g., a DB constraint failure or queue misconfiguration), the customer receives `:ok` but the message is silently dropped. No error is surfaced, no retry-or-error path is taken, and the customer has no indication that their message was not queued.

```elixir
# current
%{channel: "widget", conversation_id: conversation_id, content: content}
|> Cairnloop.Workers.ProcessMessage.new()
|> Oban.insert()

{:reply, :ok, socket}
```

**Fix:** Match on the result and return an error reply on failure:

```elixir
job_attrs = %{channel: "widget", conversation_id: conversation_id, content: content}

case job_attrs |> Cairnloop.Workers.ProcessMessage.new() |> Oban.insert() do
  {:ok, _job} ->
    {:reply, :ok, socket}

  {:error, _changeset} ->
    {:reply, {:error, %{reason: "could_not_queue_message"}}, socket}
end
```

The JS hook's `.receive("error", ...)` handler already knows to push `"send_error"` to the LiveView when a channel push error reply arrives, so no additional JS changes are needed.

---

### WR-02: `ProcessMessage` returns `:error` (retryable) for permanent changeset failures

**File:** `lib/cairnloop/workers/process_message.ex:40-43`

**Issue:**

```elixir
case Cairnloop.Chat.ingest_widget_message(id, content) do
  {:ok, _message} -> :ok
  {:error, _changeset} -> :error
end
```

Returning `:error` from an Oban `perform/1` signals a retryable failure. Oban will retry this job up to the default maximum of 20 attempts. A changeset validation error (missing required field, constraint violation, etc.) will not be resolved by retrying — the same error will occur 20 times before the job is exhausted and marked `:discarded`. This wastes Oban queue capacity and pollutes the failed-jobs view with noise.

**Fix:** Return `{:cancel, reason}` for permanent failures (Ecto changeset errors are deterministic):

```elixir
case Cairnloop.Chat.ingest_widget_message(id, content) do
  {:ok, _message} -> :ok
  {:error, changeset} -> {:cancel, "changeset error: #{inspect(changeset.errors)}"}
end
```

`{:cancel, reason}` marks the job as permanently cancelled without retries, which is the correct Oban idiom for non-transient failures.

---

### WR-03: Optimistic customer message not removed from `@messages` on `send_error`

**File:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex:245-247`

**Issue:** When `handle_event("send_error", ...)` fires, the LiveView only sets `send_error: true`:

```elixir
def handle_event("send_error", _params, socket) do
  {:noreply, assign(socket, :send_error, true)}
end
```

The optimistic customer message that was appended in `handle_event("send_message", ...)` remains in `@messages` permanently. The pending indicator is also never cleared. The customer sees a "ghost" message in the thread that was never actually sent, alongside the error alert. On re-send (if the customer types the message again), the message appears duplicated: once as the ghost and once as the new optimistic entry.

**Fix:** Remove the last optimistic message (the one just appended) and clear pending on send error:

```elixir
def handle_event("send_error", _params, socket) do
  # Drop the last optimistically-appended message (the failed one) and clear pending.
  messages = socket.assigns.messages |> Enum.drop(-1)

  {:noreply,
   socket
   |> assign(:messages, messages)
   |> assign(:pending, false)
   |> assign(:send_error, true)}
end
```

---

### WR-04: `connection_label/1` and `connection_dot_color/1` lack a catch-all clause

**File:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex:284-290`

**Issue:** Both private helpers are defined only for `:connecting`, `:connected`, and `:disconnected`. If `@channel_status` ever holds any other atom (e.g., from a future extension or due to a bug elsewhere), `render/1` will raise a `FunctionClauseError`. This is separate from the `String.to_existing_atom` issue in CR-01 — it is a general brittleness. Given that `@channel_status` is set from multiple code paths (`mount/3`, `handle_event("conversation_id", ...)`, `handle_event("channel_status", ...)`), defensive catch-all clauses cost nothing.

**Fix:**

```elixir
defp connection_label(:connecting), do: "Connecting…"
defp connection_label(:connected), do: "Connected"
defp connection_label(:disconnected), do: "Disconnected — reconnecting"
defp connection_label(_), do: "Unknown"

defp connection_dot_color(:connecting), do: "var(--cl-text-muted, #677066)"
defp connection_dot_color(:connected), do: "var(--cl-success, #2D7A3A)"
defp connection_dot_color(:disconnected), do: "var(--cl-danger, #B54C36)"
defp connection_dot_color(_), do: "var(--cl-text-muted, #677066)"
```

---

## Info

### IN-01: No test coverage for `handle_event("channel_status", ...)` or `handle_event("send_error", ...)`

**File:** `examples/cairnloop_example/test/cairnloop_example_web/live/chat_live_test.exs`

**Issue:** The test file exercises mount, conversation_id, send_message (happy + empty), handle_info (agent reply, user dedup, multi-send stack), and the negative grep for Process.send_after. However, two `handle_event` clauses are not directly tested:

1. `handle_event("channel_status", %{"status" => "connected"}, socket)` — the only indirect coverage is via `handle_event("conversation_id", ...)` which sets `channel_status: :connected` as a side effect.
2. `handle_event("send_error", _params, socket)` — no test.

These gaps mean the crash introduced by `String.to_existing_atom` on bad input (CR-01) would not be caught by the test suite, and the ghost-message behavior from WR-03 is also untested.

**Fix:** Add at minimum:

```elixir
test "handle_event(channel_status, connected) updates channel_status assign" do
  {:ok, socket} = ChatLive.mount(%{}, %{}, build_connected_socket())
  {:noreply, socket} = ChatLive.handle_event("channel_status", %{"status" => "connected"}, socket)
  assert socket.assigns.channel_status == :connected
end

test "handle_event(channel_status, disconnected) updates channel_status assign" do
  {:ok, socket} = ChatLive.mount(%{}, %{}, build_connected_socket())
  {:noreply, socket} = ChatLive.handle_event("channel_status", %{"status" => "disconnected"}, socket)
  assert socket.assigns.channel_status == :disconnected
end

test "handle_event(send_error) sets send_error: true" do
  {:ok, socket} = ChatLive.mount(%{}, %{}, build_connected_socket())
  {:noreply, socket} = ChatLive.handle_event("send_error", %{}, socket)
  assert socket.assigns.send_error == true
end
```

---

### IN-02: `WidgetSocket` token is not verified — any binary string accepted as identity

**File:** `lib/cairnloop/channels/widget_socket.ex:11-13`

**Issue:** The `connect/3` callback accepts any non-empty binary token and assigns it directly as `user_token`, which then becomes the `host_user_id` stored on the `Conversation` row:

```elixir
%{"token" => token} when is_binary(token) ->
  # In a real app, verify the token here
  {:ok, assign(socket, :user_token, token)}
```

The comment acknowledges this is unverified. Two downstream effects worth flagging for the library's example consumers:

1. The `id/1` callback returns `"widget_socket:#{token}"` — if two clients share the same token string, Phoenix will consider them the same socket id and `Phoenix.Socket.broadcast_from/3` calls targeting that id will reach both connections.
2. The `host_user_id` on conversations created through this path is entirely client-controlled, which makes it untrusted for any access-control decisions downstream.

This is an example app (not production library code) and the comment already flags it. No behavioral fix is needed for Phase 28, but downstream consumers should note the identity boundary is open and the example token `"demo_customer"` is hardcoded in the render template (`data-token="demo_customer"`).

**Fix (for documentation):** Add a note in the README under "Included Integrations" that the token verification is a stub and must be replaced before production use, pointing to `lib/cairnloop/channels/widget_socket.ex:12`.

---

_Reviewed: 2026-05-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
