# Phase 1: Foundation - Durable Auditing - Research

**Researched:** $(date +%Y-%m-%d)
**Domain:** Elixir, Ecto, Auditing, Compliance
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Threadline Durability**: Adopt the `Cairnloop.Auditor` behavior injected via `Ecto.Multi`. This ensures compliance-grade auditing by committing audit records in the exact same database transaction as the operator action, guaranteeing durable evidence. Pure telemetry is rejected because it breaks transactional boundaries and is therefore lossy.

### the agent's Discretion
- Do not build a standalone auditing solution; we are building an integration boundary (the `Cairnloop.Auditor` behaviour) that allows host applications to wire up Threadline within `Ecto.Multi` chains.
- Maintain Cairnloop's philosophy: Host-owned wiring, strict cardinality safety, and atomic evidence.

### Deferred Ideas (OUT OF SCOPE)
- Exposing metrics/SLIs directly to Parapet (This is M005 Phase 2).
- Defining SLO targets and runbook distribution (This is M005 Phase 3).
</user_constraints>

## Summary

This phase focuses on ensuring that critical operator actions in Cairnloop are durably and immutably logged for compliance purposes. The core architectural decision is to build an integration boundary using an Elixir `@callback` behaviour (`Cairnloop.Auditor`). This behaviour will intercept `Ecto.Multi` chains executing critical domain actions and give the host application (e.g., Threadline) an opportunity to append its own auditing operations (such as `Ecto.Multi.insert`) to the same database transaction.

**Primary recommendation:** Define the `Cairnloop.Auditor` behaviour, implement a default `NoOp` auditor, and update `Cairnloop.Automation` and `Cairnloop.Chat` core functions to accept `opts` (including an `:actor` or `:auditor` override) to inject the auditing step into the existing `Ecto.Multi` pipelines prior to calling `Repo.transaction()`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Audit Logging | API / Backend (Host) | Database | The host application's Auditor implementation appends to the `Ecto.Multi` transaction, ensuring atomic commits to the DB. |
| Audit Boundary | API / Backend (Lib) | — | Cairnloop provides the interface (`Cairnloop.Auditor`) and integration points within its domain operations. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir Behaviors | Core | Interface definition | Idiomatic way to define integration boundaries and inversion of control for host applications. |
| Ecto.Multi | ~> 3.0 | Transactional composition | Allows composing multiple DB operations and executing them atomically. |

## Existing Ecto.Multi Usage for Operator Actions

A review of the codebase identified the following locations where critical operator actions are executed via `Ecto.Multi`:

1.  **`Cairnloop.Automation.approve_draft/1`**: Requires modification to `approve_draft/2` to accept `opts` (for `:actor`).
2.  **`Cairnloop.Automation.discard_draft/1`**: Requires modification to `discard_draft/2`.
3.  **`Cairnloop.Automation.mark_draft_edited/1`**: Requires modification to `mark_draft_edited/2`.
4.  **`Cairnloop.Chat.reply_to_conversation/3`**: Operator action when `role == :agent`. Needs to accept `opts` to identify the specific operator/actor.
5.  **`Cairnloop.Chat.resolve_conversation/2`**: Already accepts `opts` containing `:resolved_by` (which represents the actor). Ready for auditor injection.

## Architecture Patterns

### Pattern 1: Behaviour-Driven Ecto.Multi Injection

**What:** Defining an Elixir behaviour that takes an `Ecto.Multi` struct, mutates it (by appending auditing steps), and returns the updated struct before `Repo.transaction/1` is called.

**When to use:** When a library needs to provide a transactional hook for a host application to record durable side effects.

**Example:**
```elixir
defmodule Cairnloop.Auditor do
  @doc """
  Injects audit operations into the given `Ecto.Multi` chain.
  Must return an `Ecto.Multi.t()`.
  """
  @callback audit(
              multi :: Ecto.Multi.t(),
              action :: atom(),
              actor :: map() | String.t() | nil,
              metadata :: map()
            ) :: Ecto.Multi.t()
end

defmodule Cairnloop.Auditor.NoOp do
  @behaviour Cairnloop.Auditor
  def audit(multi, _action, _actor, _metadata), do: multi
end
```

### Injection & Default Configuration

The configured auditor should be resolved dynamically, falling back to a `NoOp` implementation if the host application has not configured one.

```elixir
defp get_auditor(opts) do
  Keyword.get(opts, :auditor, Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp))
end
```

Inside the action function (e.g., `approve_draft`):

```elixir
def approve_draft(draft_id, opts \\ []) do
  draft = repo().get!(Draft, draft_id)
  auditor = get_auditor(opts)
  actor = Keyword.get(opts, :actor) # Provided by the caller

  Ecto.Multi.new()
  |> Ecto.Multi.insert(:message, ...)
  |> Ecto.Multi.update(:draft, ...)
  |> auditor.audit(:approve_draft, actor, %{draft_id: draft.id})
  |> repo().transaction()
  # ...
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Emitting Audit Logs | Standalone auditing table/schema | Host application `Auditor` via `Ecto.Multi` | The host application (Threadline) already owns compliance logging. Emitting telemetry is non-transactional and can be lost. We must append to the existing DB transaction. |

## Common Pitfalls

### Pitfall 1: Breaking the Transaction Chain
**What goes wrong:** The auditor executes `Repo.insert` directly inside the callback instead of appending to the `Ecto.Multi` struct.
**Why it happens:** Misunderstanding of how `Ecto.Multi` works and attempting side-effects mid-pipeline.
**How to avoid:** Clearly document that the `audit/4` callback MUST return an `Ecto.Multi.t()` and strictly use `Ecto.Multi.insert/run/update` within it.

### Pitfall 2: Missing Actor Context
**What goes wrong:** Audit logs are created without knowing *who* performed the action.
**Why it happens:** The caller functions (e.g., `approve_draft/1`) currently do not accept an actor parameter.
**How to avoid:** Update public APIs that trigger operator actions to accept an `opts` Keyword list containing the `:actor` (or specific keys like `:resolved_by`).

## Implementation Considerations

1.  **Create Behaviour:** Define `Cairnloop.Auditor` with the `audit/4` callback.
2.  **Create NoOp Implementation:** Define `Cairnloop.Auditor.NoOp` that returns the `multi` unchanged.
3.  **Refactor Public APIs:**
    *   Change `Cairnloop.Automation.approve_draft/1` to `approve_draft/2` (adding `opts \\ []`).
    *   Change `Cairnloop.Automation.discard_draft/1` to `discard_draft/2`.
    *   Change `Cairnloop.Automation.mark_draft_edited/1` to `mark_draft_edited/2`.
    *   Extend `Cairnloop.Chat.reply_to_conversation` to accept `opts` (e.g., `reply_to_conversation(id, content, role \\ :agent, opts \\ [])`).
4.  **Inject Auditor into Multi Chains:** In all identified functions, pass the `Ecto.Multi` pipeline through `auditor.audit(...)` right before calling `Repo.transaction()`.
5.  **Update Tests:** Update existing tests to pass `opts` where necessary. Add an isolated test using a mock/test auditor to verify `Ecto.Multi` chain interception works correctly.
