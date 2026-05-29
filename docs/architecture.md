# System Architecture

Cairnloop is not a standalone SaaS product. It is an embedded support operations layer designed to be mounted directly inside your Phoenix application's router and supervised by your application's supervision tree.

This architecture document explains how Cairnloop's internal components interact, how they connect to your host application, and how external AI tools integrate securely.

## The Core Philosophy: Host-Owned Everything

When you integrate Cairnloop, your Phoenix app remains the source of truth.
*   **Data:** Conversations and messages are stored in your database (via `cairnloop_conversations`).
*   **Context:** Operator context (like user plans or billing history) is pulled dynamically from your app via the `ContextProvider` behaviour. It is never synced to an external API.
*   **Identity:** Support agents log in using your existing authentication system.
*   **Side Effects:** When a conversation resolves, Cairnloop calls your `Notifier` behaviour. Your app decides whether to fire a webhook, send an email, or update a CRM.

## System Overview

```text
┌────────────────────────────────────────────────────────────────────┐
│                    Host Phoenix Application                        │
│  ┌──────────────┐  ┌──────────────────┐  ┌───────────────────────┐ │
│  │  Host        │  │  cairnloop_      │  │  Host                 │ │
│  │  Router      │  │  dashboard       │  │  Behaviours           │ │
│  │  (Auth)      │  │  (macro mount)   │  │  (Notifier, Context)  │ │
│  └──────┬───────┘  └──────────────────┘  └───────────────────────┘ │
└─────────┼──────────────────────────────────────────────────────────┘
          │ forward "/mcp"
┌─────────▼──────────────────────────────────────────────────────────┐
│               Cairnloop Library (hex: cairnloop)                   │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Cairnloop.Web.MCP.Auth (Plug)                               │  │
│  │    - Validates Bearer token against Cairnloop.MCP.Token      │  │
│  │    - Injects actor_id and scopes into conn.private           │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │ validated conn                           │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Cairnloop.Web.MCP.Router                                    │  │
│  │    - Handles tools/list and tools/call JSON-RPC              │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │ JSON-RPC Payload                         │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Cairnloop.Web.MCP.ToolCallHandler                           │  │
│  │    - Converts payload to Governance context                  │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │ propose/3                                │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Cairnloop.Governance (The Core Engine)                      │  │
│  │    - Evaluates AutomationPolicy (require_approval vs allow)  │  │
│  │    - Creates ToolProposal (durable state)                    │  │
│  │    - Manages ToolApproval state machine                      │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │ async execution                          │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Oban Workers                                                │  │
│  │    - ToolExecutionWorker (Sole executor of Tool.run/3)       │  │
│  │    - ApprovalResumeWorker                                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### 1. LiveView Dashboard (`cairnloop_dashboard`)
A set of encapsulated LiveViews providing the operator inbox, conversation workspace, and knowledge base management. It is mounted via a macro in your router and relies entirely on your application's session authentication.

### 2. The Governance Engine (`Cairnloop.Governance`)
The central nervous system of Cairnloop. Whether a tool is invoked by a human clicking a button, an AI drafting a reply, or an external MCP client making an API call, it **must** pass through `Governance.propose/3`.

The Governance engine ensures that:
*   Policies (`AutomationPolicy`) are evaluated.
*   Risk tiers (`:read_only` vs `:requires_approval`) are enforced.
*   Idempotency tokens are respected.
*   A durable `ToolProposal` record is created in the database.

### 3. Asynchronous Execution (Oban)
Cairnloop relies on Oban for reliable, retriable background job execution. `ToolExecutionWorker` is the *only* module authorized to call a tool's `run/3` function. This guarantees that all tool executions are captured in the audit log and cannot bypass the governance gates.

### 4. MCP OAuth Seam (`Cairnloop.Web.MCP.Auth`)
External clients (like Claude Desktop) connect via the Model Context Protocol (MCP). Cairnloop provides the Resource Server.

The `MCP.Auth` Plug acts as middleware, validating incoming Bearer tokens against the `mcp_tokens` database table. The raw token is hashed (`sha256`); Cairnloop never stores raw secrets. If valid, the Plug injects the associated `actor_id` and `scopes` into `conn.private` for the downstream router. The host application is responsible for the Authorization Server (token issuance).

### 5. Host Extension Points (`@callback` Behaviours)
Cairnloop delegates business logic back to the host via standard Elixir behaviours:
*   **`ContextProvider`**: Read-only extraction of customer data.
*   **`Notifier`**: Write-oriented side-effects (e.g., syncing CRM state after a resolution).
*   **`AutomationPolicy`**: Governance rules for AI actions.
*   **`SLAPolicyProvider`**: Dynamic SLA threshold definitions.
*   **`Tool`**: Custom, governable actions exposed to operators and AIs.

By adhering to this embedded architecture, Cairnloop provides the operational rigor of a SaaS support desk without the data silos or integration latency.
