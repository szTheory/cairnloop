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

The most powerful way to extend Cairnloop is by writing your own operator tools. Tools are discrete, idempotent actions that can be executed by human operators, triggered by AI drafts, or invoked via external MCP clients.

To create a tool, implement the `Cairnloop.Tool` behaviour:

```elixir
defmodule MyApp.Tools.IssueRefund do
  use Cairnloop.Tool

  @impl true
  def spec do
    %Cairnloop.Tool.Spec{
      name: "issue_refund",
      description: "Issues a refund to the customer's payment method.",
      parameters: %{
        type: "object",
        properties: %{
          "amount" => %{type: "number", description: "Amount to refund"},
          "reason" => %{type: "string", description: "Reason for the refund"}
        },
        required: ["amount", "reason"]
      },
      risk_tier: :requires_approval # Requires human review when proposed by AI
    }
  end

  @impl true
  def run(params, context, _opts) do
    # Implement your business logic here.
    # Return {:ok, result_string} or {:error, reason}
    case MyApp.Billing.refund(context.account_id, params["amount"]) do
      :ok -> {:ok, "Refund of $#{params["amount"]} issued successfully."}
      {:error, reason} -> {:error, "Failed to issue refund: #{reason}"}
    end
  end
end
```

Once defined, register your tool in your `config.exs`:

```elixir
config :cairnloop, tools: [MyApp.Tools.IssueRefund]
```

Cairnloop automatically handles projecting this tool to the LLM context, rendering its inputs in the UI, enforcing governance policies, and dispatching execution via background workers.

## Advanced Extension Points

### `Cairnloop.Embedder`

By default, Cairnloop relies on `pgvector` for its Knowledge Base embeddings. If you need to customize how text is vectorized (for instance, switching from the default OpenAI `text-embedding-3-small` to a local model or another provider), you can implement the `Cairnloop.Embedder` behaviour.

```elixir
@callback embed(text :: String.t(), opts :: keyword()) :: {:ok, list(float())} | {:error, term()}
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

Cairnloop maintains a rigorous audit trail of all governance decisions, tool executions, and system events. If you need to route these audit logs to an external compliance system (like Datadog, AWS CloudTrail, or an internal SIEM), implement the `Cairnloop.Auditor` behaviour.

```elixir
@callback log_event(event_type :: atom(), payload :: map(), metadata :: map()) :: :ok
```

Configure it in your `config.exs`:

```elixir
config :cairnloop, :auditor, MyApp.ComplianceAuditor
```

Whenever an operator approves a tool execution or an AI draft is generated, your auditor will receive the structured event synchronously before the action completes, ensuring your external records are always complete.
