# Phase 9: Gap Candidate Discovery - Pattern Map

**Mapped:** 2026-05-21
**Files analyzed:** 11 likely phase files + supporting analogs
**Analogs found:** 10 / 11 likely phase files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/knowledge_automation.ex` | service | request-response | `lib/cairnloop/retrieval.ex` | role-match |
| `lib/cairnloop/knowledge_automation/gap_candidate.ex` | model | CRUD/read-model | `lib/cairnloop/retrieval/gap_event.ex` | role-match |
| `lib/cairnloop/knowledge_automation/gap_candidate_snapshot.ex` or embedded evidence struct | model | transform | `lib/cairnloop/retrieval/gap_event_snapshot.ex` | role-match |
| `priv/repo/migrations/*_add_gap_candidates.exs` | migration | CRUD/read-model | `priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs` and `20260521000000_align_retrieval_gap_event_scope_semantics.exs` | role-match |
| `lib/cairnloop/knowledge_automation/workers/cluster_gap_candidates.ex` | worker | batch/event-driven | `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` | role-match |
| `lib/cairnloop/knowledge_automation/workers/prune_gap_candidates.ex` or refresh worker | worker | batch | `lib/cairnloop/retrieval/workers/prune_gap_events.ex` | exact |
| `lib/cairnloop/knowledge_automation/workers/replay_gap_candidates.ex` or public replay API | worker/service | replay | `lib/cairnloop/retrieval.ex:158-189` | exact |
| `lib/cairnloop/web/gap_dashboard_live.ex` | LiveView | request-response | `lib/cairnloop/web/conversation_live.ex` | role-match |
| `lib/cairnloop/web/gap_candidate_live/show.ex` or component for candidate detail | LiveView/component | request-response | `lib/cairnloop/web/search_modal_component.ex` | role-match |
| `lib/cairnloop/web/gap_candidate_presenter.ex` | utility | transform | `lib/cairnloop/web/search_result_presenter.ex` | exact |
| `test/cairnloop/knowledge_automation/**` and `test/cairnloop/web/gap*_test.exs` | test | domain + worker + LiveView | existing retrieval / worker / LiveView tests | exact/role-match |

## Pattern Assignments

### `lib/cairnloop/knowledge_automation.ex` (service, request-response)

**Primary analog:** `lib/cairnloop/retrieval.ex`

**Imports and façade shape** (`lib/cairnloop/retrieval.ex:1-9`)
```elixir
defmodule Cairnloop.Retrieval do
  import Ecto.Query

  alias Cairnloop.Conversation
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.Retrieval.{Providers, Ranker, Result, Telemetry}
```

**Use this public-API orchestration pattern** (`lib/cairnloop/retrieval.ex:12-33`, `35-66`)
```elixir
def search(query, opts \\ []) do
  started_at = System.monotonic_time()

  case validate_scope(opts) do
    :ok ->
      try do
        knowledge_base_results = search_knowledge_base(query, opts)
        resolved_case_results = search_resolved_cases(query, opts)
        results = ranker(opts).merge(knowledge_base_results, resolved_case_results, opts)

        emit_search_telemetry(results, opts, started_at)
        results
      rescue
        error ->
          emit_search_error_telemetry(error, opts, started_at)
          reraise error, __STACKTRACE__
      end

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Replay / requeue seam to copy for cluster reprocessing** (`lib/cairnloop/retrieval.ex:158-189`)
```elixir
def replay_failed(opts \\ []) do
  queue = Keyword.get(opts, :queue, "default")
  worker = Keyword.get(opts, :worker)

  failed_jobs_query
  |> repo().all()
  |> Enum.reduce_while({:ok, []}, fn %Oban.Job{} = job, {:ok, acc} ->
    replay_job = %{job | id: nil, state: "available", attempt: 0}

    case enqueue_job(replay_job, opts) do
      {:ok, replayed_job} -> {:cont, {:ok, [replayed_job | acc]}}
      error -> {:halt, error}
    end
  end)
  |> reverse_ok_jobs()
end
```

**Planner guidance**
- Keep Phase 9 behind a narrow context module, not inside `Cairnloop.Retrieval`.
- Use façade functions like `list_gap_candidates/1`, `get_gap_candidate!/2`, `recluster_candidate/2`, `replay_failed_cluster_jobs/1`.
- Keep clustering job lifecycle separate from operator-facing rank or freshness semantics.

---

### `lib/cairnloop/knowledge_automation/gap_candidate.ex` (model, CRUD/read-model)

**Primary analogs:** `lib/cairnloop/retrieval/gap_event.ex`, `lib/cairnloop/automation/draft.ex`

**Ecto schema pattern** (`lib/cairnloop/retrieval/gap_event.ex:1-35`)
```elixir
defmodule Cairnloop.Retrieval.GapEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.Retrieval.GapEventSnapshot

  schema "cairnloop_retrieval_gap_events" do
    field(:occurred_at, :utc_datetime_usec)
    field(:surface, Ecto.Enum, values: @surface_values)
    field(:outcome_class, Ecto.Enum, values: @outcome_values)
    field(:reason, Ecto.Enum, values: @reason_values)
    field(:host_user_id, :string)
    field(:tenant_scope, Ecto.Enum, values: @tenant_scope_values)
    field(:ui_surface, Ecto.Enum, values: @ui_surface_values, default: :unspecified)
    ...
    embeds_many(:attempted_evidence_snapshots, GapEventSnapshot, on_replace: :delete)

    timestamps(updated_at: false)
  end
end
```

**Changeset pattern with bounded enums and counts** (`lib/cairnloop/retrieval/gap_event.ex:37-84`)
```elixir
gap_event
|> cast(attrs, [
  :occurred_at,
  :surface,
  :outcome_class,
  :reason,
  :host_user_id,
  :tenant_scope,
  :ui_surface,
  :query_fingerprint,
  :sanitized_query_excerpt,
  :canonical_hit_count,
  :assistive_hit_count,
  :clarification_attempts
])
|> cast_embed(:attempted_evidence_snapshots)
|> validate_required([...])
|> validate_length(:query_fingerprint, is: 64)
|> validate_number(:canonical_hit_count, greater_than_or_equal_to: 0)
```

**Status/rank enum pattern** (`lib/cairnloop/automation/draft.ex:7-23`)
```elixir
field(:proposal_type, Ecto.Enum,
  values: [:reply, :clarification, :escalation],
  default: :reply
)

field(:status, Ecto.Enum,
  values: [:pending, :approved, :edited, :discarded],
  default: :pending
)
```

**Recommended fields for Phase 9**
- Stable candidate identity: `fingerprint`, `status`, `title`, `summary`
- Rank/freshness metadata: `evidence_count`, `last_seen_at`, `first_seen_at`, `freshness_bucket`, `score`
- Scope and trust semantics: `tenant_scope`, `host_user_id`, `ui_surface`
- Source semantics: `canonical_gap_count`, `assistive_only_count`, `retrieval_error_count`
- Embedded evidence preview: small `embeds_many` or `:map` snapshot list, bounded like `GapEvent`

**Planner guidance**
- Model Phase 9 as a durable aggregate/read model fed from `GapEvent`, not as a mutation of `GapEvent` rows.
- Reuse `Ecto.Enum` for candidate state and freshness buckets; avoid stringly typed ranking metadata.
- Prefer `timestamps()` if the table will be updated on reclustering; use explicit `last_seen_at` rather than overloading `updated_at`.

---

### `lib/cairnloop/knowledge_automation/gap_candidate_snapshot.ex` (model, transform)

**Primary analog:** `lib/cairnloop/retrieval/gap_event_snapshot.ex`

**Embedded schema pattern** (`lib/cairnloop/retrieval/gap_event_snapshot.ex:1-39`)
```elixir
defmodule Cairnloop.Retrieval.GapEventSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:source_type, Ecto.Enum, values: @source_types, default: :unknown)
    field(:trust_level, Ecto.Enum, values: @trust_levels, default: :unknown)
    field(:title, :string)
    field(:content_excerpt, :string)
    field(:citation_target, :map, default: %{})
    field(:match_reasons, {:array, :string}, default: [])
    field(:score, :float)
  end
end
```

**Bounded embedded changeset pattern** (`lib/cairnloop/retrieval/gap_event_snapshot.ex:22-42`)
```elixir
snapshot
|> cast(attrs, [
  :source_type,
  :trust_level,
  :title,
  :content_excerpt,
  :citation_target,
  :match_reasons,
  :score
])
|> validate_length(:title, max: @max_title_length)
|> validate_length(:content_excerpt, max: @max_excerpt_length)
|> validate_change(:citation_target, fn :citation_target, citation_target ->
  if map_size(citation_target || %{}) <= 5 do
    []
  else
    [citation_target: "must contain at most 5 keys"]
  end
end)
```

**Planner guidance**
- Use an embedded snapshot for operator previews and clustering explanation, not for unbounded full lineage.
- Keep these snapshots `Result`-shaped so LiveView surfaces can reuse presenter logic.

---

### `priv/repo/migrations/*_add_gap_candidates.exs` (migration, CRUD/read-model)

**Primary analogs:** `priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs`, `priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs`

**Create-table style** (`priv/repo/migrations/20260520210000_add_retrieval_gap_events.exs:4-27`)
```elixir
def change do
  create table(:cairnloop_retrieval_gap_events) do
    add(:occurred_at, :utc_datetime_usec, null: false)
    add(:surface, :string, null: false)
    add(:outcome_class, :string, null: false)
    ...
    add(:attempted_evidence_snapshots, {:array, :map}, null: false, default: [])
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  create(index(:cairnloop_retrieval_gap_events, [:occurred_at]))
  create(index(:cairnloop_retrieval_gap_events, [:surface]))
  create(index(:cairnloop_retrieval_gap_events, [:query_fingerprint]))
end
```

**Follow-up semantic migration style** (`priv/repo/migrations/20260521000000_align_retrieval_gap_event_scope_semantics.exs:4-48`)
```elixir
def up do
  alter table(:cairnloop_retrieval_gap_events) do
    add(:ui_surface, :string, default: "unspecified", null: false)
  end

  execute("""
  UPDATE cairnloop_retrieval_gap_events
  SET ...
  """)

  alter table(:cairnloop_retrieval_gap_events) do
    modify(:tenant_scope, :string, default: "system_unscoped", null: false)
  end

  create(index(:cairnloop_retrieval_gap_events, [:ui_surface]))
  create(index(:cairnloop_retrieval_gap_events, [...]))
end
```

**Planner guidance**
- Phase-owned tables should follow the same pattern: explicit defaults, `null: false`, focused indexes on queue/query dimensions.
- Add indexes for `status`, `last_seen_at`, `score`, `tenant_scope`, `host_user_id`, and candidate `fingerprint`.
- If candidate clustering logic changes later, prefer follow-up semantic migrations rather than overfitting the initial table.

---

### `lib/cairnloop/knowledge_automation/workers/cluster_gap_candidates.ex` (worker, batch/event-driven)

**Primary analogs:** `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`, `lib/cairnloop/knowledge_base.ex`

**Worker declaration and perform contract** (`lib/cairnloop/retrieval/workers/index_resolved_conversation.ex:1-27`)
```elixir
defmodule Cairnloop.Retrieval.Workers.IndexResolvedConversation do
  use Oban.Worker, queue: :default, unique: [period: 60]

  import Ecto.Query
  ...

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id} = args}) do
    case repo().get(Conversation, conversation_id) do
      nil ->
        {:error, :conversation_not_found}

      conversation ->
        ...
    end
  end
end
```

**Batch persistence pattern with `Ecto.Multi`** (`lib/cairnloop/retrieval/workers/index_resolved_conversation.ex:29-74`)
```elixir
repo().transaction(fn ->
  evidence =
    repo().one(from e in ResolvedCaseEvidence, where: e.conversation_id == ^conversation.id)

  evidence_changeset =
    (evidence || %ResolvedCaseEvidence{})
    |> ResolvedCaseEvidence.changeset(evidence_attrs)

  with {:ok, evidence_record} <- repo().insert_or_update(evidence_changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_old_chunks, ...)
    |> Ecto.Multi.insert_all(:insert_chunks, ResolvedCaseChunk, chunk_records)
    |> repo().transaction()
  else
    {:error, changeset} -> repo().rollback(changeset)
  end
end)
```

**Transactional job insert pattern for follow-up work** (`lib/cairnloop/knowledge_base.ex:51-58`)
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
|> Ecto.Multi.update(:article, fn %{revision: rev} ->
  Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
end)
|> Ecto.Multi.insert(:chunk_job, Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id}))
|> repo().transaction()
```

**Planner guidance**
- The clustering worker should read recent `GapEvent` rows, compute a bounded fingerprint/topic key, then `insert_or_update` a candidate aggregate plus evidence preview rows in one transaction.
- If Phase 9 needs operator-triggered reclustering, enqueue the worker through the context module rather than doing heavy grouping in LiveView.
- Use Oban uniqueness for periodic/batch jobs, but keep dedupe semantics in data, not only in job uniqueness.

---

### `lib/cairnloop/knowledge_automation/workers/prune_gap_candidates.ex` (worker, batch)

**Primary analog:** `lib/cairnloop/retrieval/workers/prune_gap_events.ex`

**Retention worker pattern** (`lib/cairnloop/retrieval/workers/prune_gap_events.ex:1-64`)
```elixir
defmodule Cairnloop.Retrieval.Workers.PruneGapEvents do
  use Oban.Worker, queue: :default, unique: [period: 300]

  @retention_days 90

  def new_job(args \\ %{}, opts \\ []) do
    args
    |> Map.put_new("retention_days", @retention_days)
    |> new(opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days =
      args
      |> Map.get("retention_days", @retention_days)
      |> normalize_retention_days()

    case prune_expired(retention_days: retention_days) do
      {:ok, _count} -> :ok
      error -> error
    end
  end
end
```

**Planner guidance**
- Reuse this exact maintenance pattern for stale candidate cleanup or stale snapshot compaction.
- Keep pruning secondary to core candidate writes, same as `GapRecorder.maybe_schedule_prune/1`.

---

### `lib/cairnloop/web/gap_dashboard_live.ex` (LiveView, request-response)

**Primary analogs:** `lib/cairnloop/web/conversation_live.ex`, `lib/cairnloop/web/inbox_live.ex`

**Mount + PubSub refresh pattern** (`lib/cairnloop/web/conversation_live.ex:9-24`)
```elixir
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
  end

  socket =
    socket
    |> assign(form: to_form(%{"content" => ""}), pending_discard_draft_id: nil)
    |> reload_conversation_with_context(id)

  {:ok, socket}
end

def handle_info({:draft_created, _draft_id}, socket) do
  {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
end
```

**Simple index-style list rendering** (`lib/cairnloop/web/inbox_live.ex:6-18`, `lib/cairnloop/web/knowledge_base_live/index.ex:9-27`)
```elixir
def mount(_params, session, socket) do
  conversations = Chat.list_conversations()

  {:ok,
   assign(socket,
     conversations: conversations,
     host_user_id: Map.get(session, "host_user_id")
   )}
end
```

**Planner guidance**
- The gap dashboard should mount with preloaded ranked candidates and subscribe to a dedicated topic like `"gap-candidates"` or per-scope topics.
- Follow the existing pattern of reloading server state on `handle_info/2` rather than hand-mutating deeply nested assigns.
- Thread `host_user_id` or scope into assigns and into any embedded search/inspection surface the same way `InboxLive` and `ConversationLive` do.

---

### `lib/cairnloop/web/gap_candidate_live/show.ex` or inspection component (LiveView/component, request-response)

**Primary analogs:** `lib/cairnloop/web/search_modal_component.ex`, `lib/cairnloop/web/conversation_live.ex:374-545`

**Operator inspection state machine pattern** (`lib/cairnloop/web/search_modal_component.ex:291-323`, `372-400`)
```elixir
def handle_event("search", %{"query" => query}, socket) do
  socket = assign(socket, query: query, loading: true, error: nil)

  case run_search(socket.assigns.retrieval_module, query, search_opts(socket)) do
    {:ok, results} ->
      {:noreply,
       socket
       |> assign(loading: false)
       |> assign_results(results)}

    {:error, reason} ->
      {:noreply,
       socket
       |> clear_results()
       |> assign(loading: false, error: true, search_state: :error)}
  end
end
```

**Evidence card rendering pattern** (`lib/cairnloop/web/conversation_live.ex:374-449`)
```elixir
assigns =
  assigns
  |> assign(:draft_reply, Draft.reply_content(assigns.draft))
  |> assign(:operator_summary, draft_operator_summary(assigns.draft))
  |> assign(:grounding_reason_label, grounding_reason_label(assigns.draft))
  |> assign(:evidence, draft_evidence(assigns.draft))

~H"""
<div class="rail-card draft">
  ...
  <div class="context-field">
    <strong>Supporting evidence</strong>
    <%= if @evidence == [] do %>
      <p>No supporting evidence captured for this proposal.</p>
    <% else %>
      ...
    <% end %>
  </div>
</div>
"""
```

**Planner guidance**
- Use a side-by-side list/detail inspection surface like `SearchModalComponent`: ranked list on one side, evidence preview on the other.
- Reuse calm copy and explicit empty/error states instead of exposing scores directly.
- Candidate detail should render underlying evidence using presenter helpers and normalized `Result`-shaped snapshots.

---

### `lib/cairnloop/web/gap_candidate_presenter.ex` (utility, transform)

**Primary analog:** `lib/cairnloop/web/search_result_presenter.ex`

**Source/trust labels and recency copy** (`lib/cairnloop/web/search_result_presenter.ex:7-12`, `51-60`, `96-145`)
```elixir
def source_label(%Result{source_type: :knowledge_base}), do: "Knowledge Base"
def source_label(%Result{source_type: :resolved_case}), do: "Resolved case"

def trust_label(%Result{trust_level: :canonical}), do: "Canonical guidance"
def trust_label(%Result{trust_level: :assistive}), do: "Supporting evidence"

def recency_label(%Result{source_type: :knowledge_base} = result) do
  "Updated #{relative_time(result.updated_at)}"
end
```

**Reason-label and copy pattern** (`lib/cairnloop/web/search_result_presenter.ex:96-145`)
```elixir
def diagnostic_reason_label(:assistive_only_results), do: "Only supporting evidence matched"
def diagnostic_reason_label(:no_canonical_results), do: "No verified guidance matched"

def diagnostic_reason_copy(:assistive_only_results) do
  "Only resolved-case evidence matched, so treat this as supporting context rather than verified guidance."
end
```

**Planner guidance**
- Build a dedicated presenter for gap candidates rather than formatting rank/freshness fields inline in LiveView templates.
- Follow this file’s copy discipline: short labels, bounded reasons, calm operator language.

---

### Tests for domain, worker, and LiveView flows

**Domain and seam tests**

**Gap recorder structure to copy** (`test/cairnloop/retrieval/gap_recorder_test.exs:47-107`, `128-180`)
```elixir
assert {:ok, %GapEvent{} = gap_event} =
         GapRecorder.record(%{...}, now_fn: fn -> now end, schedule_prune_fn: fn -> :ok end)

assert gap_event.sanitized_query_excerpt ==
         "Customer [redacted-email] cannot export invoice [redacted-number] from billing"

[stored_event] = GapRecorder.list_recent(limit: 5)
assert stored_event.id == gap_event.id
```

**Retrieval classification test shape** (`test/cairnloop/retrieval_test.exs:121-224`)
```elixir
grounding = Retrieval.ground_for_draft("billing export", providers: %{...})

assert grounding.grounding_assessment.status == :strong
assert grounding.diagnostic == %{
         class: :grounded,
         reason: :canonical_results,
         canonical_hit_count: 1,
         assistive_hit_count: 1
       }
```

**Worker tests**

**Oban worker + PubSub + telemetry test pattern** (`test/cairnloop/automation/workers/draft_worker_test.exs:93-155`, `176-201`)
```elixir
Application.put_env(:cairnloop, :retrieval_module, RetrievalMock)
Application.put_env(:cairnloop, :gap_recorder, GapRecorderMock)
Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:124")

assert :ok = DraftWorker.perform(%Oban.Job{args: %{"conversation_id" => 124}})

assert_received {:ground_for_draft, %{host_surface: "conversation", host_user_id: "user_42"}, [...]}
assert_receive {:draft_created, 999}, 1000
```

**Prune worker test shape** (`test/cairnloop/retrieval/workers/prune_gap_events_test.exs:38-77`)
```elixir
assert {:ok, 1} =
         PruneGapEvents.prune_expired(
           now_fn: fn -> now end,
           prune_fn: fn cutoff ->
             ...
             1
           end
         )
```

**LiveView / component tests**

**Search-modal component tests** (`test/cairnloop/web/search_modal_component_test.exs:237-314`)
```elixir
assert_received {:retrieval_search, "missing",
                 [surface: :search_modal, host_surface: "conversation", host_user_id: "user_42"]}

assert_received {:gap_recorded,
                 %{
                   query: "missing",
                   surface: :search_modal,
                   outcome_class: :empty_recall,
                   reason: :no_canonical_results,
                   host_user_id: "user_42",
                   tenant_scope: :host_user_scoped,
                   ui_surface: "conversation"
                 }}
```

**Conversation evidence-rail rendering tests** (`test/cairnloop/web/conversation_live_test.exs:312-457`)
```elixir
assert html =~ "AI Draft / Audit"
assert html =~ "Grounding note"
assert html =~ "Supporting evidence"
assert html =~ "Canonical guidance"
assert html =~ "Supporting evidence"
```

**Planner guidance**
- Phase 9 tests should stay seam-focused: aggregate creation and dedupe semantics, worker clustering/replay behavior, and LiveView inspection rendering.
- Keep tests hermetic with repo mocks and injected dependencies, following current repo style.

## Shared Patterns

### Durable evidence seam
**Source:** `lib/cairnloop/retrieval/gap_recorder.ex:16-39`, `259-287`
**Apply to:** Gap candidate aggregation jobs and any backfill/recluster entrypoint
```elixir
case find_recent_duplicate(normalized_attrs, opts) do
  %GapEvent{} = gap_event ->
    {:ok, gap_event}

  nil ->
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:gap_event, GapEvent.changeset(%GapEvent{}, normalized_attrs))
    |> repo().transaction()
    |> case do
      {:ok, %{gap_event: gap_event}} ->
        _ = maybe_schedule_prune(opts)
        {:ok, gap_event}
      ...
    end
end
```

### Normalized evidence contract
**Source:** `lib/cairnloop/retrieval/result.ex:1-30`, `lib/cairnloop/retrieval.ex:291-305`
**Apply to:** Candidate evidence previews, cluster snapshots, operator inspection UI
```elixir
defstruct [
  :id,
  :title,
  :content,
  :source_type,
  :trust_level,
  ...
  metadata: %{},
  match_reasons: [],
  keyword_rank: nil,
  semantic_rank: nil
]
```

### Telemetry emission
**Source:** `lib/cairnloop/retrieval/telemetry.ex:30-43`, `lib/cairnloop/retrieval.ex:347-365`
**Apply to:** Candidate creation, recluster, replay, operator review interactions
```elixir
Telemetry.execute(
  @search_event,
  normalize_measurements(measurements),
  normalize_metadata(metadata)
)
```

### PubSub refresh
**Source:** `lib/cairnloop/automation/workers/draft_worker.ex:102-118`, `lib/cairnloop/web/conversation_live.ex:10-24`
**Apply to:** Dashboard refresh after clustering/replay or operator actions
```elixir
Phoenix.PubSub.broadcast(
  Cairnloop.PubSub,
  "conversation:#{conversation_id}",
  {:draft_created, draft.id}
)
```

### Transactional follow-up jobs
**Source:** `lib/cairnloop/knowledge_base.ex:51-58`
**Apply to:** Recluster follow-up or downstream maintenance jobs
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(...)
|> Ecto.Multi.insert(:chunk_job, Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id}))
|> repo().transaction()
```

## No Exact Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/cairnloop/knowledge_automation/gap_candidate.ex` aggregate scoring logic | model | CRUD/read-model | Repo has durable gap-event storage, but no aggregate/read-model that clusters many events into one operator queue row |
| `lib/cairnloop/knowledge_automation/workers/cluster_gap_candidates.ex` clustering logic | worker | batch/event-driven | Repo has indexing and pruning workers, but no grouping/topic-clustering worker over many evidence rows |

## Recommended File Map

Likely Phase 9 implementation should stay narrow and build around the existing M009 seam:

- `lib/cairnloop/knowledge_automation.ex`
- `lib/cairnloop/knowledge_automation/gap_candidate.ex`
- `lib/cairnloop/knowledge_automation/gap_candidate_snapshot.ex`
- `lib/cairnloop/knowledge_automation/workers/cluster_gap_candidates.ex`
- `lib/cairnloop/knowledge_automation/workers/prune_gap_candidates.ex`
- `lib/cairnloop/web/gap_dashboard_live.ex`
- `lib/cairnloop/web/gap_candidate_presenter.ex`
- `priv/repo/migrations/*_add_gap_candidates.exs`
- `test/cairnloop/knowledge_automation/gap_candidate_test.exs`
- `test/cairnloop/knowledge_automation/workers/cluster_gap_candidates_test.exs`
- `test/cairnloop/web/gap_dashboard_live_test.exs`

## Metadata

**Analog search scope:** `lib/cairnloop/retrieval/**`, `lib/cairnloop/web/**`, `lib/cairnloop/automation/**`, `priv/repo/migrations/**`, `test/cairnloop/**`
**Files scanned:** 20+
**Pattern extraction date:** 2026-05-21
