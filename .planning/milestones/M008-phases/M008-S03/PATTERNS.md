# Phase 3: Semantic Chunking & pgvector Embeddings (Oban) - Pattern Map

**Mapped:** 2024-05-24 (Current Date)
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/embedder.ex` | provider | request-response | `lib/cairnloop/context_provider.ex` | exact |
| `lib/cairnloop/embedder/external_api.ex` | provider | request-response | `lib/cairnloop/default_context_provider.ex` | role-match |
| `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` | worker | event-driven | `lib/cairnloop/automation/workers/draft_worker.ex` | exact |
| `lib/cairnloop/knowledge_base/markdown_parser.ex` | utility | transform | `lib/cairnloop/ingress/email_parser.ex` | exact |
| `lib/cairnloop/knowledge_base/chunk.ex` | model | CRUD | `lib/cairnloop/knowledge_base/chunk.ex` | exact |
| `lib/cairnloop/knowledge_base.ex` | context | CRUD | `lib/cairnloop/knowledge_base.ex` | exact |

## Pattern Assignments

### `lib/cairnloop/embedder.ex` (provider, request-response)

**Analog:** `lib/cairnloop/context_provider.ex`

**Behaviour pattern** (lines 1-24):
```elixir
defmodule Cairnloop.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context to Cairnloop.
  ...
  """

  @doc """
  Retrieves context details for a given identity.
  """
  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
```

---

### `lib/cairnloop/embedder/external_api.ex` (provider, request-response)

**Analog:** `lib/cairnloop/default_context_provider.ex`

**Implementation pattern** (lines 1-10):
```elixir
defmodule Cairnloop.DefaultContextProvider do
  @moduledoc """
  Default implementation of Cairnloop.ContextProvider.
  """

  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(_actor_id, _opts \\ []) do
    {:ok, %{}}
  end
end
```

---

### `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` (worker, event-driven)

**Analog:** `lib/cairnloop/automation/workers/draft_worker.ex`

**Oban Worker pattern** (lines 1-5):
```elixir
defmodule Cairnloop.Automation.Workers.DraftWorker do
  use Oban.Worker,
    queue: :default,
    unique: [period: 60, states: [:scheduled]],
    replace: [scheduled: [:scheduled_at]]
```

**Job perform pattern with Telemetry** (lines 7-16):
```elixir
  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id}}) do
    trace_id = Ecto.UUID.generate()
    start_time = System.system_time()
    start_mono = System.monotonic_time()

    :telemetry.execute(
      [:openinference, :span, :start],
      %{system_time: start_time},
      %{trace_id: trace_id, span_name: "DraftWorker", span_kind: "AGENT"}
    )
```

---

### `lib/cairnloop/knowledge_base/markdown_parser.ex` (utility, transform)

**Analog:** `lib/cairnloop/ingress/email_parser.ex`

**Pure function pattern** (lines 1-13):
```elixir
defmodule Cairnloop.Ingress.EmailParser do
  @doc """
  Parses an email body to strictly isolate new reply text from quoted history.
  """
  def parse(email_body) when is_binary(email_body) do
    # ...
    email_body
    |> String.split(~r/(?i)(^On\s.*wrote:$|^>)/m)
    |> List.first()
    |> String.trim()
  end

  def parse(_), do: ""
end
```

---

### `lib/cairnloop/knowledge_base/chunk.ex` (model, CRUD)

**Analog:** `lib/cairnloop/knowledge_base/chunk.ex`

**Ecto Schema with pgvector** (lines 1-17):
```elixir
defmodule Cairnloop.KnowledgeBase.Chunk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_chunks" do
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :revision, Cairnloop.KnowledgeBase.Revision

    timestamps()
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:content, :embedding, :revision_id])
    |> validate_required([:content, :embedding, :revision_id])
  end
end
```

---

### `lib/cairnloop/knowledge_base.ex` (context, CRUD)

**Analog:** `lib/cairnloop/knowledge_base.ex`

**Context multi-operation pattern** (lines 40-51):
```elixir
  def publish_revision(revision) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
    |> Ecto.Multi.update(:article, fn %{revision: rev} ->
      Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
    end)
    |> repo().transaction()
    |> case do
      {:ok, %{revision: published_revision}} -> {:ok, published_revision}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end
```

## Shared Patterns

### Telemetry Tracing
**Source:** `lib/cairnloop/automation/workers/draft_worker.ex`
**Apply to:** All Oban workers
Workers should emit `[:openinference, :span, :start]` and `[:openinference, :span, :stop]` telemetry events to track performance and status.

### Transactional Boundaries (Ecto.Multi)
**Source:** `lib/cairnloop/knowledge_base.ex`
**Apply to:** Context operations that modify multiple schemas or create associated records simultaneously.

## Metadata

**Analog search scope:** `lib/cairnloop/**/*.ex`
**Files scanned:** 43
**Pattern extraction date:** 2024-05-24
