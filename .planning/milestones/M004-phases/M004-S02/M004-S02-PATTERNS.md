# Phase M004-S02: Customer Satisfaction (CSAT) Capture - Pattern Map

**Mapped:** 2024-05-24 (Current Date)
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/cairnloop/add_csat_columns.ex` | migration | schema | `lib/mix/tasks/cairnloop/add_resolved_at_column.ex` | exact |
| `lib/cairnloop/message.ex` | model | schema | `lib/cairnloop/conversation.ex` | exact |
| `lib/cairnloop/conversation.ex` | model | schema | `lib/cairnloop/conversation.ex` | exact |
| `lib/cairnloop/chat.ex` | service | CRUD/event-driven | `lib/cairnloop/chat.ex` | exact |
| `lib/cairnloop/channels/widget_channel.ex` | controller | request-response | `lib/cairnloop/channels/widget_channel.ex` | exact |

## Pattern Assignments

### `lib/mix/tasks/cairnloop/add_csat_columns.ex` (migration, schema)

**Analog:** `lib/mix/tasks/cairnloop/add_resolved_at_column.ex`

**Igniter mix task and Ecto migration pattern** (lines 1-32):
```elixir
defmodule Mix.Tasks.Cairnloop.AddResolvedAtColumn do
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
          "No Ecto repo found. Please create a migration manually for cairnloop tables."
        )

      {igniter, repo} ->
        Igniter.Libs.Ecto.gen_migration(
          igniter,
          repo,
          "add_resolved_at_to_conversations",
          body: """
            def change do
              alter table(:cairnloop_conversations) do
                add :resolved_at, :utc_datetime_usec
              end
            end
          """,
          on_exists: :skip
        )
    end
  end
end
```

---

### `lib/cairnloop/message.ex` & `lib/cairnloop/conversation.ex` (model, schema)

**Analog:** `lib/cairnloop/conversation.ex`

**Schema field pattern (Enum/string)** (lines 5-6):
```elixir
  schema "cairnloop_conversations" do
    field(:status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open)
```

**Changeset casting pattern** (lines 17-21):
```elixir
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :subject, :host_user_id, :resolved_at])
    |> validate_required([:status])
  end
```

---

### `lib/cairnloop/chat.ex` (service, CRUD/event-driven)

**Analog:** `lib/cairnloop/chat.ex`

**Ecto Multi insert pattern (for adding system message)** (lines 27-36):
```elixir
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
```

**Telemetry execution pattern** (lines 69-78):
```elixir
        :telemetry.execute(
          [:cairnloop, :conversation, :resolved],
          %{count: 1, duration_seconds: duration_seconds},
          %{
            conversation_id: updated_conversation.id,
            host_user_id: updated_conversation.host_user_id,
            actor: actor,
            metadata: Enum.into(metadata, %{})
          }
        )
```

---

### `lib/cairnloop/channels/widget_channel.ex` (controller, request-response)

**Analog:** `lib/cairnloop/channels/widget_channel.ex`

**Channel handle_in pattern** (lines 18-25):
```elixir
  @impl true
  def handle_in("new_message", %{"content" => content}, socket) do
    # T-M001-03 Mitigation: Enqueueing to Oban prevents channel blocking.
    %{channel: "widget", content: content}
    |> Cairnloop.Workers.ProcessMessage.new()
    |> Oban.insert()

    {:reply, :ok, socket}
  end
```

## Shared Patterns

### Database Transactions
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** Core logic appending the CSAT system message when a conversation is resolved. Ensure `Ecto.Multi` is used and committed via `repo().transaction(multi)`.

### Telemetry Execution
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** Channels and services generating business events. Telemetry executes should follow standard `[:cairnloop, <domain>, <action>]` format, providing `count: 1` as the default measurement and a map of relevant dimensions as metadata.

## No Analog Found

None. All files have direct analogs.

## Metadata

**Analog search scope:** `lib/**/*.ex`
**Files scanned:** 5
**Pattern extraction date:** 2024-05-24
