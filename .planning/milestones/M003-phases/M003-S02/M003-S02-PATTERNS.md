# Phase M003-S02: Dynamic Context Pane UI in LiveView - Pattern Map

**Mapped:** 2026-05-11
**Files analyzed:** 2
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/conversation_live.ex` | component | request-response | `lib/cairnloop/web/conversation_live.ex` | exact |
| `test/cairnloop/web/conversation_live_test.exs` | test | request-response | `test/cairnloop/web/conversation_live_test.exs` | exact |

## Pattern Assignments

### `lib/cairnloop/web/conversation_live.ex` (component, request-response)

**Analog:** `lib/cairnloop/web/conversation_live.ex`

**Why this is the closest match:** This phase is modifying the existing parent LiveView in place. The current module already owns `mount/3`, `handle_info/2`, `handle_event/3`, context-provider lookup, draft actions, and the HEEx render tree.

**Imports and module setup pattern** (lines 1-4):
```elixir
defmodule Cairnloop.Web.ConversationLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat
```

**Mount + provider resolution pattern** (lines 6-31):
```elixir
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end

  conversation = Chat.get_conversation!(id)

  provider = Application.get_env(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider)

  {context, context_error} =
    if conversation.host_user_id do
      case provider.get_context(conversation.host_user_id, []) do
        {:ok, map} -> {map, nil}
        {:error, reason} -> {%{}, reason}
      end
    else
      {%{}, nil}
    end

  {:ok,
   assign(socket,
     conversation: conversation,
     form: to_form(%{"content" => ""}),
     host_context: context,
     context_error: context_error
   )}
end
```
Copy this shape for the new private reload helper: resolve provider from app env, convert provider errors into assigns, and keep the LiveView alive.

**Reload-on-event pattern** (lines 34-97):
```elixir
def handle_info({:draft_created, _draft_id}, socket) do
  conversation = Chat.get_conversation!(socket.assigns.conversation.id)
  {:noreply, assign(socket, conversation: conversation)}
end

def handle_event("reply", %{"content" => content}, socket) do
  if content != "" do
    case Chat.reply_to_conversation(socket.assigns.conversation.id, content) do
      {:ok, _result} ->
        conversation = Chat.get_conversation!(socket.assigns.conversation.id)

        {:noreply,
         assign(socket, conversation: conversation, form: to_form(%{"content" => ""}))}

      {:error, _failed_operation, _failed_value, _changes_so_far} ->
        {:noreply, put_flash(socket, :error, "Failed to send reply.")}
    end
  else
    {:noreply, socket}
  end
end
```
Use this as the callback ownership pattern, but centralize the repeated `Chat.get_conversation!/1` path so every reload also refreshes context.

**Draft action pattern** (lines 61-96):
```elixir
def handle_event("approve_draft", %{"draft-id" => draft_id}, socket) do
  case Cairnloop.Automation.approve_draft(String.to_integer(draft_id)) do
    {:ok, _} ->
      conversation = Chat.get_conversation!(socket.assigns.conversation.id)
      {:noreply, assign(socket, conversation: conversation)}

    _error ->
      {:noreply, put_flash(socket, :error, "Failed to approve draft.")}
  end
end
```
Mirror this case/flash structure for any new inline confirmation branch; keep operator failures as flashes instead of crashes.

**Current render skeleton to preserve while extracting function components** (lines 99-155):
```elixir
def render(assigns) do
  ~H"""
  <div class="cairnloop-conversation">
    <.link navigate="/">Back to Inbox</.link>
    <h2><%= @conversation.subject || "No Subject" %></h2>
    ...
    <div class="messages">
      <%= for msg <- @conversation.messages do %>
        <div class={"message role-#{msg.role}"}>
          <strong><%= msg.role %>:</strong>
          <p><%= msg.content %></p>
        </div>
      <% end %>
    </div>
    ...
    <div class="reply-form">
      <.form for={@form} phx-submit="reply" phx-change="change">
        <textarea name="content" placeholder="Type a reply..."><%= @form.params["content"] %></textarea>
        <button type="submit">Send Reply</button>
      </.form>
    </div>
  </div>
  """
end
```
Keep the parent LiveView render ownership and inline HEEx style. Extract private function components inside this module rather than introducing a child LiveView or `LiveComponent`.

**Current anti-pattern to replace** (lines 105-119):
```elixir
<%= if @context_error do %>
  <div class="host-context error">
    <h3>Customer Context</h3>
    <p>Context Unavailable: <%= inspect(@context_error) %></p>
  </div>
<% else %>
  <%= if map_size(@host_context) > 0 do %>
    <div class="host-context">
      <h3>Customer Context</h3>
      <ul>
        <%= for {key, value} <- @host_context do %>
          <li><strong><%= key %>:</strong> <%= inspect(value) %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
<% end %>
```
Planner should explicitly replace this with: always-visible rail shell, deterministic normalized sections, and safe fallback values instead of raw `inspect/1`.

**Secondary analog for minimal parent LiveView structure:** `lib/cairnloop/web/inbox_live.ex` lines 1-16, especially `use Phoenix.LiveView`, `alias`, `mount/3`, and single-module `render/1`.

---

### `test/cairnloop/web/conversation_live_test.exs` (test, request-response)

**Analog:** `test/cairnloop/web/conversation_live_test.exs`

**Why this is the closest match:** The repo already tests this LiveView by calling `mount/3`, `handle_info/2`, and `render/1` directly with mock providers and a mock repo. There is no richer local `ConnCase` or `Phoenix.LiveViewTest` harness to copy instead.

**Test module + alias pattern** (lines 1-4):
```elixir
defmodule Cairnloop.Web.ConversationLiveTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Web.ConversationLive
```

**Inline repo/provider doubles pattern** (lines 6-34):
```elixir
defmodule MockRepo do
  def get!(Cairnloop.Conversation, 1) do
    %Cairnloop.Conversation{
      id: 1,
      host_user_id: "user_42",
      subject: "Test Subject",
      messages: [],
      drafts: [
        %Cairnloop.Automation.Draft{
          id: 202,
          content: "Newly loaded AI draft",
          status: :pending
        }
      ]
    }
  end

  def preload(record, _), do: record
end

defmodule SuccessContextProvider do
  @behaviour Cairnloop.ContextProvider
  def get_context("user_42", _opts), do: {:ok, %{"Plan" => "Pro"}}
end

defmodule ErrorContextProvider do
  @behaviour Cairnloop.ContextProvider
  def get_context("user_42", _opts), do: {:error, :not_found}
end
```
Reuse this approach for new normalization, empty-state, nested-map, and reload-path tests.

**App env setup/cleanup pattern** (lines 36-45):
```elixir
setup do
  Application.put_env(:cairnloop, :repo, MockRepo)

  on_exit(fn ->
    Application.delete_env(:cairnloop, :repo)
    Application.delete_env(:cairnloop, :context_provider)
  end)

  :ok
end
```
Keep tests isolated through app-env setup, not global mocks.

**Mount assertions pattern** (lines 47-71):
```elixir
describe "mount/3 context resolution" do
  test "handles success tuple from configured context provider" do
    Application.put_env(:cairnloop, :context_provider, SuccessContextProvider)

    assert {:ok, socket} = ConversationLive.mount(%{"id" => 1}, %{}, %Phoenix.LiveView.Socket{})
    assert socket.assigns.host_context == %{"Plan" => "Pro"}
    assert socket.assigns.context_error == nil
  end
end
```
Extend this describe block with empty context, nested context, and normalized render-tree assertions.

**Callback reload test pattern** (lines 74-86):
```elixir
describe "handle_info/2" do
  test "reloads conversation on :draft_created" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        conversation: %Cairnloop.Conversation{id: 1},
        __changed__: %{}
      }
    }

    assert {:noreply, new_socket} = ConversationLive.handle_info({:draft_created, 202}, socket)
    assert hd(new_socket.assigns.conversation.drafts).id == 202
  end
end
```
Copy this direct-callback style for each event path that should now refresh both `conversation` and context assigns.

**Direct render assertion pattern** (lines 89-200):
```elixir
html =
  assigns
  |> ConversationLive.render()
  |> Phoenix.HTML.Safe.to_iodata()
  |> IO.iodata_to_binary()

assert html =~ "Approve & Send"
assert html =~ "phx-click=\"approve_draft\""
```
Use this exact render-to-string pattern for the rail shell, empty/error copy, nested subsection headings, and inline discard confirmation state.

---

## Shared Patterns

### Context Provider Contract
**Source:** `lib/cairnloop/context_provider.ex`
**Apply to:** `lib/cairnloop/web/conversation_live.ex`, `test/cairnloop/web/conversation_live_test.exs`

**Contract pattern** (lines 21-34):
```elixir
Callbacks return tagged tuples (`{:ok, map()} | {:error, term()}`) rather than
raising exceptions on failure.
...
@callback get_context(actor_id :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
```
Planner should preserve tagged-tuple handling. UI errors belong in `context_error`, not exceptions.

### Safe Default Context Provider
**Source:** `lib/cairnloop/default_context_provider.ex`
**Apply to:** `lib/cairnloop/web/conversation_live.ex`, tests for default behavior

**Default pattern** (lines 7-12):
```elixir
@behaviour Cairnloop.ContextProvider

@impl true
def get_context(_actor_id, _opts \\ []) do
  {:ok, %{}}
end
```
Keep empty-map fallback behavior for unconfigured hosts.

### Parent LiveView Structure
**Source:** `lib/cairnloop/web/inbox_live.ex`
**Apply to:** `lib/cairnloop/web/conversation_live.ex`

**Minimal owner pattern** (lines 1-16):
```elixir
defmodule Cairnloop.Web.InboxLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

  def mount(_params, _session, socket) do
    conversations = Chat.list_conversations()
    {:ok, assign(socket, conversations: conversations)}
  end
```
Use this as the project’s only other LiveView baseline: state stays in the parent module and rendering remains straightforward.

### Brand Tokens For Rail Styling
**Source:** `prompts/cairnloop.css`
**Apply to:** Any classes or inline styles added in `lib/cairnloop/web/conversation_live.ex`

**Token definitions** (lines 19-41):
```css
--cl-bg: var(--cl-color-trailpaper);
--cl-surface: var(--cl-color-warm-stone);
--cl-text: var(--cl-color-basalt);
--cl-text-muted: var(--cl-color-slate-lichen);
--cl-border: var(--cl-color-granite);
--cl-primary: var(--cl-color-path-copper);
--cl-success: var(--cl-color-deep-lichen);
--cl-info: var(--cl-color-waypoint-blue);
--cl-ai: var(--cl-color-heather);
--cl-danger: var(--cl-color-fault-clay);
--cl-font-sans: "Atkinson Hyperlegible Next", "Atkinson Hyperlegible", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
--cl-font-mono: "Martian Mono", "Atkinson Hyperlegible Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
--cl-radius-sm: 6px;
--cl-radius-md: 10px;
--cl-radius-lg: 14px;
--cl-shadow-raised: 0 1px 2px rgba(24, 33, 31, 0.08), 0 8px 24px rgba(24, 33, 31, 0.06);
```

**Existing card/button pattern** (lines 61-85):
```css
.cl-button-primary {
  background: var(--cl-primary);
  color: var(--cl-primary-text);
  border-radius: var(--cl-radius-md);
  font-family: var(--cl-font-sans);
}

.cl-card {
  background: var(--cl-surface);
  color: var(--cl-text);
  border: 1px solid var(--cl-border);
  border-radius: var(--cl-radius-lg);
  box-shadow: var(--cl-shadow-raised);
}
```
There is no production CSS pipeline pattern in the repo, but these are the canonical local tokens the UI spec expects the planner to use.

### Direct Render Testing Instead Of Endpoint-Mounted LiveView Tests
**Source:** `test/cairnloop/web/conversation_live_test.exs`
**Apply to:** All new tests for this slice

**Render pattern** (lines 103-107, 126-130, 156-160, 191-195):
```elixir
assigns
|> ConversationLive.render()
|> Phoenix.HTML.Safe.to_iodata()
|> IO.iodata_to_binary()
```
No local `ConnCase`, `Phoenix.ConnTest`, or `Phoenix.LiveViewTest` usage exists today. Keep the planner anchored to direct module/callback tests unless it explicitly adds new web test scaffolding.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/cairnloop/web/conversation_live.ex` (new private function components inside same file) | component | request-response | No separate local function-component module exists yet; extraction must stay inside the parent LiveView and follow Phoenix idioms from the phase docs rather than copy an existing component file. |
| `lib/cairnloop/web/conversation_live.ex` (inline discard confirmation state) | component | request-response | No existing inline confirmation interaction pattern exists anywhere in the repo; planner must derive this from `M003-S02-UI-SPEC.md` while keeping the current `handle_event/3` + flash style. |

## Metadata

**Analog search scope:** `lib/cairnloop/web/`, `lib/cairnloop/`, `test/cairnloop/web/`, `prompts/`, `.planning/`
**Files scanned:** 10
**Pattern extraction date:** 2026-05-11
