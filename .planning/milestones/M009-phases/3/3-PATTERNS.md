# Phase 3: Operator UI - Add a powerful cmd+k search bar to the LiveView dashboard - Pattern Map

**Mapped:** 2024-05-17
**Files analyzed:** 2
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/search_modal_component.ex` | component | request-response | `lib/cairnloop/web/conversation_live.ex` | role-match |
| `lib/cairnloop/web/inbox_live.ex` | view | request-response | `lib/cairnloop/web/conversation_live.ex` | role-match |

## Pattern Assignments

### `lib/cairnloop/web/search_modal_component.ex` (component, request-response)

**Analog:** `lib/cairnloop/web/conversation_live.ex` (for LiveView events) and `lib/cairnloop/workers/ingest_scrypath.ex` (for Scrypath API call via Req)

**Imports pattern:**
```elixir
  use Phoenix.LiveComponent
```

**Core UI / Component Pattern** (from `lib/cairnloop/web/conversation_live.ex` lines 188-219):
```elixir
  def context_pane(assigns) do
    assigns =
      assign(
        assigns,
        :available_tools,
        Cairnloop.ToolRegistry.get_available_tools(assigns.actor_id, assigns.context)
      )

    ~H"""
    <div class={["rail-card host-context", @error && "error"]}>
      <h3>Customer Context</h3>
      <%= if @error do %>
        <p>Customer context is unavailable right now. Continue handling the conversation, then reload to try again.</p>
      <% else %>
...
```

**Event Handling Pattern** (from `lib/cairnloop/web/conversation_live.ex` lines 47-59):
```elixir
  def handle_event("edit_draft", %{"draft-id" => draft_id}, socket) do
    draft_id = String.to_integer(draft_id)
    draft = Enum.find(socket.assigns.conversation.drafts, &(&1.id == draft_id))

    case Cairnloop.Automation.mark_draft_edited(draft_id) do
      {:ok, _} ->
        socket =
          socket
          |> reload_conversation_with_context(socket.assigns.conversation.id)
          |> assign(form: to_form(%{"content" => draft.content}))

        {:noreply, socket}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to edit draft.")}
    end
  end
```

**Scrypath API Call Pattern** (from `lib/cairnloop/workers/ingest_scrypath.ex` lines 11-18):
```elixir
    req = 
      Req.new(
        url: api_url,
        auth: {:bearer, api_key}
      )
      |> Req.merge(req_options)

    case Req.post(req, json: %{conversation_id: id, text: text}) do
```

---

### `lib/cairnloop/web/inbox_live.ex` (view, request-response)

**Analog:** `lib/cairnloop/web/conversation_live.ex`

**Component Mounting Pattern** (from `lib/cairnloop/web/conversation_live.ex` lines 135-136):
```elixir
  def render(assigns) do
    ~H"""
    <.live_component module={Cairnloop.Web.SearchModalComponent} id="search-modal" />
```

---

## Shared Patterns

### Req API Integration
**Source:** `lib/cairnloop/workers/ingest_scrypath.ex`
**Apply to:** `search_modal_component.ex` search function
```elixir
    api_url = Application.get_env(:cairnloop, :scrypath_api_url, "https://api.scrypath.local/v1/index")
    api_key = Application.get_env(:cairnloop, :scrypath_api_key, "dummy")
    
    req_options = Application.get_env(:cairnloop, :scrypath_req_options, [])
```

### Flash Error Handling
**Source:** `lib/cairnloop/web/conversation_live.ex`
**Apply to:** All LiveView handle_event functions
```elixir
    {:noreply, put_flash(socket, :error, "Failed operation message.")}
```

## Metadata

**Analog search scope:** `lib/cairnloop/web/`, `lib/cairnloop/workers/`
**Files scanned:** 4
**Pattern extraction date:** 2024-05-17
