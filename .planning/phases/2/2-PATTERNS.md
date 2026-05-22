# Phase 2: The Notifier Behaviour & Chimeway - Pattern Map

**Mapped:** 2024-05-24
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/workers/check_sla.ex` | worker | event-driven | `lib/cairnloop/workers/notify_resolved_worker.ex` | exact |
| `lib/cairnloop/notifier.ex` | behaviour | event-driven | `lib/cairnloop/context_provider.ex` | role-match |
| `lib/cairnloop/notifier/chimeway.ex` | adapter | event-driven/push | `lib/cairnloop/default_context_provider.ex` | role-match |

## Pattern Assignments

### `lib/cairnloop/workers/check_sla.ex` (worker, event-driven)

**Analog:** `lib/cairnloop/workers/notify_resolved_worker.ex`

**Imports pattern** (lines 1-2):
```elixir
defmodule Cairnloop.Workers.NotifyResolvedWorker do
  use Oban.Worker, queue: :default
```

**Core Execution & Configuration pattern** (lines 4-13):
```elixir
  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id, "metadata" => metadata}}) do
    conversation = Cairnloop.Chat.get_conversation!(conversation_id)
    
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_conversation_resolved(conversation, Enum.into(metadata, %{}))

      _ ->
        :ok
    end
  end
```

---

### `lib/cairnloop/notifier.ex` (behaviour, event-driven)

**Analog:** `lib/cairnloop/context_provider.ex`

**Imports and Moduledoc pattern** (lines 1-19):
```elixir
defmodule Cairnloop.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context to Cairnloop.

  Cairnloop uses this behaviour to achieve a zero-API-sync design. Host applications
  implement this behaviour to directly return a map containing their internal domain
  data (like billing status, lifetime value, etc.) bound to a support ticket's actor.

  The returned map should be a deeply nested map of simple Elixir terms (strings,
  numbers, booleans, dates) that Cairnloop will recursively render as categorized
  UI sections. This "Zero-Config UI" allows the host developer to instantly receive
  a beautifully structured UI in the dashboard without writing any frontend code.
  """
```

**Callback definition pattern** (lines 21-28):
```elixir
  @doc """
  Retrieves context details for a given identity.

  The `actor_id` is a raw string from the Cairnloop ticket. The host application is
  responsible for mapping this string to their internal domain (e.g., resolving integer
  IDs, UUIDs, or emails).
  """
  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
```

---

### `lib/cairnloop/notifier/chimeway.ex` (adapter, event-driven/push)

**Analog:** `lib/cairnloop/default_context_provider.ex`

**Adapter implementation pattern** (lines 1-11):
```elixir
defmodule Cairnloop.DefaultContextProvider do
  @moduledoc """
  Default implementation of Cairnloop.ContextProvider.
  Returns an empty context `{:ok, %{}}` for any input to ensure a safe default.
  """

  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(_actor_id, _opts \\ []) do
    {:ok, %{}}
  end
end
```

---

## Shared Patterns

### Dynamic Configuration Loading
**Source:** `lib/cairnloop/workers/notify_resolved_worker.ex`
**Apply to:** Workers interacting with configurable behaviours
```elixir
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        # Call the configured behaviour module
        notifier.some_callback(args)
      _ ->
        :ok
    end
```

### Behaviour Implementation Structure
**Source:** `lib/cairnloop/default_context_provider.ex`
**Apply to:** New built-in adapters (like Chimeway)
```elixir
  @behaviour Cairnloop.Notifier

  @impl true
  def on_sla_breach(conversation, metadata) do
    # Adapter logic
  end
```

## No Analog Found

Files with no close match in the codebase: None. All components have a strong structural analog for how workers are defined, behaviours are structured, and adapters implemented.

## Metadata

**Analog search scope:** `lib/cairnloop/**/*.ex`
**Files scanned:** 26
**Pattern extraction date:** 2024-05-24
