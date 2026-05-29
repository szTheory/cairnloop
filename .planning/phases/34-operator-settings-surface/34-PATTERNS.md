# Phase 34: Operator Settings Surface - Pattern Map

**Mapped:** 2024-05-18
**Files analyzed:** 1 (`lib/cairnloop/web/settings_live.ex`)
**Analogs found:** 1 / 1

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/settings_live.ex` | controller | request-response | `lib/cairnloop/web/settings_live.ex` | exact |

## Pattern Assignments

### `lib/cairnloop/web/settings_live.ex` (controller, request-response)

**Analog:** `lib/cairnloop/web/settings_live.ex` (Self-expansion) and `lib/cairnloop/mcp.ex` (Context)

**Imports pattern** (lines 1-3):
```elixir
defmodule Cairnloop.Web.SettingsLive do
  use Phoenix.LiveView
  alias Cairnloop.MCP
```

**MCP Token CRUD Pattern (SET-01)**
Analog: SLA form handling and flash alerts in `SettingsLive.ex` (lines 4-43).
```elixir
  def handle_event("create_token", %{"token" => params}, socket) do
    case Cairnloop.MCP.issue_token(params) do
      {:ok, _token, raw_token} ->
        {:noreply,
         socket 
         |> put_flash(:info, "Token created: #{raw_token}. Please save it now.")
         |> load_tokens()}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create token.")}
    end
  end
```

**Configuration Lookups & Health (SET-02 & SET-03)**
Analog: Initialization in `SettingsLive.mount/3` (lines 4-15) and Notifier checks in `lib/cairnloop/workers/notify_resolved_worker.ex` (lines 7-9).
```elixir
  def mount(_params, session, socket) do
    notifier = Application.get_env(:cairnloop, :notifier)
    notifier_configured? = is_atom(notifier) and not is_nil(notifier)
    
    socket =
      socket
      |> assign(:notifier, notifier)
      |> assign(:notifier_health, notifier_configured? && Code.ensure_loaded?(notifier))
      # Retrieval health evaluation delegated to Context layer
      |> assign(:retrieval_health, Cairnloop.Retrieval.system_health())
```

**Dark Mode Toggle / UI Event Pattern (SET-04)**
Analog: Standard `handle_event` combined with CSS custom properties (defined in `prompts/cairnloop.css` as `[data-theme="dark"]`).
```elixir
  def handle_event("toggle_theme", _params, socket) do
    # Requires client-side JS Hook for localStorage persistence, 
    # but state is driven by UI assignments here.
    theme = if socket.assigns.theme == "dark", do: "light", else: "dark"
    {:noreply, assign(socket, :theme, theme)}
  end
```

**Form Display and Flash Alerts**
Analog: `SettingsLive.ex` render flash and list displays (lines 56-94).
```elixir
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div class="alert alert-info" role="alert"><%= flash %></div>
      <% end %>
      
      <div class="tokens-list">
        <h2>Active Tokens</h2>
        <ul>
           <!-- Token list rendering -->
        </ul>
      </div>
```

## Shared Patterns

### Configuration Access
**Source:** `lib/cairnloop/workers/notify_resolved_worker.ex`
**Apply to:** Notifier checks in `SettingsLive`.
```elixir
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        # Notifier is configured
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns if available):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Theme Persistence | hook | UI / LocalStorage | No existing JavaScript Hook handles dark mode persistence, though `cairnloop.css` natively supports `[data-theme="dark"]`. A new Hook is required. |
| Retrieval Health Query | context | database | There are no existing pgvector extension status queries. Ecto `query!` must be invoked directly to assess index capability. |

## Metadata

**Analog search scope:** `lib/cairnloop/web/`, `lib/cairnloop/mcp/`, `lib/cairnloop/workers/`
**Files scanned:** 23
**Pattern extraction date:** 2024-05-18
