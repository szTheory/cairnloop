# Phase M009-S04: Retrieval Telemetry & Gap Signals - Pattern Map

**Mapped:** 2026-05-20
**Files analyzed:** 13 target files + supporting analogs
**Analogs found:** 10 / 12 likely phase files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/telemetry.ex` | utility | event-driven | `lib/cairnloop/telemetry.ex` | exact |
| `lib/cairnloop/retrieval.ex` | service | request-response | `lib/cairnloop/retrieval.ex` | exact |
| `lib/cairnloop/retrieval/result.ex` | model | transform | `lib/cairnloop/retrieval/result.ex` | exact |
| `lib/cairnloop/retrieval/gap_event.ex` | model | append-only | `lib/cairnloop/retrieval/resolved_case_evidence.ex` | role-match |
| `priv/repo/migrations/*_add_retrieval_gap_events.exs` | migration | append-only | `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` | role-match |
| `lib/cairnloop/retrieval/workers/persist_gap_event.ex` or replay worker | worker | event-driven | `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` | role-match |
| `lib/cairnloop/automation/workers/draft_worker.ex` | worker | request-response | `lib/cairnloop/automation/workers/draft_worker.ex` | exact |
| `lib/cairnloop/automation/scoria_engine.ex` | service | transform | `lib/cairnloop/automation/scoria_engine.ex` | exact |
| `lib/cairnloop/web/search_modal_component.ex` | component | request-response | `lib/cairnloop/web/search_modal_component.ex` | exact |
| `lib/cairnloop/web/search_result_presenter.ex` | utility | transform | `lib/cairnloop/web/search_result_presenter.ex` | exact |
| `lib/cairnloop/web/conversation_live.ex` | component | request-response | `lib/cairnloop/web/conversation_live.ex` | exact |
| `test/...retrieval/draft/search/liveview...` | test | event-driven + request-response | existing retrieval/worker/liveview tests | exact/role-match |

## Pattern Assignments

### `lib/cairnloop/telemetry.ex` and retrieval telemetry emitters

**Primary analog:** `lib/cairnloop/telemetry.ex:27-39`

**Use this wrapper pattern for the public contract**
```elixir
def span(event_suffix, metadata, fun) when is_list(event_suffix) do
  :telemetry.span([:cairnloop | event_suffix], metadata, fun)
end

def execute(event_suffix, measurements, metadata) when is_list(event_suffix) do
  :telemetry.execute([:cairnloop | event_suffix], measurements, metadata)
end
```

**Use this call-site pattern for spans around app-boundary work**

Source: `lib/cairnloop/chat.ex:29-31, 105-107, 120-127`
```elixir
meta = %{conversation_id: conversation.id, role: role}

Cairnloop.Telemetry.span([:conversation, :reply], meta, fn ->
  result = repo().transaction(multi)
  {result, meta}
end)
```

**Use this post-transaction domain event pattern for low-cardinality measurements**

Source: `lib/cairnloop/chat.ex:166-172`
```elixir
measurements = %{duration_seconds: duration_seconds, count: 1}
event_meta = Map.put(meta, :conversation, results.conversation)
Cairnloop.Telemetry.execute([:conversation, :resolved], measurements, event_meta)
```

**Planner guidance**
- Put retrieval search and grounding spans at the `Cairnloop.Retrieval` boundary, not inside telemetry handlers.
- Keep metric metadata bounded like `surface`, `outcome`, `reason`, `canonical_count`, `assistive_count`.
- Keep high-cardinality evidence in durable storage, not label metadata.

---

### `lib/cairnloop/retrieval.ex`

**Primary analog:** `lib/cairnloop/retrieval.ex:12-16, 18-50, 116-163, 206-251, 253-264`

**Use this facade-first orchestration pattern**
```elixir
def search(query, opts \\ []) do
  knowledge_base_results = search_knowledge_base(query, opts)
  resolved_case_results = search_resolved_cases(query, opts)
  ranker(opts).merge(knowledge_base_results, resolved_case_results, opts)
end
```

**Use this normalized boundary return shape for drafting/gap capture**
```elixir
%{
  query: query,
  canonical_results: canonical,
  assistive_results: assistive,
  evidence: Enum.map(results, &serialize_result/1),
  clarification_attempts: clarification_attempts,
  grounding_assessment: assess_grounding(canonical, assistive, clarification_attempts)
}
```

**Use this failure fallback pattern rather than raising through the draft path**
```elixir
rescue
  _error ->
    %{
      query: extract_query(query_or_context),
      canonical_results: [],
      assistive_results: [],
      evidence: [],
      clarification_attempts: 0,
      grounding_assessment: %{status: :escalation, reason: :retrieval_error, ...}
    }
```

**Use this replay/enqueue seam for durable retryable work**
```elixir
defp enqueue_job(job, opts) do
  enqueue_fn = Keyword.get(opts, :enqueue_fn, &Oban.insert/1)
  enqueue_fn.(job)
end
```

Source: `lib/cairnloop/retrieval.ex:116-144`
```elixir
failed_jobs_query
|> repo().all()
|> Enum.reduce_while({:ok, []}, fn %Oban.Job{} = job, {:ok, acc} ->
  replay_job = %{job | id: nil, state: "available", attempt: 0}
  ...
end)
```

**Planner guidance**
- Add retrieval telemetry and gap-event writes here or in direct callers of `ground_for_draft/2` and search UI.
- Preserve the coarse `grounding_assessment.status` contract and add deeper diagnostic metadata under it.

---

### `lib/cairnloop/retrieval/result.ex` and result-contract reuse

**Primary analog:** `lib/cairnloop/retrieval/result.ex:1-26`

**Keep extending the normalized struct instead of inventing per-surface payloads**
```elixir
defstruct [
  :id,
  :title,
  :content,
  :source_type,
  :trust_level,
  :visibility,
  :citation_target,
  ...
  :score,
  :can_ground_reply?,
  metadata: %{},
  match_reasons: [],
  keyword_rank: nil,
  semantic_rank: nil
]
```

**Serialization pattern**

Source: `lib/cairnloop/retrieval.ex:253-264`
```elixir
%{
  id: result.id,
  title: result.title,
  content: result.content,
  source_type: result.source_type,
  trust_level: result.trust_level,
  citation_target: result.citation_target,
  match_reasons: result.match_reasons
}
```

**Presenter/UI rehydration pattern**

Source: `lib/cairnloop/web/conversation_live.ex:495-515`
```elixir
defp draft_evidence(%Draft{evidence_snapshot: %{evidence: evidence}}) when is_list(evidence),
  do: Enum.map(evidence, &to_result/1)

defp to_result(%{} = evidence) do
  evidence
  |> Enum.into(%{}, fn
    {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
    pair -> pair
  end)
  |> then(&struct(Result, &1))
end
```

**Planner guidance**
- Reuse `Result`-shaped evidence snapshots for gap-event attempted evidence and UI trust cues.
- Keep `source_type` and `trust_level` first-class everywhere.

---

### `lib/cairnloop/retrieval/gap_event.ex`

**Closest analog:** `lib/cairnloop/retrieval/resolved_case_evidence.ex:1-59`

**Schema/changeset pattern to copy**
```elixir
schema "..." do
  field :metadata, :map, default: %{}
  belongs_to :conversation, Cairnloop.Conversation
  timestamps()
end

def changeset(record, attrs) do
  record
  |> cast(attrs, [..., :metadata])
  |> validate_required([...])
  |> unique_constraint(...)
end
```

**Bounded metadata validation pattern**

Source: `lib/cairnloop/retrieval/resolved_case_evidence.ex:50-58`
```elixir
validate_change(changeset, :metadata, fn :metadata, metadata ->
  if map_size(metadata || %{}) <= 10, do: [], else: [metadata: "must contain at most 10 keys"]
end)
```

**Enum pattern for typed bounded fields**

Source analogs:
- `lib/cairnloop/automation/draft.ex:8-22`
- `lib/cairnloop/conversation.ex:6-12`

Use `Ecto.Enum` for fields like `surface`, `outcome_class`, `grounding_status`, `source_mix`.

**Planner guidance**
- There is no exact append-only event schema today.
- Prefer a single focused table with typed envelope fields plus bounded `:map` payloads.
- Do not model this after `resolved_case_evidence` uniqueness on `conversation_id`; append-only implies no upsert key by conversation.

---

### `priv/repo/migrations/*_add_retrieval_gap_events.exs`

**Closest analog:** `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs:37-85`

**Use this migration style**
```elixir
create table(:cairnloop_resolved_case_evidences) do
  add :conversation_id, references(:cairnloop_conversations, on_delete: :delete_all), null: false
  add :metadata, :map, null: false, default: %{}
  timestamps()
end

create index(:cairnloop_resolved_case_evidences, [:resolved_at])
create index(:cairnloop_resolved_case_evidences, [:host_user_id])
```

**Planner guidance**
- For append-only gap events, prefer regular indexes on query dimensions like occurrence time, host scope, surface, outcome/reason, fingerprint.
- Avoid uniqueness constraints unless dedupe requires a bounded synthetic key.
- Use `:map` defaults and `null: false` the same way existing retrieval tables do.

---

### transactional persistence for durable gap writes

**Primary analog 1:** `lib/cairnloop/automation.ex:16-34`
```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:draft, Draft.changeset(%Draft{}, attrs))
|> repo().transaction()
|> case do
  {:ok, %{draft: draft}} -> ...
  {:error, :draft, changeset, _changes} -> {:error, changeset}
end
```

**Primary analog 2:** `lib/cairnloop/chat.ex:128-176`
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(:conversation, ...)
|> Ecto.Multi.insert(:notify_job, ...)
|> Ecto.Multi.insert(:resolved_case_index_job, ...)
|> auditor.audit(...)
|> Ecto.Multi.merge(fn _changes -> ... end)
|> repo().transaction()
```

**Primary analog 3:** `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex:41-79`
```elixir
repo().transaction(fn ->
  ...
  Ecto.Multi.new()
  |> Ecto.Multi.delete_all(:delete_old_chunks, query)
  |> Ecto.Multi.insert_all(:insert_chunks, ResolvedCaseChunk, chunk_records)
  |> repo().transaction()
end)
```

**Planner guidance**
- For synchronous gap persistence, use `Ecto.Multi.insert` at the application boundary.
- If async durability is chosen, enqueue the worker from the boundary inside the same `Ecto.Multi`.
- If dedupe is needed, do it before insert or with a bounded unique key, not by mutating prior events.

---

### Oban worker and replay patterns

**Primary analogs**
- `lib/cairnloop/automation/workers/draft_worker.ex:1-29`
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex:12-57`
- `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex:15-35`

**Worker module/header pattern**
```elixir
use Oban.Worker, queue: :default, unique: [period: 60]
```

**Worker perform pattern**
```elixir
def perform(%Oban.Job{args: %{"conversation_id" => conversation_id} = args}) do
  case repo().get(Conversation, conversation_id) do
    nil -> {:error, :conversation_not_found}
    conversation -> ...
  end
end
```

**OpenInference adapter pattern already in workers**

Source: `lib/cairnloop/automation/workers/draft_worker.ex:12-26`
```elixir
:telemetry.execute([:openinference, :span, :start], %{system_time: start_time}, %{trace_id: trace_id, ...})
...
:telemetry.execute([:openinference, :span, :stop], %{duration: duration}, %{status: status})
```

**Replay pattern**

Source: `lib/cairnloop/retrieval.ex:116-144`
```elixir
replay_job = %{job | id: nil, state: "available", attempt: 0}
case enqueue_job(replay_job, opts) do
  {:ok, replayed_job} -> ...
end
```

**Planner guidance**
- If gap-event persistence can fail independently, model a dedicated worker plus replay through the existing `Retrieval.replay_failed/1` seam.
- Keep worker lifecycle state separate from retrieval trust outcome fields.

---

### search/draft lightweight trust cues

**Primary analog:** `lib/cairnloop/web/search_modal_component.ex:83-140, 146-183, 384-423, 490-504`

**Use this fixed-order surface split**
```elixir
@section_order [:knowledge_base, :resolved_case]

defp build_sections(results) do
  Enum.map(@section_order, fn source_type ->
    %{source_type: source_type, title: section_title(source_type), results: Enum.filter(results, &(&1.source_type == source_type))}
  end)
end
```

**Use this calm no-hit copy pattern**
```elixir
defp empty_section_copy(:knowledge_base, _query), do: "No knowledge base matches for this query."
defp empty_section_copy(:resolved_case, _query), do: "No similar resolved cases for this query."
```

**Use this badge/presenter indirection pattern**
```elixir
source_label: SearchResultPresenter.source_label(result),
trust_label: SearchResultPresenter.trust_label(result),
row_snippet: SearchResultPresenter.row_snippet(result),
recency_label: SearchResultPresenter.recency_label(result)
```

**Conversation draft evidence rail pattern**

Source: `lib/cairnloop/web/conversation_live.ex:398-418`
```elixir
<strong>Supporting evidence</strong>
...
<strong><%= SearchResultPresenter.source_label(evidence) %></strong>
<strong><%= SearchResultPresenter.trust_label(evidence) %></strong>
<p><%= SearchResultPresenter.row_snippet(evidence) %></p>
<p><em><%= SearchResultPresenter.recency_label(evidence) %></em></p>
```

**Explicit operator-state copy pattern**

Source: `lib/cairnloop/web/conversation_live.ex:475-493`
```elixir
defp proposal_state_label(%Draft{proposal_type: :clarification}), do: "Clarification required"
defp proposal_state_label(%Draft{proposal_type: :escalation}), do: "Escalation recommended"
```

**Planner guidance**
- Add retrieval quality cues by extending presenter output and existing evidence rails, not by introducing a new routed console.
- Keep wording source-aware and calm; do not expose raw scores.

---

### `lib/cairnloop/web/search_result_presenter.ex`

**Primary analog:** `lib/cairnloop/web/search_result_presenter.ex:4-117`

**Use this source/trust label mapping**
```elixir
def source_label(%Result{source_type: :knowledge_base}), do: "Knowledge Base"
def source_label(%Result{source_type: :resolved_case}), do: "Resolved case"

def trust_label(%Result{trust_level: :canonical}), do: "Canonical guidance"
def trust_label(%Result{trust_level: :assistive}), do: "Supporting evidence"
```

**Use this result-shape-specific preview composition**
```elixir
def preview_copy(%Result{source_type: :resolved_case} = result) do
  [
    preview_block("Issue summary", result.issue_summary),
    preview_block("Resolution note", result.resolution_note),
    preview_actions(result.actions_taken),
    preview_block("Outcome", result.outcome),
    preview_block("Matched excerpt", preview_excerpt(result))
  ]
  |> Enum.filter(&present?/1)
end
```

**Planner guidance**
- Put trust/gap phrasing in the presenter so both search modal and conversation surfaces stay aligned.

## Shared Patterns

### Public telemetry contract

**Source:** `lib/cairnloop/telemetry.ex:30-38`
```elixir
:telemetry.span([:cairnloop | event_suffix], metadata, fun)
:telemetry.execute([:cairnloop | event_suffix], measurements, metadata)
```

Apply to all retrieval search/grounding/gap events.

### Atomic DB + job composition

**Source:** `lib/cairnloop/chat.ex:127-165`, `lib/cairnloop/knowledge_base.ex:52-61`
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(...)
|> Ecto.Multi.insert(:worker_job, Worker.new(%{...}))
|> repo().transaction()
```

Apply when a user-visible retrieval outcome and a durable async follow-up must stay coherent.

### Result contract reuse

**Source:** `lib/cairnloop/retrieval/result.ex:1-26`, `lib/cairnloop/web/conversation_live.ex:495-515`

Use `Result`-compatible maps for evidence snapshots, UI rendering, and any durable attempted-evidence payloads.

### Calm operator wording

**Source:** `lib/cairnloop/web/search_modal_component.ex:405-408`, `lib/cairnloop/web/conversation_live.ex:483-488`

Reuse explicit no-hit / clarification / escalation copy patterns. Avoid score-heavy or debug-heavy wording.

## Test Patterns

### Telemetry capture

**Sources**
- `test/cairnloop/automation_test.exs:52-64, 94-95`
- `test/cairnloop/chat_test.exs:158-193`
- `test/cairnloop/automation/workers/draft_worker_test.exs:74-109`

**Pattern**
```elixir
:telemetry.attach_many(handler_id, [event1, event2], fn name, measurements, metadata, _config ->
  send(parent, {:telemetry_event, name, measurements, metadata})
end, nil)

assert_receive {:telemetry_event, [:cairnloop, ...], %{count: 1}, %{...}}
```

Use for both stable `[:cairnloop, ...]` events and OpenInference adapter events.

### Worker persistence capture

**Sources**
- `test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs:36-47, 81-96`
- `test/cairnloop/knowledge_base/workers/chunk_revision_test.exs:16-36, 56-66`

Pattern: mock `repo().transaction/1`, inspect `Ecto.Multi.to_list/1`, and `send/2` inserted records back to the test process.

### Retrieval contract tests

**Sources**
- `test/cairnloop/retrieval_test.exs:64-128`
- `test/cairnloop/automation/scoria_engine_test.exs:7-47`

Pattern: provide provider mocks returning `Result` structs, then assert:
- source ordering
- trust labels / `can_ground_reply?`
- `match_reasons`
- stable `grounding_assessment.status` and `reason`

### Search and draft UI surfaces

**Sources**
- `test/cairnloop/web/search_modal_component_test.exs:176-201`
- `test/cairnloop/web/conversation_live_test.exs:312-449`

Pattern: render HTML and assert for:
- fixed KB-before-resolved-case ordering
- source/trust labels
- explicit empty/error/clarification/escalation copy
- open-target links

## No Exact Analog Found

| File/Concern | Closest Analog | Reason |
|---|---|---|
| Append-only retrieval gap event schema | `lib/cairnloop/retrieval/resolved_case_evidence.ex` | Existing retrieval storage is upsert-per-conversation, not append-only |
| Dedicated retrieval gap persistence worker | `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` | Existing worker indexes resolved corpus, not loss/failure events |
| Retrieval telemetry namespace under `[:cairnloop, :retrieval, ...]` | `lib/cairnloop/chat.ex` + `lib/cairnloop/telemetry.ex` | Current stable events cover conversation/feedback, not retrieval |

## Metadata

**Analog search scope:** `lib/cairnloop`, `priv/repo/migrations`, `test/cairnloop`
**Key supporting analogs:** `lib/cairnloop/chat.ex`, `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/automation/scoria_engine.ex`, `test/cairnloop/web/search_modal_component_test.exs`, `test/cairnloop/web/conversation_live_test.exs`
**Planner note:** Reuse existing seams; add new append-only storage as the only genuinely new pattern family in this phase.
