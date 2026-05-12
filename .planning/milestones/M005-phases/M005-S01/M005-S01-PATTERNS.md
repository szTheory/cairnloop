# Phase M005-S01: Foundation - Durable Auditing - Pattern Map

**Mapped:** 2024
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/auditor.ex` | behavior | host-owned wiring | `lib/cairnloop/context_provider.ex` | exact |
| `lib/cairnloop/automation.ex` | service | transactional (CRUD) | `lib/cairnloop/automation.ex` | exact |
| `lib/cairnloop/chat.ex` | service | transactional (CRUD) | `lib/cairnloop/chat.ex` | exact |

## Pattern Assignments

### `lib/cairnloop/auditor.ex` (behavior, host-owned wiring)

**Analog:** `lib/cairnloop/context_provider.ex`

**Behavior Definition Pattern** (lines 1-7, 24-29):
```elixir
defmodule Cairnloop.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context to Cairnloop.
  ...
  """

  @doc """
  ...
  """
  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
```
*Note: The new `Cairnloop.Auditor` behavior should similarly expose a callback like `@callback audit(Ecto.Multi.t(), action :: atom(), metadata :: map()) :: Ecto.Multi.t()` to allow appending to the chain.*

### `lib/cairnloop/automation.ex` (service, transactional)

**Analog:** `lib/cairnloop/automation.ex`

**Ecto.Multi Usage Pattern** (lines 38-54):
```elixir
  def approve_draft(draft_id) do
    draft = repo().get!(Draft, draft_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :message,
      Message.changeset(%Message{}, %{
        conversation_id: draft.conversation_id,
        content: draft.content,
        role: :agent
      })
    )
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :approved}))
    # --> Auditor integration should be injected here within the Multi chain <--
    |> repo().transaction()
    |> case do
      {:ok, _result} = success ->
```

### `lib/cairnloop/chat.ex` (service, transactional)

**Analog:** `lib/cairnloop/chat.ex`

**Ecto.Multi Usage Pattern** (lines 77-88):
```elixir
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :conversation,
        Ecto.Changeset.change(conversation, %{status: :resolved, resolved_at: resolved_at})
      )
      |> Ecto.Multi.insert(
        :system_message,
        Message.changeset(%Message{}, %{
          # ...
        })
      )
      |> Ecto.Multi.insert(
        :notify_job,
        # ...
      )
      # --> Auditor integration should be injected here within the Multi chain <--
      |> repo().transaction()
```

## Shared Patterns

### Dynamic Behavior Lookup
**Source:** `lib/cairnloop/workers/notify_resolved_worker.ex` (line 7) and `lib/cairnloop/web/conversation_live.ex` (line 144)
**Apply to:** Code that invokes the `Auditor` inside of core service modules.
```elixir
# Pattern for fetching configured behavior
Application.get_env(:cairnloop, :auditor)

# Alternatively with a default/fallback
Application.get_env(:cairnloop, :auditor, Cairnloop.DefaultAuditor)
```
When wrapping Multi chains, this lookup should be executed to dynamically inject the auditing steps if a host application provides an implementation.

## Metadata

**Analog search scope:** `lib/cairnloop/**/*.ex`
**Files scanned:** 30
**Pattern extraction date:** 2024
