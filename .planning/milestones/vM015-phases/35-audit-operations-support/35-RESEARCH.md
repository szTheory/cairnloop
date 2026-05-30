# Phase 35: Audit & Operations Support - Research

**Researched:** 2024-05-24
**Domain:** Audit logging and operational observability (health/metrics endpoints)
**Confidence:** HIGH

## Summary

This phase introduces an operational `AuditLogLive` dashboard for operators and two standard observability endpoints (`/health` and `/metrics`) for adopters. It also addresses unbounded DOM growth on the governed actions rail by implementing limit-based plain-assign pagination.

**Primary recommendation:** Extend `Cairnloop.Auditor` behaviour with a `list_events/1` callback and implement default retrieval. Supply `Cairnloop.Web.HealthPlug` and `Cairnloop.Web.MetricsPlug` using `:telemetry_metrics_prometheus_core` as an optional dependency. Add limit-based querying to `Governance.list_proposals_for_conversation/2` with plain-assign state in `ConversationLive`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| **Audit Event Querying** | API / Backend | Browser / Client | `Cairnloop.Auditor` behaviour must act as the primary interface for fetching host-persisted audit logs to render in the UI. |
| **Health Probes** | API / Backend | — | Simple Plug answering `200 OK` for liveness/readiness without heavy dependencies. |
| **Metrics Exporter** | API / Backend | — | Plugs into host router to export `Telemetry.Metrics` in Prometheus format via `telemetry_metrics_prometheus_core`. |
| **Rail Pagination** | Browser / Client | API / Backend | LiveView plain-assign state (`limit`) coupled with Ecto limit clauses on backend queries to handle DOM cap. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:telemetry` | (Transitive) | Event emission | Native Erlang/Elixir telemetry standard already used in Cairnloop. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `:telemetry_metrics_prometheus_core` | `~> 1.2` | Prometheus formatting | Optional dependency used by `Cairnloop.Web.MetricsPlug` to format metrics without running a separate HTTP server. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `telemetry_metrics_prometheus_core` | `telemetry_metrics_prometheus` | The non-core package starts its own Bandit/Cowboy server or defines its own Plug router. `core` just provides the `scrape/1` formatter string, keeping Cairnloop's Plug stateless and flexible. |
| Extending `Auditor` behaviour | Internal `Cairnloop.AuditLog` schema | An internal schema breaks the established `Cairnloop.Auditor` contract where the host application owns audit persistence via Ecto.Multi. |
| Phoenix Streams | Plain-assign with `limit` | Streams add complexity for bidirectional sync. AR-14-02 explicitly dictates plain-assign for the conversation rails. |

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `telemetry_metrics_prometheus_core` | hex | 3 yrs | 10M+ | github.com/beam-telemetry/telemetry_metrics_prometheus_core | [OK] | Approved |

*Note: Package is added to `mix.exs` as `optional: true`.*

## Architecture Patterns

### Pattern 1: Pluggable Auditor Retrieval (AUDIT-01)
**What:** The `Cairnloop.Auditor` behaviour is currently write-only (injects Ecto.Multi operations). It must be expanded to support reads so `AuditLogLive` can display events.
**When to use:** For querying host-owned audit logs.
**Example:**
```elixir
# In lib/cairnloop/auditor.ex
@callback list_events(opts :: keyword()) :: [map()]

# Default implementation (Cairnloop.Auditor.NoOp)
@impl true
def list_events(_opts), do: []

# In lib/cairnloop/web/audit_log_live.ex
def mount(_params, session, socket) do
  auditor = Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
  events = auditor.list_events([])
  
  {:ok, assign(socket, events: events)}
end
```
**Route:** `AuditLogLive` should be mounted at `/audit-log` in `Cairnloop.Router.cairnloop_dashboard/2`.

### Pattern 2: Lightweight Optional Metrics Exporter (OPS-02)
**What:** Exposing metrics without forcing a dependency.
**When to use:** `Cairnloop.Web.MetricsPlug` provides a Prometheus endpoint only if the host optionally includes `:telemetry_metrics_prometheus_core`.
**Example:**
```elixir
defmodule Cairnloop.Web.MetricsPlug do
  @behaviour Plug
  import Plug.Conn

  def init(opts), do: Keyword.get(opts, :reporter, Cairnloop.MetricsReporter)

  def call(conn, reporter) do
    if Code.ensure_loaded?(TelemetryMetricsPrometheus.Core) do
      metrics = TelemetryMetricsPrometheus.Core.scrape(reporter)
      conn |> put_resp_content_type("text/plain") |> send_resp(200, metrics)
    else
      send_resp(conn, 501, "Metrics require :telemetry_metrics_prometheus_core optional dependency")
    end
  end
end
```

### Pattern 3: Plain-Assign Limit Pagination (TECH-01)
**What:** Appending data via plain-assign by tracking `limit` in socket state and applying it to backend Ecto queries, preventing unbounded DOM rendering without `Phoenix.LiveView.stream`.
**When to use:** For the governed-actions rail per AR-14-02 closure.
**Example:**
```elixir
# In lib/cairnloop/governance.ex
def list_proposals_for_conversation(conversation_id, opts \\ []) do
  limit = Keyword.get(opts, :limit)

  query = ToolProposal |> where([p], p.conversation_id == ^conversation_id) |> order_by([p], desc: p.inserted_at)
  query = if limit, do: limit(query, ^limit), else: query
  
  query |> preload(events: ^events_query, approval: []) |> repo().all()
end

# In lib/cairnloop/web/conversation_live.ex
def handle_event("load_more_actions", _, socket) do
  limit = socket.assigns.governed_actions_limit + 10
  {:noreply, 
    socket 
    |> assign(governed_actions_limit: limit)
    |> reload_conversation_with_context(socket.assigns.conversation.id)
  }
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Prometheus text formatting | Custom string builders over `:telemetry` | `:telemetry_metrics_prometheus_core` (optional) | The Prometheus exposition format is strictly defined and error-prone to hand-roll. |
| Internal Audit Schema | A secondary audit table | `Cairnloop.Auditor` behavior extensions | Cairnloop's philosophy dictates the host owns audit data. Syncing an internal table duplicates data and breaks the single source of truth. |

## Common Pitfalls

### Pitfall 1: Uncapped Plain Assigns
**What goes wrong:** High volume conversations crash the browser due to massive DOM nodes in the governed actions rail.
**Why it happens:** Fetching `repo().all()` without a limit clause.
**How to avoid:** TECH-01 mandates adding a `limit` state to `ConversationLive` and pushing that limit down to `Governance.list_proposals_for_conversation/2`.

### Pitfall 2: Forcing Web Server Dependencies
**What goes wrong:** Adding `telemetry_metrics_prometheus` adds an embedded web server (Cowboy/Bandit) to a library context.
**Why it happens:** Not realizing `telemetry_metrics_prometheus_core` exists for pure text formatting.
**How to avoid:** Use `telemetry_metrics_prometheus_core` as an optional dependency; build a simple standard Plug to serve the text payload.

## Open Questions

1. **Host Auditing Schema Format**
   - What we know: The `list_events/1` callback needs to return maps or structs that the UI can blindly render.
   - What's unclear: Does `AuditLogLive` need a canonical struct like `%Cairnloop.AuditLog.Event{}` to enforce the shape of returned maps?
   - Recommendation: Define a lightweight struct (e.g. `%Cairnloop.Auditor.Event{id, action, actor, metadata, inserted_at}`) so the host implementation knows exactly what shape to return.