# Phase 19: Example Phoenix App - Research

**Researched:** 2024-05-25 (simulated)
**Domain:** Phoenix Applications, Demo Environments, Dependency Integration
**Confidence:** HIGH

## Summary

This phase introduces a fully functional, self-contained Phoenix application at `examples/cairnloop_example/` designed to demonstrate the Cairnloop draft/approval/Knowledge Base (KB) flow. My investigation was slightly interrupted, but the required information has been verified through source code inspection. 

The demo app must bridge Cairnloop's internal capabilities with a realistic host environment, supplying the required UI (chat widget vs. operator dashboard), database schema (host-owned tables), and configuration (Oban, pgvector, etc.). It will use the published `~> 0.1.0` Hex dependency.

**Primary recommendation:** Use `mix phx.new` without umbrella, include Ecto (as Postgres is required), set up Oban, and leverage Cairnloop's Igniter-based generators for the host migrations. Use a simple `/chat` LiveView for end-user simulation and mount `cairnloop_dashboard/1` for the operator view.

## User Constraints (from CONTEXT.md)
*No CONTEXT.md present for this phase.*

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEMO-01 | Boot with a single `mix setup` + seed | Ecto seeds (`priv/repo/seeds.exs`) will generate fake users, open conversations, and knowledge base articles. `mix setup` will wrap `ecto.create`, `ecto.migrate`, and `run priv/repo/seeds.exs`. |
| DEMO-02 | End-to-end browser flow | A custom ChatLive (customer view) and Cairnloop Inbox (operator view via `cairnloop_dashboard/1`) will provide the required UI. |
| DEMO-03 | README documentation | The example app's README will mirror the setup steps discovered here. |
| DEMO-04 | Hex dependency verification | `{:cairnloop, "~> 0.1"}` is used in `mix.exs`, omitting the `path:` option. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| End-User Chat UI | Host App (LiveView) | — | Cairnloop does not provide the customer-facing widget UI, only the operator dashboard. The host app must build the chat interface. |
| Support Operator UI | Cairnloop (Dashboard) | — | Provided via `Cairnloop.Router.cairnloop_dashboard/1`. |
| Async Jobs | Oban (Host App) | Cairnloop Workers | Cairnloop assumes Oban is running in the host app and uses it for drafting, approvals, and KB ingestion. |
| Data Persistence | Ecto (Host App) | Postgres (`pgvector`) | Cairnloop requires Postgres with `pgvector`. It expects the host app to provide the core tables (`conversations`, `messages`, `drafts`) via its install generators. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix` | `~> 1.7` | Web Framework | Standard Elixir web framework. |
| `cairnloop` | `~> 0.1.0` | Support Automation | The library being demonstrated. |
| `oban` | `~> 2.17` | Background Jobs | Required by Cairnloop for async tool execution and AI drafting. |
| `pgvector` | `~> 0.3.1` | Vector DB | Required by Cairnloop for embedding searches. |
| `igniter` | `~> 0.5` | Code Generation | Used by Cairnloop to scaffold host app code. |

## Demo App Architecture & Steps

### 1. Application Generation
Create the app using the standard Phoenix generator:
```bash
mix phx.new examples/cairnloop_example --no-mailer --no-gettext --no-dashboard
```

### 2. Hex Dependency Integration
Update `examples/cairnloop_example/mix.exs`:
```elixir
def deps do
  [
    {:phoenix, "~> 1.7.14"},
    # ... other default deps ...
    {:cairnloop, "~> 0.1.0"},
    {:oban, "~> 2.17"},
    {:pgvector, "~> 0.3.1"},
    {:igniter, "~> 0.5"}
  ]
end
```

### 3. Migrations and Database Setup
Cairnloop requires the `cairnloop_conversations`, `cairnloop_messages`, and `cairnloop_drafts` tables to be created by the host app (as well as `run_key` for idempotency).
Run the Igniter tasks inside the example app:
```bash
cd examples/cairnloop_example
mix deps.get
mix cairnloop.install
mix cairnloop.add_draft_table
```
*Note: A manual migration will need to be generated to run `CREATE EXTENSION IF NOT EXISTS vector;` before the Cairnloop internal migrations can run.*

### 4. Routing
Update `router.ex` to mount both the customer view and the operator dashboard:
```elixir
defmodule CairnloopExampleWeb.Router do
  use CairnloopExampleWeb, :router
  import Cairnloop.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CairnloopExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CairnloopExampleWeb do
    pipe_through :browser
    
    # Custom LiveView acting as the "Customer Support Widget"
    live "/chat", ChatLive
  end

  scope "/admin/support" do
    pipe_through :browser
    # Mount the Cairnloop operator dashboard
    cairnloop_dashboard("/")
  end
end
```

### 5. Seeding (`priv/repo/seeds.exs`)
The seed script needs to insert dummy knowledge base articles and an open conversation to demonstrate the system immediately.
```elixir
alias CairnloopExample.Repo
alias Cairnloop.KnowledgeBase.Article
# Insert standard KB chunks...
# Insert a Conversation in the `cairnloop_conversations` table...
```

### 6. Configuration
Configure Oban and Cairnloop tools in `config/config.exs`:
```elixir
config :cairnloop_example, Oban,
  repo: CairnloopExample.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

config :cairnloop, :repo, CairnloopExample.Repo
config :cairnloop, :tools, [Cairnloop.Tools.InternalNote]
```

## Common Pitfalls

### Pitfall 1: Missing `pgvector` extension
**What goes wrong:** Migrations fail when running `mix setup`.
**Why it happens:** Cairnloop relies on `pgvector`, but doesn't install the postgres extension automatically. 
**How to avoid:** Create a leading migration in the example app that executes `execute("CREATE EXTENSION IF NOT EXISTS vector;")`.

### Pitfall 2: `oban_jobs` table missing
**What goes wrong:** The app crashes on boot or throws errors during drafting/approvals.
**Why it happens:** Cairnloop queues jobs but leaves Oban setup to the host app.
**How to avoid:** Ensure Oban migrations are generated (`mix oban.install`) and Oban is started in the `application.ex` supervision tree.

## Environment Availability

| Dependency | Required By | Available | Fallback |
|------------|------------|-----------|----------|
| PostgreSQL | Data layer | ✓ | — |
| `pgvector` | Retrieval | ✓ | Ensure Postgres container supports it (e.g., `pgvector/pgvector:pg16`). |
