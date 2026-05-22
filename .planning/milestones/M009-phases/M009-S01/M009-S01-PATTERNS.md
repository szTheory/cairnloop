# M009-S01 Pattern Map

## Target Files And Closest Analogs

| Planned file | Role | Closest analog | Why it matches |
|---|---|---|---|
| `lib/cairnloop/retrieval.ex` | public context facade | `lib/cairnloop/knowledge_base.ex` | Existing context-style public API over repo-backed domain behavior |
| `lib/cairnloop/retrieval/providers/knowledge_base.ex` | KB retrieval provider | `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` | Already owns KB chunk shape and embedding flow |
| `lib/cairnloop/retrieval/providers/resolved_cases.ex` | assistive evidence provider | `lib/cairnloop/chat.ex` | Existing resolved-conversation boundary and metadata source |
| `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` | transactional async indexing worker | `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` | Same Oban + repo transaction + idempotent replacement pattern |
| `lib/cairnloop/retrieval/resolved_case_evidence.ex` | schema for assistive source documents | `lib/cairnloop/conversation.ex` | Reuses resolved conversation timing and subject semantics |
| `lib/mix/tasks/cairnloop.retrieval.rebuild.ex` | operator/developer maintenance task | `lib/mix/tasks/cairnloop.gen.notifier.ex` | Existing Cairnloop-prefixed Mix task naming and host DX intent |

## Reusable Code Patterns

### 1. Context module pattern

From `lib/cairnloop/knowledge_base.ex`:

```elixir
defmodule Cairnloop.KnowledgeBase do
  import Ecto.Query

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end
end
```

Use the same shape for `Cairnloop.Retrieval`: private repo accessor, Ecto queries, and context-owned public functions.

### 2. Transaction-bound Oban insertion

From `lib/cairnloop/knowledge_base.ex`:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(:revision, ...)
|> Ecto.Multi.insert(:chunk_job, Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id}))
|> repo().transaction()
```

Use the same pattern for:
- enqueueing KB reindex work from publish
- enqueueing resolved-case indexing from resolution

### 3. Idempotent replace-all worker writes

From `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.delete_all(:delete_old_chunks, from(c in Chunk, where: c.revision_id == ^revision_id))
|> Ecto.Multi.insert_all(:insert_chunks, Chunk, chunk_records)
|> repo().transaction()
```

Keep this exact strategy for retrieval corpus updates. It is already the cleanest anti-duplication pattern in the repo.

### 4. Resolution metadata source

From `lib/cairnloop/chat.ex`:

```elixir
meta = %{
  conversation_id: conversation.id,
  host_user_id: conversation.host_user_id,
  actor: actor,
  metadata: Enum.into(metadata, %{})
}
```

Resolved-case evidence generation should derive its structured fields from this boundary rather than from UI or downstream telemetry consumers.

### 5. Existing anti-pattern to retire later

From `lib/cairnloop/web/search_modal_component.ex`:

```elixir
case Req.post(req, json: %{query: query}) do
```

Phase 1 should not expand this direct remote-call pattern. Phase 2 should replace it with `Cairnloop.Retrieval.search/2`.

## File-Specific Guidance

### `lib/cairnloop/retrieval.ex`

- Follow context API style from `KnowledgeBase`
- Keep provider orchestration here, not in LiveView or workers
- Return structs/maps that future search UI and AI drafting can both consume

### `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`

- Mirror `ChunkRevision` for:
  - `use Oban.Worker`
  - repo lookup
  - replacement writes inside `Ecto.Multi`
- Add explicit no-op or error path for missing conversations

### `test/cairnloop/retrieval_test.exs`

- Reuse current ExUnit style from `test/cairnloop/knowledge_base_test.exs`
- Mock repo behavior with `Process.put` when feasible
- Assert ordering and labels, not just non-empty results

## Recommended Naming

- Public context: `Cairnloop.Retrieval`
- Assistive source type atom/string: `:resolved_case`
- Canonical source type atom/string: `:knowledge_base`
- Ranking helper: `Cairnloop.Retrieval.Ranker`
- Result struct: `Cairnloop.Retrieval.Result`

## Non-Patterns To Avoid

- Do not put retrieval query logic in `SearchModalComponent`
- Do not reuse `Cairnloop.Application.handle_conversation_resolved/4` as the primary Phase 1 indexing path
- Do not add a single mixed table that erases canonical-vs-assistive semantics
