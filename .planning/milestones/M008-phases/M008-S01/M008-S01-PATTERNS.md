# Phase 1: Immutable Knowledge Base Foundation (Ecto) - Pattern Map

**Mapped:** 2024
**Files analyzed:** 5
**Analogs found:** 4 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/knowledge_base/article.ex` | model | CRUD | `lib/cairnloop/conversation.ex` | exact |
| `lib/cairnloop/knowledge_base/revision.ex` | model | CRUD (Immutable) | `lib/cairnloop/message.ex` | exact |
| `lib/cairnloop/knowledge_base/chunk.ex` | model | CRUD (Immutable) | `lib/cairnloop/message.ex` | role-match |
| `lib/cairnloop/knowledge_base.ex` | context / service | CRUD | `lib/cairnloop/chat.ex` | exact |
| `priv/repo/migrations/*_create_knowledge_base.exs` | migration | DDL | N/A | no-analog |

## Pattern Assignments

### `lib/cairnloop/knowledge_base/article.ex` (model, CRUD)

**Analog:** `lib/cairnloop/conversation.ex`

**Imports pattern** (lines 1-3):
```elixir
defmodule Cairnloop.KnowledgeBase.Article do
  use Ecto.Schema
  import Ecto.Changeset
```

**Core CRUD pattern** (lines 5-17):
```elixir
  schema "cairnloop_articles" do
    field(:status, Ecto.Enum, values: [:draft, :published, :archived], default: :draft)
    field(:title, :string)

    has_many(:revisions, Cairnloop.KnowledgeBase.Revision)

    timestamps()
  end
```

**Validation pattern** (lines 19-24):
```elixir
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:status, :title])
    |> validate_required([:status, :title])
  end
```

---

### `lib/cairnloop/knowledge_base/revision.ex` (model, CRUD Immutable)

**Analog:** `lib/cairnloop/message.ex`

**Imports pattern** (lines 1-3):
```elixir
defmodule Cairnloop.KnowledgeBase.Revision do
  use Ecto.Schema
  import Ecto.Changeset
```

**Core CRUD pattern** (lines 5-14):
```elixir
  schema "cairnloop_revisions" do
    field(:content, :string)
    field(:version, :integer)
    
    belongs_to(:article, Cairnloop.KnowledgeBase.Article)
    has_many(:chunks, Cairnloop.KnowledgeBase.Chunk)

    timestamps()
  end
```

**Validation pattern** (lines 16-21):
```elixir
  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [:content, :version, :article_id])
    |> validate_required([:content, :version, :article_id])
    # Consider `foreign_key_constraint(:article_id)`
  end
```

---

### `lib/cairnloop/knowledge_base.ex` (context, CRUD)

**Analog:** `lib/cairnloop/chat.ex`

**Imports pattern** (lines 1-9):
```elixir
defmodule Cairnloop.KnowledgeBase do
  import Ecto.Query
  alias Cairnloop.KnowledgeBase.{Article, Revision, Chunk}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end
```

**Core Query pattern** (lines 16-22):
```elixir
  def get_article!(id) do
    Article
    |> repo().get!(id)
    |> repo().preload(
      revisions: from(r in Revision, order_by: [desc: r.inserted_at])
    )
  end
```

**Complex Multi-insert pattern** (lines 24-41):
*(Reference `Cairnloop.Chat.reply_to_conversation`)*
```elixir
  def publish_revision(article_id, content, opts \\ []) do
    article = repo().get!(Article, article_id)
    
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :revision,
      Revision.changeset(%Revision{}, %{
        article_id: article.id,
        content: content,
        version: 1 # Increment logic goes here
      })
    )
    |> Ecto.Multi.update(:article, Ecto.Changeset.change(article, %{status: :published}))
    |> repo().transaction()
  end
```

---

## Shared Patterns

### Dynamic Repo Loading
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** All Context modules
```elixir
  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end
```

### Complex Operations via Ecto.Multi
**Source:** `lib/cairnloop/chat.ex`
**Apply to:** Operations spanning multiple tables (e.g., publishing an Article which creates a Revision).
```elixir
    Ecto.Multi.new()
    |> Ecto.Multi.insert(...)
    |> Ecto.Multi.update(...)
    |> repo().transaction()
```

## No Analog Found

Files with no close match in the codebase:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `priv/repo/migrations/*` | migration | DDL | The `priv/repo/migrations/` directory was not found in the current tree, meaning we fallback to standard Ecto migration structures. |

## Metadata

**Analog search scope:** `lib/cairnloop/**/*.ex`
**Files scanned:** 5
**Pattern extraction date:** 2024
