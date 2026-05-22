# Phase M006-S03: LiveView SLA Configuration - Pattern Map

**Mapped:** 2024-05-15
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/cairnloop/install.sla.ex` | generator | file-I/O | `lib/mix/tasks/cairnloop/install.ex` | good match |
| `lib/cairnloop/sla_policy_provider.ex` | behaviour | interface | `lib/cairnloop/context_provider.ex` | exact |
| `lib/cairnloop/web/settings_live.ex` | component | request-response | `lib/cairnloop/web/inbox_live.ex` | role-match |
| `lib/cairnloop/router.ex` | route | request-response | `lib/cairnloop/router.ex` (`cairnloop_dashboard/2`) | exact |

## Pattern Assignments

### `lib/mix/tasks/cairnloop/install.sla.ex` (generator, file-I/O)

**Analog:** `lib/mix/tasks/cairnloop/install.ex`

**Igniter boilerplate pattern** (lines 1-13):
```elixir
defmodule Mix.Tasks.Cairnloop.Install do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :cairnloop,
      schema: [],
      defaults: []
    }
  end
```

**Ecto Schema generation pattern** (lines 16-25):
```elixir
    igniter
    |> Igniter.Libs.Ecto.select_repo()
    |> case do
      {igniter, nil} ->
        Igniter.add_issue(
          igniter,
          "No Ecto repo found. Please create a migration manually for cairnloop tables."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
```

**Migration table pattern** (lines 28-33):
```elixir
          body: """
            def change do
              create table(:cairnloop_conversations) do
                add :status, :string, null: false
                add :subject, :string
                # Pattern for SLA priorities and integer columns:
                # add :priority, :string, null: false (or use Ecto.Enum)
                # add :target_first_response_minutes, :integer, null: false
```

---

### `lib/cairnloop/sla_policy_provider.ex` (behaviour, interface)

**Analog:** `lib/cairnloop/context_provider.ex`

**Behaviour definition pattern** (lines 1-4, 25-27):
```elixir
defmodule Cairnloop.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context to Cairnloop.
  ...
  """

  @doc """
  Retrieves context details for a given identity.
  """
  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
```
*Note: SLAPolicyProvider should follow this structure to provide SLA policies configured in the host application.*

---

### `lib/cairnloop/router.ex` (route, request-response)

**Analog:** `lib/cairnloop/router.ex`

**Macro injection pattern** (lines 2-9):
```elixir
  defmacro cairnloop_dashboard(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :cairnloop_dashboard, opts do
          live("/", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
          # Add new route here:
          # live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
          live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
        end
      end
    end
  end
```

---

### `lib/cairnloop/web/settings_live.ex` (component, request-response)

**Analog:** `lib/cairnloop/web/inbox_live.ex`

**LiveView module pattern** (lines 1-8):
```elixir
defmodule Cairnloop.Web.InboxLive do
  use Phoenix.LiveView

  alias Cairnloop.Chat

  def mount(_params, _session, socket) do
    # Mount logic for settings
    {:ok, assign(socket, settings: load_settings())}
  end
```

**LiveView render pattern** (lines 14-22):
```elixir
  def render(assigns) do
    ~H"""
    <div class="cairnloop-inbox">
      <h1>Inbox</h1>
      <!-- Settings form goes here -->
    </div>
    """
  end
```

## Shared Patterns

### Host-App Configuration Provider
**Source:** `lib/cairnloop/context_provider.ex`
**Apply to:** `Cairnloop.SLAPolicyProvider`
All host app integrations should use a behaviour with a tagged tuple return type `{:ok, term()} | {:error, term()}`.

### Ecto Migrations via Igniter
**Source:** `lib/mix/tasks/cairnloop/install.ex`
**Apply to:** `lib/mix/tasks/cairnloop/install.sla.ex`
Always use `Igniter.Libs.Ecto.select_repo()` to find the host's repo before generating migrations. Use string literals for table definitions with explicit types.

## Metadata

**Analog search scope:** `lib/**/*.ex`
**Files scanned:** 4
**Pattern extraction date:** 2024-05-15
