# Host Integration

Cairnloop exposes four behaviour contracts that let your host application control the
support lifecycle without giving up ownership of your data or business logic. Each behaviour
is a plain Elixir `@behaviour` module — implement the callbacks, configure the module, and
Cairnloop uses your implementation at the right moment.

This guide documents all four behaviours and their full callback sets, in the order a new
adopter would typically implement them. It also covers Cairnloop's telemetry emission points
as an observability reference.

---

## ContextProvider

**Module:** `Cairnloop.ContextProvider`

**When to implement:** Always — every operator conversation workspace pulls context from this
behaviour. Without a configured provider, the context rail renders "Context Unavailable".

`ContextProvider` is how Cairnloop achieves a zero-API-sync design. Your implementation
returns a map of host-owned facts for the given support actor. Cairnloop renders that map
recursively as categorized UI sections in the conversation workspace's right rail — no
frontend code required on your end. This is the "Zero-Config UI" feature.

**Callback:**

```elixir
@callback get_context(actor_id :: String.t(), opts :: keyword()) ::
            {:ok, map()} | {:error, term()}
```

The `actor_id` is the raw string from the Cairnloop conversation. Your implementation maps
it to your internal domain — a UUID, integer ID, email, or external identifier. The opts
keyword list is reserved for future extension and can be ignored.

Return a tagged tuple. Never raise. If your database or external service is unavailable,
return `{:error, reason}` — the dashboard degrades to "Context Unavailable" rather than
crashing the operator's session.

**Example implementation:**

```elixir
defmodule MyApp.CairnloopContext do
  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(actor_id, _opts) do
    case MyApp.Accounts.get_user(actor_id) do
      nil ->
        {:ok, %{}}

      user ->
        {:ok, %{
          "User Details" => %{name: user.name, lifetime_value: "$#{user.ltv}"},
          "Active Plan"  => %{tier: user.plan, status: user.billing_status}
        }}
    end
  end
end
```

**Configuration** (`config/config.exs`):

```elixir
config :cairnloop, :context_provider, MyApp.CairnloopContext
```

The returned map is rendered as grouped sections in the support workspace right rail. Top-level
string keys become section headers; nested maps render as key-value pairs within that section.

---

## Notifier

**Module:** `Cairnloop.Notifier`

**When to implement:** Required when you need side effects on conversation events, and required
for the outbound delivery lane (`Outbound.trigger/2` and `bulk_trigger/2` route through
`on_outbound_triggered/2`).

`Notifier` is the business-logic integration point: CRM sync, email, webhooks, background
jobs, or any other side effect your app needs to trigger when support events occur. Cairnloop
calls each callback asynchronously via Oban, ensuring reliable retries and data consistency.

**Callbacks (all three — implement all of them):**

```elixir
@callback on_conversation_resolved(conversation :: struct(), metadata :: map()) ::
            :ok | any()

@callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) ::
            :ok | {:error, term()} | any()

@callback on_outbound_triggered(message :: struct(), conversation :: struct()) ::
            :ok | {:error, term()} | any()
```

**Example implementation:**

```elixir
defmodule MyApp.CairnloopNotifier do
  @behaviour Cairnloop.Notifier

  @impl true
  def on_conversation_resolved(conversation, metadata) do
    actor = metadata[:actor]

    # Enqueue a background job rather than performing the side effect inline.
    %{conversation_id: conversation.id, resolved_by_id: actor && actor.id}
    |> MyApp.Workers.CRMSyncJob.new()
    |> Oban.insert()

    :ok
  end

  @impl true
  def on_sla_breach(_conversation, _sla, _metadata) do
    # Notify your on-call channel, update a dashboard, or page an operator.
    :ok
  end

  @impl true
  def on_outbound_triggered(_message, _conversation) do
    # Route the outbound message through your delivery provider (email, SMS, etc.).
    # Return :ok on success or {:error, reason} to signal a delivery failure to Oban.
    :ok
  end
end
```

**Generator escape hatch:** Rather than writing this module by hand, run:

```bash
mix cairnloop.gen.notifier
```

This scaffolds a `MyApp.CairnloopNotifier` module with all three callbacks and automatically
injects the configuration line into your `config/config.exs`.

**Manual configuration** (`config/config.exs`):

```elixir
config :cairnloop, :notifier, MyApp.CairnloopNotifier
```

> The README's earlier examples showed only two Notifier callbacks. The full behaviour
> defines three: `on_conversation_resolved/2`, `on_sla_breach/3`, and
> `on_outbound_triggered/2`. Implement all three — missing callbacks cause a compile-time
> warning about incomplete behaviour implementation.

---

## AutomationPolicy

**Module:** `Cairnloop.AutomationPolicy`

**When to implement:** When you want to control how Cairnloop handles AI draft proposals.
Without a configured policy, the default posture is `:require_approval` — every AI draft
waits for explicit operator review before anything is sent.

`AutomationPolicy` is the governance boundary for AI drafting. Your implementation receives
a proposal map and opts, and returns one of four atoms that determine what Cairnloop does
with the AI-generated content.

**Callback:**

```elixir
@callback decide(proposal :: map(), opts :: map()) ::
            :allow | :draft_only | :require_approval | :deny
```

**Return values:**

| Atom | Meaning |
|------|---------|
| `:allow` | The draft may be sent without operator review (use with caution — bypasses HITL). |
| `:draft_only` | Cairnloop prepares the draft but does not surface an approval prompt. Operator must retrieve and act on it manually. |
| `:require_approval` | The draft requires explicit operator approval before it becomes an outgoing reply. This is the recommended default. |
| `:deny` | Cairnloop discards the draft. No AI content is presented to the operator for this proposal. |

**Example implementation (recommended — approval-gated):**

```elixir
defmodule MyApp.CairnloopPolicy do
  @behaviour Cairnloop.AutomationPolicy

  @impl true
  def decide(_proposal, _opts), do: :require_approval
  # Returns :allow | :draft_only | :require_approval | :deny
end
```

Start with `:require_approval`. This mirrors Cairnloop's "safe-by-default, not
autonomous-by-default" posture — operators review before anything reaches a customer.
Graduate to finer-grained logic (inspecting `proposal.risk_tier`, conversation tags, or
account properties) only after you have validated quality in your specific context.

**Configuration** (`config/config.exs`):

```elixir
config :cairnloop, :automation_policy, MyApp.CairnloopPolicy
```

---

## SLAPolicyProvider

**Module:** `Cairnloop.SLAPolicyProvider`

**When to implement:** When your support team has SLA commitments — response time targets,
breach thresholds, or priority tiers — that you want Cairnloop to track and enforce.

`SLAPolicyProvider` supplies Cairnloop with the active SLA rule set at runtime. Policies can
be stored in your database and retrieved dynamically, letting you change SLA terms without
redeploying.

**Callbacks:**

```elixir
@callback get_active_policies() :: {:ok, list(map())} | {:error, term()}

@callback set_policy(priority :: atom(), attrs :: map()) :: {:ok, map()} | {:error, term()}
```

**Example implementation:**

```elixir
defmodule MyApp.CairnloopSLA do
  @behaviour Cairnloop.SLAPolicyProvider

  @impl true
  def get_active_policies do
    # Return a list of SLA policy maps from your database or config.
    # Return {:ok, []} to disable SLA tracking.
    {:ok, [
      %{priority: :high, response_minutes: 60, breach_minutes: 240},
      %{priority: :normal, response_minutes: 240, breach_minutes: 1440}
    ]}
  end

  @impl true
  def set_policy(_priority, _attrs) do
    # Persist a new or updated SLA policy. Return {:ok, policy_map} on success.
    {:error, :not_implemented}
  end
end
```

**Configuration** (`config/config.exs`):

```elixir
config :cairnloop, :sla_policy_provider, MyApp.CairnloopSLA
```

When `get_active_policies/0` returns `{:ok, []}`, Cairnloop disables SLA breach tracking
rather than raising — the support workflow continues without SLA enforcement.

---

## Telemetry (observability only)

Cairnloop emits `:telemetry` events for observability. Per the project's architecture
posture: **telemetry is observability only — never a UI or display source**. Do not build
logic that reads Cairnloop telemetry to drive LiveView state; use the `Notifier` behaviour
for business-logic side effects.

Cairnloop uses a **dual emission** architecture: bounded `:telemetry.span/3` events for
APM tracing alongside past-tense domain events for business logic hooks.

### A. Tracing spans (performance and APMs)

Use the span lifecycle events (`:start`, `:stop`, `:exception`) to capture execution
metrics. These are appropriate for exporting to APMs (Datadog, Prometheus) or logging
function execution duration.

```elixir
:telemetry.attach(
  "cairnloop-apm-tracker",
  [:cairnloop, :conversation, :resolve, :stop],
  fn _event, measurements, _metadata, _config ->
    require Logger
    # Execution time is available in measurements.duration (native units).
    Logger.info(
      "Resolve took #{System.convert_time_unit(measurements.duration, :native, :millisecond)}ms"
    )
  end,
  nil
)
```

### B. Domain events (business lifecycle hooks)

Use past-tense domain events to observe successful business actions. These events carry
the resolved `Conversation` struct and actor metadata.

```elixir
:telemetry.attach(
  "cairnloop-domain-hooks",
  [:cairnloop, :conversation, :resolved],
  fn _event, measurements, metadata, _config ->
    require Logger

    conversation = metadata.conversation
    Logger.info(
      "Conversation #{conversation.id} resolved by #{metadata.actor.id} " <>
      "in #{measurements.duration_seconds}s at #{conversation.resolved_at}"
    )

    # Example: broadcast to a LiveView session to surface a CSAT prompt.
    # Phoenix.PubSub.broadcast(
    #   MyApp.PubSub,
    #   "user_sessions:#{metadata.host_user_id}",
    #   :support_issue_resolved
    # )
  end,
  nil
)
```

Telemetry event names follow the `[:cairnloop, :domain, :action, :lifecycle]` convention.
The events are non-blocking — they do not delay the conversation resolve path. For
side-effects that need reliability guarantees (retries, durability), use `Notifier`
instead.
