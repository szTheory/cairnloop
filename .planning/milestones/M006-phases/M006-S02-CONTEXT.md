# M006-S02 Context: The Notifier Behaviour & Chimeway

## Architectural Decision: Optional Dep + Default Adapter

To dispatch actionable notifications for SLA breaches without tightly coupling the core domain logic to external APIs, we will implement the **Optional Dep + Default Adapter** pattern for integrating Chimeway.

### Why this approach?
1. **Batteries-Included DX ("SaaS-in-a-box"):** By shipping a built-in `Cairnloop.Notifier.Chimeway` adapter and adding `:chimeway` as an `optional: true` dependency, host applications can start sending SLA alerts to Slack/Email out of the box with zero boilerplate.
2. **Architectural Purity:** The core business logic only interacts with a strict `Cairnloop.Notifier` behaviour. It has no direct knowledge of Chimeway's implementation details.
3. **Ecosystem Synergy:** This mirrors the successful patterns seen in industry-standard Elixir libraries like `Oban` and `Swoosh`, which define strict behaviours but provide first-party plugins/adapters for the most common use cases.
4. **Host-Owned Override:** Because it's driven by behaviour configuration, a host app with complex routing requirements can simply swap out the Notifier in their `config.exs` and write their own custom adapter, bypassing Chimeway entirely if they choose.

## Proposed Integration Contract

### The Behaviour
The core `Cairnloop.Notifier` behaviour will define callbacks for critical system events, such as SLA breaches. (Note: It will also retain the existing `on_conversation_resolved` callback from M004).

```elixir
defmodule Cairnloop.Notifier do
  @moduledoc "Behaviour for dispatching notifications to the host app."

  @doc "Dispatched when an SLA timer expires and the SLA is breached."
  @callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) :: :ok | {:error, term()}
  
  # Existing M004 callback
  @callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()
end
```

### The Chimeway Adapter (First-Party)
Cairnloop will ship this module internally:

```elixir
defmodule Cairnloop.Notifier.Chimeway do
  @behaviour Cairnloop.Notifier

  @impl true
  def on_sla_breach(conversation, sla, context) do
    # Defers the actual HTTP/Delivery work to Chimeway's async processing.
    # The CheckSLA Oban worker can call this synchronously.
    Chimeway.deliver(
      "cairnloop_sla_breach",
      %{
        conversation_id: conversation.id,
        sla_type: sla.target_type,
        breached_at: sla.completed_at
      },
      context
    )
  end
  
  @impl true
  def on_conversation_resolved(conversation, metadata) do
    # existing implementation...
  end
end
```

### Handoff from Phase 1 (Oban)
The `CheckSLA` Oban job built in Phase 1 will execute the evaluation logic. If it determines an SLA is breached, it will synchronously call the configured notifier (e.g., `Cairnloop.Notifier.on_sla_breach/3`). The built-in Notifier adapter will then enqueue the outbound delivery via Chimeway, ensuring that `CheckSLA` Oban queue resources are not tied up waiting for third-party API responses.

## References
- `.planning/M006-ROADMAP.md`
- `prompts/elixir-lib-customer-support-automation-deep-research.md` (szTheory ecosystem integration vision)
