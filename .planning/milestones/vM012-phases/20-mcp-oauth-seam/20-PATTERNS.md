# Phase 20: MCP OAuth Seam - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/mcp/token.ex` | model | CRUD | `lib/cairnloop/governance/tool_proposal.ex` | role-match |
| `lib/cairnloop/mcp.ex` | service / context | CRUD | `lib/cairnloop/governance.ex` | role-match |
| `lib/cairnloop/web/mcp/auth_plug.ex` | middleware / plug | request-response | `lib/cairnloop/web/mcp/router.ex` | exact |
| `lib/cairnloop/web/mcp/well_known_plug.ex` | middleware / plug | request-response | `lib/cairnloop/web/mcp/router.ex` | exact |
| `priv/repo/migrations/[timestamp]_create_cairnloop_mcp_tokens.exs` | migration | batch | `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs` | exact |

## Pattern Assignments

### `lib/cairnloop/mcp/token.ex` (model, CRUD)

**Analog:** `lib/cairnloop/governance/tool_proposal.ex`

**Imports and Moduledoc pattern** (lines 1-17):
```elixir
defmodule Cairnloop.MCP.Token do
  @moduledoc """
  Durable token record for MCP OAuth Bearer authentication.
  """

  use Ecto.Schema
  import Ecto.Changeset
```

**Schema pattern** (lines 24-52):
```elixir
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "cairnloop_mcp_tokens" do
    field(:name, :string)
    field(:token_hash, :binary)
    field(:expires_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end
```

**Changeset pattern** (lines 59-79):
```elixir
  @doc """
  Standard changeset for creating a Token.
  """
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:name, :token_hash, :expires_at, :revoked_at])
    |> validate_required([:name, :token_hash])
    |> unique_constraint(:token_hash)
  end
```

---

### `lib/cairnloop/mcp.ex` (service / context, CRUD)

**Analog:** `lib/cairnloop/governance.ex`

**Context Structure pattern** (lines 1-30):
```elixir
defmodule Cairnloop.MCP do
  @moduledoc """
  Public facade for the MCP token management and validation.
  """

  require Logger
  import Ecto.Query

  alias Cairnloop.MCP.Token
```

**Repo fetching pattern** (lines 40-42):
```elixir
  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end
```

---

### `lib/cairnloop/web/mcp/auth_plug.ex` & `lib/cairnloop/web/mcp/well_known_plug.ex` (middleware / plug, request-response)

**Analog:** `lib/cairnloop/web/mcp/router.ex`

**Plug Declaration pattern** (lines 28-35):
```elixir
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts
```

**Error Formatting (if applicable)** (lines 80-89):
```elixir
  defp json_error(conn, id, code, message) do
    body =
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => %{"code" => code, "message" => message}
      })

    conn |> put_resp_content_type("application/json") |> send_resp(200, body)
  end
```

---

### `priv/repo/migrations/..._create_cairnloop_mcp_tokens.exs` (migration, batch)

**Analog:** `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs`

**Migration Table and Timestamps pattern** (lines 4-22):
```elixir
defmodule Cairnloop.Repo.Migrations.CreateCairnloopMcpTokens do
  use Ecto.Migration

  def change do
    create table(:cairnloop_mcp_tokens, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:name, :string, null: false)
      add(:token_hash, :binary, null: false)
      add(:expires_at, :utc_datetime_usec)
      add(:revoked_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end
```

**Indexes pattern** (lines 24-29):
```elixir
    # Unique index for token hashes
    create(unique_index(:cairnloop_mcp_tokens, [:token_hash]))
  end
end
```

## Shared Patterns

### Plug Construction
**Source:** `lib/cairnloop/web/mcp/router.ex`
**Apply to:** All MCP plugs (AuthPlug, WellKnownPlug)
```elixir
  @behaviour Plug
  import Plug.Conn
  
  @impl Plug
  def init(opts), do: opts
```

### Context Repo Integration
**Source:** `lib/cairnloop/governance.ex`
**Apply to:** Context Modules
```elixir
  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end
```

## Metadata

**Analog search scope:** `lib/cairnloop/**/*.ex`, `lib/cairnloop/web/**/*.ex`, `priv/repo/migrations/*.exs`
**Files scanned:** 127
**Pattern extraction date:** 2026-05-26
