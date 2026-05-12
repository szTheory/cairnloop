# Phase M004-S01: Resolution Telemetry & Host Extensibility - Pattern Map

**Mapped:** 2024-05-19 (Current Date)
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/cairnloop/add_resolved_at_column.ex` | migration | schema update | `lib/mix/tasks/cairnloop/add_draft_table.ex` | role-match |
| `lib/cairnloop/conversation.ex` | model | database mapping | `lib/cairnloop/conversation.ex` | exact |
| `lib/cairnloop/chat.ex` | service | CRUD/event-driven | `lib/cairnloop/chat.ex` | exact |
| `README.md` (or new guide) | documentation | N/A | `lib/cairnloop/notifier.ex` (for docs) | partial |

## Pattern Assignments

### `lib/mix/tasks/cairnloop/add_resolved_at_column.ex` (migration, schema update)

**Analog:** `lib/mix/tasks/cairnloop/add_draft_table.ex`

**Igniter Mix Task setup pattern** (lines 1-17):
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
```

**Migration Generation pattern** (lines 24-41):
```elixir
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
```

---

### `lib/cairnloop/conversation.ex` (model, database mapping)

**Analog:** `lib/cairnloop/conversation.ex`

**Schema definition pattern** (lines 4-14):
```elixir
  schema "cairnloop_conversations" do
    field(:status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open)
    field(:subject, :string)

    # External reference for the user or host context
    field(:host_user_id, :string)

    has_many(:messages, Cairnloop.Message)
    has_many(:drafts, Cairnloop.Automation.Draft)

    timestamps()
  end
```

---

### `lib/cairnloop/chat.ex` (service, CRUD/event-driven)

**Analog:** `lib/cairnloop/chat.ex`

**Core Update and Telemetry Pattern** (lines 56-80):
```elixir
  def resolve_conversation(conversation_id, metadata \\ %{}) do
    conversation = repo().get!(Conversation, conversation_id)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :resolved}))
    |> repo().transaction()
    |> case do
      {:ok, %{conversation: updated_conversation}} ->
        notify_resolved(updated_conversation, metadata)

        :telemetry.execute(
          [:cairnloop, :conversation, :resolved],
          %{count: 1},
          %{
            conversation_id: updated_conversation.id,
            host_user_id: updated_conversation.host_user_id,
            metadata: metadata
          }
        )

        {:ok, updated_conversation}

      error ->
        error
    end
  end
```

**Notifier callback pattern** (lines 83-91):
```elixir
  defp notify_resolved(conversation, metadata) do
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_conversation_resolved(conversation, metadata)

      _ ->
        :ok
    end
  end
```

---

### Documentation (`README.md` or guide)

**Analog:** `lib/cairnloop/notifier.ex`

**Notifier contract pattern** (lines 6-10):
```elixir
  @doc """
  Called when a conversation is resolved. 
  Metadata may contain :sentiment, :intent, etc.
  """
  @callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()
```
*(This outlines the business logic vs telemetry split that needs documenting)*

## Shared Patterns

### Telemetry Emission
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** `resolve_conversation`
```elixir
:telemetry.execute(
  [:cairnloop, :conversation, :resolved],
  %{count: 1, duration_seconds: duration}, # Will be updated here
  %{
    conversation_id: updated_conversation.id,
    actor: actor, # Need to map from updated arguments
    metadata: metadata
  }
)
```

## No Analog Found
None. All required changes naturally extend existing structures.

## Metadata

**Analog search scope:** `lib/cairnloop/**/*.ex`, `lib/mix/tasks/**/*.ex`
**Files scanned:** 4
**Pattern extraction date:** 2024-05-19