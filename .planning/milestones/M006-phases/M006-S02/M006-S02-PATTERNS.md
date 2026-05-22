# Phase M006-S02: Optional Dep + Default Adapter - Pattern Map

**Mapped:** 2023-10-27
**Files analyzed:** `Cairnloop.Notifier`, `Cairnloop.Notifier.Chimeway`, `mix.exs`, `Cairnloop.Workers.NotifyResolvedWorker`, `Cairnloop.Workers.CheckSLA`
**Analogs found:** 5 / 5

## File Classification

| Existing File | Role | Data Flow | Purpose |
|---------------|------|-----------|---------|
| `lib/cairnloop/notifier.ex` | behaviour | event-driven | Defines the interface for dispatching notifications |
| `lib/cairnloop/notifier/chimeway.ex` | adapter | event-driven | Implements the Notifier behaviour via Chimeway optional dep |
| `mix.exs` | config | build | Defines `chimeway` as an optional dependency |
| `lib/cairnloop/workers/notify_resolved_worker.ex` | worker | background | Calls the `on_conversation_resolved` dynamically |
| `lib/cairnloop/workers/check_sla.ex` | worker | background | Calls the `on_sla_breach` dynamically |

## Pattern Assignments

### Behaviour Pattern
**Analog:** `lib/cairnloop/notifier.ex`

The `Cairnloop.Notifier` module defines `@callback` functions for notifying the host application of important Cairnloop events.

**Core pattern:**
```elixir
defmodule Cairnloop.Notifier do
  @moduledoc """
  Behaviour for notifying the host application of important Cairnloop events.
  """

  @callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()

  @callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) :: :ok | {:error, term()} | any()
end
```

### Adapter Pattern
**Analog:** `lib/cairnloop/notifier/chimeway.ex`

The `Cairnloop.Notifier.Chimeway` adapter leverages `Chimeway.trigger` to dispatch the events to the optional dependency asynchronously.

**Core pattern:**
```elixir
defmodule Cairnloop.Notifier.Chimeway do
  @behaviour Cairnloop.Notifier

  @impl true
  def on_sla_breach(conversation, sla, _metadata) do
    payload = %{
      conversation_id: conversation.id,
      sla_type: sla.target_type,
      breached_at: sla.completed_at
    }

    opts = [
      idempotency_key: "sla_breach_#{conversation.id}_#{sla.target_type}"
    ]

    _ = Chimeway.trigger(Cairnloop.Chimeway.SLABreachNotifier, payload, opts)

    :ok
  end
  
  # ... other callbacks return :ok if not applicable or implemented
end
```

### Optional Dependency Pattern
**Analog:** `mix.exs`

The `chimeway` dependency is included with `optional: true` in the application environment so host applications are not forced to use it.

**Core pattern:**
```elixir
  defp deps do
    [
      # ... other deps
      {:chimeway, "~> 1.0", optional: true}
    ]
  end
```

### Configuration-Driven Behaviour (Dynamic Dispatch)
**Analog:** `lib/cairnloop/workers/check_sla.ex` & `lib/cairnloop/workers/notify_resolved_worker.ex`

Instead of calling an adapter directly, the code retrieves the active adapter from `Application.get_env(:cairnloop, :notifier)`. If set, it delegates the call; otherwise, it handles the absence gracefully.

**Core pattern:**
```elixir
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_sla_breach(conversation, sla, %{})

      _ ->
        :ok
    end
```

## Shared Patterns

### Configuration-Driven Callback Invocation
**Source:** `lib/cairnloop/workers/notify_resolved_worker.ex` and `lib/cairnloop/workers/check_sla.ex`
**Apply to:** Any new background workers triggering host notifications.
```elixir
case Application.get_env(:cairnloop, :notifier) do
  notifier when is_atom(notifier) and not is_nil(notifier) ->
    notifier.some_callback(args)
  _ ->
    :ok
end
```

## No Analog Found

None. All structural components requested for this phase already have representative analogs or foundations available in the current codebase.

## Metadata

**Analog search scope:** `lib/cairnloop/notifier*`, `lib/cairnloop/workers/*`, `mix.exs`
**Files scanned:** 5
**Pattern extraction date:** 2023-10-27
