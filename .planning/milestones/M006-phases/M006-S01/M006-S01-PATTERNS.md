# Phase 1: SLA Countdown Engine (Oban) - Pattern Map

**Mapped:** 2024-05-14
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/conversations/sla.ex` | model | CRUD | `lib/cairnloop/conversation.ex` | exact |
| `lib/mix/tasks/cairnloop/add_sla_table.ex` | migration | CRUD | `lib/mix/tasks/cairnloop/add_draft_table.ex` | exact |
| `lib/cairnloop/workers/sla_countdown_worker.ex` | worker | event-driven | `lib/cairnloop/workers/notify_resolved_worker.ex` | exact |
| `lib/cairnloop/chat.ex` | service | CRUD | `lib/cairnloop/chat.ex` | exact |

## Pattern Assignments

### `lib/cairnloop/conversations/sla.ex` (model, CRUD)

**Analog:** `lib/cairnloop/conversation.ex`

**Core Pattern (Schema and Changeset)** (lines 1-22):
```elixir
defmodule Cairnloop.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_conversations" do
    field(:status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open)
    field(:subject, :string)

    # External reference for the user or host context
    field(:host_user_id, :string)
    field(:resolved_at, :utc_datetime_usec)
    field(:csat_rating, Ecto.Enum, values: [:positive, :negative])

    has_many(:messages, Cairnloop.Message)
    has_many(:drafts, Cairnloop.Automation.Draft)

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :subject, :host_user_id, :resolved_at, :csat_rating])
    |> validate_required([:status])
  end
end
```

---

### `lib/mix/tasks/cairnloop/add_sla_table.ex` (migration, CRUD)

**Analog:** `lib/mix/tasks/cairnloop/add_draft_table.ex`

**Igniter Migration Pattern** (lines 1-32):
```elixir
defmodule Mix.Tasks.Cairnloop.AddDraftTable do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :cairnloop,
      schema: [],
      defaults: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> Igniter.Libs.Ecto.select_repo()
    |> case do
      {igniter, nil} ->
        Igniter.add_issue(
          igniter,
          "No Ecto repo found. Please create a migration manually for cairnloop_drafts table."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
          igniter,
          repo,
          "create_cairnloop_drafts",
          body: """
            def change do
              create table(:cairnloop_drafts) do
                add :content, :text, null: false
                add :status, :string, null: false, default: "pending"
                add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all), null: false

                timestamps()
              end

              create index(:cairnloop_drafts, [:conversation_id])
            end
          """,
          on_exists: :skip
        )
    end
  end
end
```

---

### `lib/cairnloop/workers/sla_countdown_worker.ex` (worker, event-driven)

**Analog:** `lib/cairnloop/workers/notify_resolved_worker.ex`

**Oban Worker Pattern** (lines 1-13):
```elixir
defmodule Cairnloop.Workers.NotifyResolvedWorker do
  use Oban.Worker, queue: :default

  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id, "metadata" => metadata}}) do
    conversation = Cairnloop.Chat.get_conversation!(conversation_id)
    
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_conversation_resolved(conversation, Enum.into(metadata, %{}))

      _ ->
        :ok
    end
  end
end
```

---

### `lib/cairnloop/chat.ex` (service, CRUD)

**Analog:** `lib/cairnloop/chat.ex`

**Ecto.Multi Chain Pattern** (lines 28-56):
```elixir
    Cairnloop.Telemetry.span([:conversation, :reply], meta, fn ->
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(
          :message,
          Message.changeset(%Message{}, %{
            conversation_id: conversation.id,
            content: content,
            role: role
          })
        )
        |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :open}))
        |> auditor.audit(:reply_to_conversation, actor, %{conversation_id: conversation.id})

      multi =
        if role == :user do
          Ecto.Multi.insert(
            multi,
            :draft_job,
            Cairnloop.Automation.Workers.DraftWorker.new(
              %{"conversation_id" => conversation.id},
              schedule_in: 5
            )
          )
        else
          multi
        end

      result = repo().transaction(multi)
      {result, meta}
    end)
```

## Shared Patterns

### Dependency Injection (Oban/Notifier/Auditor)
**Source:** `lib/cairnloop/chat.ex` and `lib/cairnloop/workers/notify_resolved_worker.ex`
**Apply to:** All services and workers
The library uses `Application.get_env/3` for dependencies like `:auditor` and `:notifier` rather than hardcoding them, and falls back to NoOps when not configured. This should be followed for any new external integration or worker queues.

### Telemetry Spans
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** Service layer updates
Data mutations (insert/update) in `Cairnloop.Chat` are wrapped in `Cairnloop.Telemetry.span/3` to emit execution metrics. State transitions for SLAs should follow this approach.

## Metadata

**Analog search scope:** `lib/cairnloop/`
**Files scanned:** 4
**Pattern extraction date:** 2024-05-14