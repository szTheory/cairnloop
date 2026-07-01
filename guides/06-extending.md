# Extending Cairnloop

Cairnloop's core design philosophy is "host-owned data and logic." Instead of forcing you to sync your data into a SaaS product, Cairnloop runs inside your Phoenix application and relies on `@callback` behaviours to interact with your domain.

This guide outlines the primary extension points available to customize Cairnloop's behavior.

## Core Behaviours

If you haven't yet, read the [Host Integration guide](03-host-integration.html) for detailed walkthroughs of the first four core behaviours:

*   **`Cairnloop.ContextProvider`**: Injects host domain state (like user LTV, billing status, or active plan) directly into the operator workspace UI. No frontend code is required; you return a map, and Cairnloop renders it.
*   **`Cairnloop.Notifier`**: Handles side effects. This is where you trigger webhooks, sync to your CRM, or send emails when a conversation resolves or an SLA breaches.
*   **`Cairnloop.AutomationPolicy`**: Gatekeeps AI drafting. You decide if an AI draft requires human approval (`:require_approval`), is generated silently (`:draft_only`), is automatically sent (`:allow`), or is discarded (`:deny`).
*   **`Cairnloop.SLAPolicyProvider`**: Supplies dynamic SLA rules (response time targets, breach thresholds) at runtime.

## Defining Custom Tools (`Cairnloop.Tool`)

The most powerful way to extend Cairnloop is by writing your own operator tools. Tools are discrete,
idempotent actions proposed by human operators, AI-assisted flows, or authenticated MCP clients.
They do not run inline from MCP: external `tools/call` requests route through
`Cairnloop.Governance.propose/3`, creating the same governed proposal an operator would review in
the dashboard.

To create a tool, use the `Cairnloop.Tool` macro and implement the required callbacks:

```elixir
defmodule MyApp.Tools.IssueRefund do
  use Cairnloop.Tool,
    risk_tier: :low_write,
    title: "Issue refund",
    description: "Issues a refund to the customer's payment method."

  embedded_schema do
    field :conversation_id, :string
    field :amount_cents, :integer
    field :reason, :string
  end

  @impl true
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:conversation_id, :amount_cents, :reason])
    |> validate_required([:conversation_id, :amount_cents, :reason])
    |> validate_number(:amount_cents, greater_than: 0)
  end

  @impl true
  def scope, do: [:billing]

  @impl true
  def authorize(_actor_id, context) do
    if :billing in Map.get(context, :scopes, []) do
      :ok
    else
      {:error, :missing_billing_scope}
    end
  end

  @impl true
  def run(%__MODULE__{} = tool, _actor_id, context) do
    run_key = Map.fetch!(context, :run_idempotency_key)

    case MyApp.Billing.refund_once(tool.conversation_id, tool.amount_cents, tool.reason, run_key) do
      {:ok, refund} -> {:ok, %{refund_id: refund.id}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

Once defined, register your tool in your `config.exs`:

```elixir
config :cairnloop, tools: [MyApp.Tools.IssueRefund]
```

Cairnloop validates the macro options at compile time, derives a fail-closed approval mode from the
tool's risk tier when you do not provide one, projects the embedded schema to MCP input metadata,
validates proposed input through `changeset/2`, checks `scope/0` and `authorize/2`, snapshots the
proposal, and calls `run/3` only from the background execution worker after approval and
re-validation.

Keep `run/3` atomic and idempotent. The execution context includes a `:run_idempotency_key`; use it
as the unique key for the one durable write your tool performs, or wrap multiple writes in a single
transaction you can safely replay.

## Advanced Extension Points

### `Cairnloop.Embedder`

By default, Cairnloop relies on `pgvector` for its Knowledge Base embeddings. If you need to customize how text is vectorized (for instance, switching from the default OpenAI `text-embedding-3-small` to a local model or another provider), you can implement the `Cairnloop.Embedder` behaviour.

```elixir
@callback generate_embeddings(chunks :: [String.t()], opts :: keyword()) ::
            {:ok, [[float()]]} | {:error, term()}
```

Configure it in your `config.exs`:

```elixir
config :cairnloop, :embedder, MyApp.CustomEmbedder
```

### `Cairnloop.Automation.DraftGenerator`

Cairnloop turns a retrieval **grounding bundle** into an operator-reviewable reply draft through a swappable engine. The library default, `Cairnloop.Automation.ScoriaEngine`, is deterministic and dependency-free: it needs no API key and never calls out to a model, composing a citation-anchored reply from the canonical Knowledge Base evidence (and asking for the missing detail or recommending a handoff when grounding is weak).

To have a real model compose the customer-facing reply, configure the bundled Anthropic adapter:

```elixir
# config.exs — choose the engine
config :cairnloop, :draft_generator, Cairnloop.Automation.DraftGenerator.Anthropic

# runtime.exs — read the secret at boot, never compile it in
config :cairnloop, :anthropic_api_key, System.fetch_env!("ANTHROPIC_API_KEY")
```

Optional knobs: `:anthropic_model` (default `"claude-sonnet-4-6"`) and `:anthropic_max_tokens` (default `1024`). The API key is also read from the `ANTHROPIC_API_KEY` environment variable when not set in config.

The adapter is **fail-closed by design**. It only asks Claude to compose a reply when the grounding assessment is `:strong`; for `:clarification`/`:escalation` grounding, a missing API key, or any API error it transparently delegates to `ScoriaEngine` — so a model never guesses past the available evidence, and a draft always appears for the operator. Every draft is still human-in-the-loop: it lands as a `:pending` draft an operator reviews (and `Cairnloop.AutomationPolicy` decides whether it can be auto-sent) before anything reaches the customer.

To build your own engine (a different provider, a local model, or custom prompting), implement the one-callback behaviour:

```elixir
@callback generate_draft(conversation_id :: String.t(), grounding_bundle :: map()) ::
            {:ok, proposal :: map()} | {:error, term()}
```

```elixir
config :cairnloop, :draft_generator, MyApp.CustomDraftGenerator
```

Return a proposal map with `:proposal_type`, `:operator_summary`, `:customer_reply`, `:content`, `:evidence`, `:grounding_metadata`, and `:clarification_attempts`. See `Cairnloop.Automation.DraftGenerator` for the full contract and trust posture.

### `Cairnloop.Auditor`

Cairnloop maintains a durable audit trail of governance decisions, tool executions, and support
events. The default `Cairnloop.Auditor.Governance` reads governed-action events through the
`Cairnloop.Governance` facade so the Audit Log has useful rows without extra host setup. If you need
to co-commit your own audit rows or read from your own audit store, implement `Cairnloop.Auditor`.

```elixir
@callback audit(
            multi :: Ecto.Multi.t(),
            action :: atom(),
            actor :: map() | String.t() | nil,
            metadata :: map()
          ) :: Ecto.Multi.t()

@callback list_events(opts :: keyword()) :: [map()]
```

Configure it in your `config.exs`:

```elixir
config :cairnloop, :auditor, MyApp.ComplianceAuditor
```

`audit/4` receives an existing `Ecto.Multi` so your audit operation can participate in the same
transaction as the Cairnloop write. `list_events/1` returns plain maps for the operator Audit Log.
Keep returned metadata bounded and human-readable; raw payloads and support bodies should stay in
your own controlled systems, not in generic audit metadata.
