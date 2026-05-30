# Phase 35: Audit & Operations Support - Pattern Map

**Mapped:** 2024-05-24
**Files analyzed:** 4 new/modified features
**Analogs found:** 4 / 4

## File Classification

| New/Modified Feature | Role | Data Flow | Closest Analog | Match Quality |
|----------------------|------|-----------|----------------|---------------|
| `AuditLogLive` | view | request-response | `lib/cairnloop/web/inbox_live.ex` | role-match |
| `/health` Plug | route/plug | request-response | `lib/cairnloop/ingress/email_webhook_plug.ex` | exact |
| `/metrics` Plug | route/plug | request-response | `lib/cairnloop/web/mcp/router.ex` | exact |
| Rail pagination | component | state-update | `lib/cairnloop/web/conversation_live.ex` | exact |

## Pattern Assignments

### `Cairnloop.Web.AuditLogLive` (LiveView)

**Analog:** `lib/cairnloop/web/settings_live.ex` / `lib/cairnloop/web/inbox_live.ex`

**Imports pattern:**
```elixir
defmodule Cairnloop.Web.AuditLogLive do
  use Phoenix.LiveView

  import Ecto.Query
```

**Core pattern (mount and render):**
Like `InboxLive`, setting up state and rendering a simple list without streams.
```elixir
  def mount(_params, session, socket) do
    # Requires new retrieval mechanism, see note below.
    events = [] 

    {:ok,
     assign(socket,
       events: events,
       host_user_id: Map.get(session, "host_user_id")
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="cairnloop-audit-log">
      <h1>Audit Log</h1>
      <!-- list UI similar to InboxLive -->
    </div>
    """
  end
```

**Auditor Retrieval Note:**
Currently, `Cairnloop.Auditor` events are persisted by injecting Ecto.Multi operations via the behaviour (`auditor.audit(multi, :action, actor, metadata)` in `Cairnloop.Chat`, `Cairnloop.Outbound`, etc.), delegating to the host application's own schema. There is **no existing retrieval pattern** in the codebase (no `list_events` callback). To build `AuditLogLive`, the `Cairnloop.Auditor` behaviour must be expanded with a `search/1` or `list_events/1` callback, or Cairnloop must introduce an internal `Cairnloop.AuditLog` schema fallback to query from.

---

### `/health` and `/metrics` (Plugs)

**Analog:** `lib/cairnloop/ingress/email_webhook_plug.ex`

**Imports & Core pattern:**
Exposed as modular Plugs to be forwarded in the host's Phoenix router.
```elixir
defmodule Cairnloop.Web.HealthPlug do
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    health_status = %{status: "ok"} # Or call internal health checks

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(health_status))
  end
end
```
*(Similarly for `MetricsPlug`, outputting Prometheus/Telemetry format instead of JSON)*

---

### Governed-actions Rail Pagination (ConversationLive)

**Analog:** `lib/cairnloop/web/conversation_live.ex` + `lib/cairnloop/governance.ex`

**Backend Pattern (limit/offset via Ecto):**
Existing Ecto queries (e.g. `cairnloop/knowledge_base.ex`) use the Ecto `limit` function via `Keyword.get(opts, :limit, default)`. `Cairnloop.Governance.list_proposals_for_conversation/1` must be updated to accept `opts` (limit, offset).
```elixir
  # In Cairnloop.Governance
  def list_proposals_for_conversation(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    
    # ... existing query ...
    |> limit(^limit)
    |> offset(^offset)
    |> repo().all()
  end
```

**LiveView State Pattern:**
Per AR-14-02 and D-02 ("plain-assign, no streams"), pagination should use state in `ConversationLive` with standard "Load more" semantics without Phoenix streams.
```elixir
  # In ConversationLive mount/handle_event
  assigns = Map.put_new(assigns, :governed_actions, [])
  assigns = Map.put_new(assigns, :governed_actions_page, 1)

  # In handle_event for "load_more_actions":
  # fetch next page, append to existing list:
  # updated_actions = socket.assigns.governed_actions ++ new_actions
```

## Shared Patterns

### HTTP Endpoints
**Source:** `lib/cairnloop/web/mcp/router.ex`
**Apply to:** `/health` and `/metrics`
Host integration pattern is to instruct adopters to mount via `forward` in their Phoenix router:
```elixir
  ## Host integration
  # Mount this Plug via `forward` in the host's Phoenix router:
  #     forward "/health", Cairnloop.Web.HealthPlug
```

### Pagination
**Source:** Standard Ecto + LiveView Plain Assign (no `Phoenix.LiveView.stream`)
**Apply to:** `ConversationLive` governed-actions rail.

## Metadata

**Analog search scope:** `lib/cairnloop/web/*.ex`, `lib/cairnloop/auditor.ex`, `lib/cairnloop/governance.ex`
**Files scanned:** ~25
