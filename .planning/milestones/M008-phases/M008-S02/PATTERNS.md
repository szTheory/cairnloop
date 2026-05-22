# Phase 2: LiveView Markdown Authoring Interface - Pattern Map

**Mapped:** 2024-05-18
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/web/knowledge_base_live/editor.ex` | controller | request-response | `lib/cairnloop/web/conversation_live.ex` | role-match |
| `lib/cairnloop/knowledge_base.ex` | service | CRUD | `lib/cairnloop/automation.ex` | role-match |
| `lib/cairnloop/router.ex` | route | request-response | `lib/cairnloop/router.ex` | exact |

## Pattern Assignments

### `lib/cairnloop/web/knowledge_base_live/editor.ex` (controller, request-response)

**Analog:** `lib/cairnloop/web/conversation_live.ex`

**Imports pattern** (lines 1-4):
```elixir
defmodule Cairnloop.Web.KnowledgeBaseLive.Editor do
  use Phoenix.LiveView

  alias Cairnloop.KnowledgeBase
```

**State management & Core pattern** (lines 20-36):
```elixir
  def handle_event("change", %{"content" => content}, socket) do
    {:noreply, assign(socket, form: to_form(%{"content" => content}))}
  end

  # Example of form handling calling a context method
  def handle_event("save", %{"content" => content}, socket) do
    # Implementation calling KnowledgeBase...
  end
```

**UI layout pattern** (lines 154-180):
```elixir
    <style>
      .conversation-layout {
        display: flex;
        flex-direction: column;
        gap: 32px;
      }
      @media (min-width: 1024px) {
        .conversation-layout {
          flex-direction: row;
        }
      }
    </style>
```

---

### `lib/cairnloop/knowledge_base.ex` (service, CRUD)

**Analog:** `lib/cairnloop/automation.ex`

**Imports pattern** (lines 1-2):
```elixir
defmodule Cairnloop.KnowledgeBase do
  import Ecto.Query
```

**Core CRUD pattern with Ecto.Multi** (lines 13-33):
```elixir
  def create_draft(conversation_id, attrs) do
    # ...
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :draft,
      Draft.changeset(%Draft{}, attrs)
    )
    |> repo().transaction()
    |> case do
      {:ok, %{draft: draft}} ->
        :telemetry.execute(
          [:cairnloop, :automation, :draft, :created],
          %{count: 1},
          %{draft_id: draft.id}
        )

        {:ok, draft}

      {:error, :draft, changeset, _changes} ->
        {:error, changeset}
    end
  end
```

---

### `lib/cairnloop/router.ex` (route, request-response)

**Analog:** `lib/cairnloop/router.ex`

**Route definition pattern** (lines 6-10):
```elixir
        live_session :cairnloop_dashboard, opts do
          live("/", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
          live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
          live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
          # new route here for KB editor
        end
```

## Shared Patterns

### Error Handling
**Source:** `lib/cairnloop/web/conversation_live.ex`
**Apply to:** LiveView forms handling context execution
```elixir
        {:error, _failed_operation, _failed_value, _changes_so_far} ->
          {:noreply, put_flash(socket, :error, "Failed to send reply.")}
```

## Metadata

**Analog search scope:** `lib/cairnloop/web/**/*_live.ex`, `lib/cairnloop/*.ex`, `lib/cairnloop/router.ex`
**Files scanned:** 4
**Pattern extraction date:** 2024-05-18