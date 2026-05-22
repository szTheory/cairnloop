# Phase 11: Review-Gated KB Updates - Pattern Map

**Mapped:** 2026-05-21
**Files analyzed:** 11 likely phase files + supporting analogs
**Analogs found:** 11 / 11 likely phase files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/knowledge_automation.ex` | service | request-response | `lib/cairnloop/knowledge_automation.ex` | exact |
| `lib/cairnloop/knowledge_automation/review_task.ex` | model | CRUD/request-response | `lib/cairnloop/knowledge_automation/article_suggestion.ex`, `lib/cairnloop/knowledge_automation/gap_candidate.ex`, `lib/cairnloop/knowledge_base/revision.ex` | role-match |
| `lib/cairnloop/knowledge_automation/review_task_event.ex` | model | event-driven/audit | `lib/cairnloop/knowledge_automation/gap_candidate_membership.ex` | partial |
| `priv/repo/migrations/*_add_review_tasks*.exs` | migration | CRUD | `priv/repo/migrations/20260521020000_add_article_suggestions.exs`, `priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs` | role-match |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | LiveView | request-response | `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex`, `lib/cairnloop/web/inbox_live.ex`, `lib/cairnloop/web/knowledge_base_live/gaps.ex` | exact/role-match |
| `lib/cairnloop/web/knowledge_base_live/editor.ex` | LiveView | request-response | `lib/cairnloop/web/knowledge_base_live/editor.ex`, `lib/cairnloop/web/conversation_live.ex` | exact/role-match |
| `lib/cairnloop/web/review_task_presenter.ex` or `lib/cairnloop/web/article_suggestion_presenter.ex` changes | presenter | transform | `lib/cairnloop/web/article_suggestion_presenter.ex`, `lib/cairnloop/web/search_result_presenter.ex`, `lib/cairnloop/web/gap_candidate_presenter.ex` | exact/role-match |
| `lib/cairnloop/knowledge_automation/workers/review_task_follow_through.ex` or similar | worker | event-driven | `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`, `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex`, `lib/cairnloop/automation/workers/draft_worker.ex` | partial |
| `lib/cairnloop/knowledge_base.ex` | service | request-response/event-driven | `lib/cairnloop/knowledge_base.ex` | exact |
| `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` and editor/live tests | test | request-response | `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`, `test/cairnloop/web/knowledge_base_live_test.exs`, `test/cairnloop/web/knowledge_base_live/gaps_test.exs` | exact |
| `test/cairnloop/knowledge_automation/review_task_test.exs`, worker tests, migration assertions | test | unit/event-driven | `test/cairnloop/knowledge_automation/article_suggestion_test.exs`, `test/cairnloop/knowledge_automation/gap_candidate_test.exs`, `test/cairnloop/knowledge_base_test.exs`, `test/cairnloop/knowledge_base/workers/chunk_revision_test.exs` | role-match |

## Pattern Assignments

### `lib/cairnloop/knowledge_automation/review_task.ex` (model, CRUD/request-response)

**Primary analogs:** `lib/cairnloop/knowledge_automation/article_suggestion.ex`, `lib/cairnloop/knowledge_automation/gap_candidate.ex`, `lib/cairnloop/knowledge_base/revision.ex`

**Schema + enum posture** (`lib/cairnloop/knowledge_automation/article_suggestion.ex:7-34`)
```elixir
@status_values [:pending_generation, :ready, :failed, :dismissed]
@suggestion_type_values [:article, :revision]
@entrypoint_type_values [:gap_candidate, :article_revision]
@tenant_scope_values [:host_user_scoped, :public_only, :system_unscoped]

schema "cairnloop_article_suggestions" do
  field(:stable_key, :string)
  field(:suggestion_type, Ecto.Enum, values: @suggestion_type_values)
  field(:status, Ecto.Enum, values: @status_values, default: :pending_generation)
  field(:tenant_scope, Ecto.Enum, values: @tenant_scope_values)
  field(:host_user_id, :string)
  field(:entrypoint_type, Ecto.Enum, values: @entrypoint_type_values)
  field(:entrypoint_id, :integer)
  field(:article_id, :integer)
  field(:base_revision_id, :integer)
  ...
  timestamps(type: :utc_datetime_usec)
end
```

**Scope validation and durable required fields** (`lib/cairnloop/knowledge_automation/gap_candidate.ex:38-85`)
```elixir
gap_candidate
|> cast(attrs, [...])
|> validate_required([
  :stable_key,
  :status,
  :candidate_type,
  :title,
  :seed_excerpt,
  :tenant_scope,
  :ui_surface,
  :first_seen_at,
  :last_seen_at
])
|> validate_length(:stable_key, min: 8, max: 128)
|> validate_number(:evidence_count, greater_than_or_equal_to: 0)
|> validate_host_scope()
```

**Immutable published-boundary pattern** (`lib/cairnloop/knowledge_base/revision.ex:16-34`)
```elixir
def changeset(revision, attrs) do
  revision
  |> cast(attrs, [:content, :version, :state, :article_id])
  |> validate_required([:content, :version, :state, :article_id])
  |> enforce_immutability()
end
```

**Planner guidance**
- Keep `ReviewTask` separate from `ArticleSuggestion`. Phase context D-01/D-02 matches the repo’s existing “separate durable artifact per workflow concern” pattern.
- Use `Ecto.Enum` for task state and bounded review reason taxonomy rather than freeform strings in JSON.
- Model the task as the join between suggestion review and KB publish lifecycle: `article_suggestion_id`, `draft_revision_id`, `published_revision_id`, `base_revision_id_at_review`, `decision`, `decision_reason`, `decided_by`, `decided_at`, `published_at`, `publish_status`, `reindex_status`.
- Apply `validate_host_scope/1` style logic if tasks remain tenant-scoped like suggestions.
- Borrow the revision immutability idea for “approved against old base revision” checks: do not let `published_revision_id` or publish-success fields drift once recorded.

---

### `lib/cairnloop/knowledge_automation/review_task_event.ex` (model, event-driven/audit)

**Primary analog:** `lib/cairnloop/knowledge_automation/gap_candidate_membership.ex`

**Narrow append-only companion table pattern** (`lib/cairnloop/knowledge_automation/gap_candidate_membership.ex:7-26`)
```elixir
@source_type_values [:retrieval_gap_event, :manual_handling_case]

schema "cairnloop_gap_candidate_memberships" do
  field :source_type, Ecto.Enum, values: @source_type_values
  field :source_id, :integer

  belongs_to :gap_candidate, GapCandidate

  timestamps(type: :utc_datetime_usec, updated_at: false)
end

def changeset(membership, attrs) do
  membership
  |> cast(attrs, [:gap_candidate_id, :source_type, :source_id])
  |> validate_required([:source_type, :source_id])
  |> validate_number(:source_id, greater_than: 0)
end
```

**Planner guidance**
- There is no existing event-history table in this lane. The closest repo idiom is a small host-owned relational companion table with `updated_at: false`.
- Keep events append-only and narrow: `review_task_id`, `event_type`, `from_state`, `to_state`, `decision`, `reason`, `actor_id`, `notes`, `metadata`.
- Prefer first-class columns for queryable audit truth and keep only secondary details in `metadata`.
- Use `inserted_at` as event time; do not design a mutable “latest event” row.
- If notes are optional, keep them nullable, not the primary audit source.

---

### `priv/repo/migrations/*_add_review_tasks*.exs` (migration, CRUD)

**Primary analogs:** `priv/repo/migrations/20260521020000_add_article_suggestions.exs`, `priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs`

**Main table + indexes** (`priv/repo/migrations/20260521020000_add_article_suggestions.exs:4-31`)
```elixir
create table(:cairnloop_article_suggestions) do
  add(:stable_key, :string, null: false)
  add(:suggestion_type, :string, null: false)
  add(:status, :string, null: false, default: "pending_generation")
  add(:tenant_scope, :string, null: false)
  add(:host_user_id, :string)
  ...
  timestamps(type: :utc_datetime_usec)
end

create(unique_index(:cairnloop_article_suggestions, [:stable_key]))
create(index(:cairnloop_article_suggestions, [:status]))
create(index(:cairnloop_article_suggestions, [:entrypoint_type, :entrypoint_id]))
create(index(:cairnloop_article_suggestions, [:evidence_digest]))
create(index(:cairnloop_article_suggestions, [:base_revision_id]))
```

**Companion table pattern** (`priv/repo/migrations/20260521010000_add_gap_candidates_and_memberships.exs:29-41`)
```elixir
create table(:cairnloop_gap_candidate_memberships) do
  add :gap_candidate_id, references(:cairnloop_gap_candidates, on_delete: :delete_all),
    null: false

  add :source_type, :string, null: false
  add :source_id, :integer, null: false
  timestamps(type: :utc_datetime_usec, updated_at: false)
end

create unique_index(
         :cairnloop_gap_candidate_memberships,
         [:gap_candidate_id, :source_type, :source_id]
       )
```

**Planner guidance**
- Use two tables, not one JSON-heavy table: `cairnloop_review_tasks` and `cairnloop_review_task_events`.
- Match naming and typing conventions: string-backed enums, `utc_datetime_usec`, explicit `references`.
- Good default indexes for Phase 11: `[:status]`, `[:article_suggestion_id]`, `[:draft_revision_id]`, `[:published_revision_id]`, `[:host_user_id]`, `[:inserted_at]`.
- Add a unique index on `article_suggestion_id` if Phase 11 enforces one active task per suggestion.
- Use `on_delete: :nilify_all` for revision/article backlinks unless deletion must cascade. The existing suggestion migration uses nilify for KB links and delete-all only for ownership-style child rows.

---

### `lib/cairnloop/knowledge_automation.ex` (service, request-response)

**Primary analog:** `lib/cairnloop/knowledge_automation.ex`

**Context alias and query facade posture** (`lib/cairnloop/knowledge_automation.ex:4-17`, `29-67`)
```elixir
alias Cairnloop.KnowledgeAutomation.{
  ArticleSuggestion,
  ArticleSuggestionEvidence,
  CandidateBuilder,
  GapCandidate,
  StaleArticleSignal,
  Workers.BackfillGapCandidates,
  Workers.GenerateArticleSuggestion,
  Workers.RefreshGapCandidates
}

def list_article_suggestions(opts \\ []) do
  ArticleSuggestion
  |> apply_scope(opts)
  |> maybe_filter_article_suggestion_status(opts)
  |> order_by([suggestion], desc: suggestion.inserted_at, desc: suggestion.id)
  |> repo().all()
end

def get_article_suggestion!(id, opts \\ []) do
  ArticleSuggestion
  |> apply_scope(opts)
  |> where([suggestion], suggestion.id == ^id)
  |> repo().one!()
  |> enforce_scope!(opts, ArticleSuggestion)
end
```

**Command seam with durable write + enqueue** (`lib/cairnloop/knowledge_automation.ex:128-168`, `504-527`)
```elixir
def regenerate_article_suggestion(id, opts \\ []) do
  suggestion = get_article_suggestion!(id, opts)

  with {:ok, regenerated} <-
         suggestion
         |> ArticleSuggestion.regenerate_changeset()
         |> repo().update(),
       {:ok, _job} <- enqueue_generation_job(regenerated, opts) do
    {:ok, regenerated}
  end
end

defp insert_and_enqueue(prepared, opts) do
  with {:ok, suggestion} <-
         %ArticleSuggestion{}
         |> ArticleSuggestion.changeset(prepared)
         |> repo().insert(),
       {:ok, _job} <- enqueue_generation_job(suggestion, opts) do
    {:ok, suggestion}
  end
end
```

**Scope helpers** (`lib/cairnloop/knowledge_automation.ex:733-760`)
```elixir
defp apply_scope(query, opts) do
  query
  |> maybe_where_equal(:tenant_scope, Keyword.get(opts, :tenant_scope))
  |> maybe_where_equal(:host_user_id, Keyword.get(opts, :host_user_id))
end
```

**Editor handoff helper seam** (`lib/cairnloop/knowledge_automation.ex:140-168`)
```elixir
def create_or_reuse_authoring_article_for_suggestion(id, opts \\ []) do
  suggestion = get_article_suggestion!(id, opts)
  existing_authoring_article_id =
    suggestion.grounding_metadata
    |> map_value(:authoring_article_id)

  cond do
    suggestion.suggestion_type == :revision and suggestion.article_id ->
      {:ok, suggestion.article_id}

    existing_authoring_article_id ->
      {:ok, existing_authoring_article_id}
```

**Planner guidance**
- Add review-task APIs beside suggestion APIs, not in `KnowledgeBase`: `list_review_tasks/1`, `get_review_task!/2`, `open_review_task_for_suggestion/2`, `approve_review_task/3`, `reject_review_task/3`, `defer_review_task/3`, `mark_review_task_editing/2`, `mark_review_task_ready_for_re_review/2`, `publish_review_task/2`, `record_review_follow_through/2`.
- Keep commands shaped like existing context commands: fetch scoped row, build changeset, `repo().update/insert`, optionally enqueue worker.
- Reuse `apply_scope/2` and `enforce_scope!` for tasks and events.
- Do not overload `ArticleSuggestion` state with review lifecycle. Use review-task rows for workflow truth and leave suggestion rows proposal-only.
- For approve/edit/publish, prefer one context command that writes task state and inserts history in the same transaction.

---

### `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` (LiveView, request-response)

**Primary analogs:** `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex`, `lib/cairnloop/web/inbox_live.ex`, `lib/cairnloop/web/knowledge_base_live/gaps.ex`

**Current list/detail lane** (`lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:7-30`, `77-153`)
```elixir
def mount(_params, session, socket) do
  scope_filters = scope_filters(session)
  suggestions = knowledge_automation().list_article_suggestions(scope_filters)

  {:ok,
   assign(socket,
     suggestions: suggestions,
     selected_suggestion: List.first(suggestions),
     selected_diff: nil,
     scope_filters: scope_filters
   )}
end

def handle_params(%{"suggestion" => suggestion_id}, _uri, socket) do
  suggestion =
    suggestion_id
    |> String.to_integer()
    |> knowledge_automation().get_article_suggestion!(socket.assigns.scope_filters)

  {:noreply, assign_selected(socket, suggestion)}
end
```

**Cross-surface deep-link pattern** (`lib/cairnloop/web/knowledge_base_live/gaps.ex:30-45`, `lib/cairnloop/web/knowledge_base_live/index.ex:15-22`)
```elixir
case knowledge_automation().suggest_article(attrs) do
  {:ok, suggestion} ->
    {:noreply, push_navigate(socket, to: "/knowledge-base/suggestions?suggestion=#{suggestion.id}")}
```

```elixir
case knowledge_automation().suggest_revision(%{article_id: String.to_integer(article_id)}) do
  {:ok, suggestion} ->
    {:noreply, push_navigate(socket, to: "/knowledge-base/suggestions?suggestion=#{suggestion.id}")}
```

**Calm inbox baseline** (`lib/cairnloop/web/inbox_live.ex:11-18`, `20-43`)
```elixir
{:ok,
 assign(socket,
   conversations: conversations,
   host_user_id: Map.get(session, "host_user_id")
 )}
```

**Planner guidance**
- Evolve this screen into a task inbox/detail lane instead of replacing it. The existing LiveView already matches the phase decision to use one shared review lane.
- Replace `suggestions` with task-centric assigns, but keep the same list/detail URL shape: one selected task in params, one queue list in assigns.
- Add queue filters using explicit task states: pending review, approved ready to publish, rejected, deferred, published, publish failed or retry needed.
- Preserve evidence-first detail rendering. Approval and publish actions should sit beside evidence and diff, not inside the editor.
- Keep deep links from gap and article surfaces, but redirect to a task id once a task exists. The current push-navigate pattern is the analog to copy.

---

### `lib/cairnloop/web/knowledge_base_live/editor.ex` (LiveView, request-response)

**Primary analogs:** `lib/cairnloop/web/knowledge_base_live/editor.ex`, `lib/cairnloop/web/conversation_live.ex`

**Suggestion preload seam** (`lib/cairnloop/web/knowledge_base_live/editor.ex:11-23`, `59-70`)
```elixir
def mount(params, session, socket) do
  id = (is_map(params) && params["id"]) || session["id"]
  article = repo().get!(Article, id)
  latest_revision = KnowledgeBase.get_latest_revision(id)
  content = preload_content(params, latest_revision)
  ...
end

defp preload_content(%{"suggestion_id" => suggestion_id}, _latest_revision) do
  suggestion =
    suggestion_id
    |> normalize_id()
    |> knowledge_automation().get_article_suggestion!()

  suggestion.proposed_markdown
end
```

**Return-link / host-surface context pattern** (`lib/cairnloop/web/conversation_live.ex:161-168`, `216-217`)
```elixir
<.live_component
  module={Cairnloop.Web.SearchModalComponent}
  id="search-modal"
  host_surface="conversation"
  host_user_id={@conversation.host_user_id}
  current_path={"/#{@conversation.id}"}
  preserve_reply_form={true}
/>

<.link navigate="/">Back to Inbox</.link>
```

**Planner guidance**
- Keep the editor as the canonical authoring surface. Phase 11 should extend preload and return-path behavior, not move authoring into review.
- Replace raw `suggestion_id` semantics with task-aware params, likely `review_task_id` plus existing `suggestion_id` if needed for compatibility.
- Add explicit return-path assigns so the editor can link back to the review task lane instead of always “Back to Index”.
- Keep review evidence lightweight here: summary card, return link, maybe presenter-driven citations sidebar. Do not duplicate full review controls in editor.
- When saving a materially edited approved draft, call back into `KnowledgeAutomation` to mark the task review-needed again. That behavior belongs at the workflow boundary, not inside `KnowledgeBase`.

---

### `lib/cairnloop/knowledge_base.ex` (service, request-response/event-driven)

**Primary analog:** `lib/cairnloop/knowledge_base.ex`

**Draft then publish boundary** (`lib/cairnloop/knowledge_base.ex:32-50`, `64-73`)
```elixir
def save_draft(article, content_attrs) do
  latest = get_latest_revision(article.id)
  attrs = Enum.into(content_attrs, %{})

  multi =
    if latest && latest.state == :draft do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:revision, Revision.changeset(latest, attrs))
    else
      version = if latest, do: latest.version + 1, else: 1
      new_attrs = Map.merge(attrs, %{article_id: article.id, version: version, state: :draft})

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:revision, Revision.changeset(%Revision{}, new_attrs))
    end
end

def publish_revision(revision) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
  |> Ecto.Multi.update(:article, fn %{revision: rev} ->
    Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
  end)
  |> Ecto.Multi.insert(:chunk_job, Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id}))
  |> repo().transaction()
end
```

**Planner guidance**
- Do not invent a parallel publish pipeline for review tasks. Call `KnowledgeBase.save_draft/2` and `KnowledgeBase.publish_revision/1` from review-task commands.
- Phase 11 approval should stop after draft creation or update and record the resulting `draft_revision_id`.
- Phase 11 publish should call this exact service path and then mirror the outcome back onto the review task.
- Add base-revision freshness checks in `KnowledgeAutomation` before calling `publish_revision/1`. The existing `KnowledgeBase` API does not currently enforce review freshness.

---

### `lib/cairnloop/knowledge_automation/workers/review_task_follow_through.ex` or similar (worker, event-driven)

**Primary analogs:** `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`, `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex`, `lib/cairnloop/automation/workers/draft_worker.ex`

**Job identity pattern** (`lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:1-11`)
```elixir
use Oban.Worker,
  queue: :default,
  unique: [period: 60, fields: [:worker, :args], keys: [:entrypoint_type, :entrypoint_id, :base_revision_id, :evidence_digest]]

def new_job(args \\ %{}, opts \\ []) do
  args
  |> Enum.into(%{})
  |> stringify_keys()
  |> new(opts)
end
```

**Transactional follow-through seam** (`lib/cairnloop/knowledge_base/workers/chunk_revision.ex:13-57`)
```elixir
def perform(%Oban.Job{args: %{"revision_id" => revision_id}}) do
  result =
    case repo().get(Revision, revision_id) do
      nil ->
        {:error, :revision_not_found}

      %Revision{content: content} ->
        ...
        Ecto.Multi.new()
        |> Ecto.Multi.delete_all(:delete_old_chunks, from(c in Chunk, where: c.revision_id == ^revision_id))
        |> Ecto.Multi.insert_all(:insert_chunks, Chunk, chunk_records)
        |> repo().transaction()

        :ok
```

**Telemetry/error posture** (`lib/cairnloop/automation/workers/draft_worker.ex:9-30`)
```elixir
:telemetry.execute(
  [:openinference, :span, :start],
  %{system_time: start_time},
  %{trace_id: trace_id, span_name: "DraftWorker", span_kind: "AGENT"}
)
...
:telemetry.execute(
  [:openinference, :span, :stop],
  %{duration: duration},
  %{status: status}
)
```

**Planner guidance**
- There is no existing worker that updates a review-tracking row after KB publish completion. This is a partial analog area.
- Phase 11 can stay repo-idiomatic by either:
  1. Recording publish success synchronously in the command that calls `KnowledgeBase.publish_revision/1`, then storing the queued chunk job id on the task.
  2. Adding a small follow-through worker that receives `review_task_id` and `revision_id`, verifies downstream state, and updates `publish_status` or `reindex_status`.
- Prefer explicit durable args like the suggestion worker, not hidden process state.
- If a worker is added, make it idempotent and keyed by `review_task_id` plus `published_revision_id`.

---

### `lib/cairnloop/web/review_task_presenter.ex` or `lib/cairnloop/web/article_suggestion_presenter.ex` changes (presenter, transform)

**Primary analogs:** `lib/cairnloop/web/article_suggestion_presenter.ex`, `lib/cairnloop/web/search_result_presenter.ex`, `lib/cairnloop/web/gap_candidate_presenter.ex`

**Status/action label pattern** (`lib/cairnloop/web/article_suggestion_presenter.ex:6-24`)
```elixir
def status_label(%ArticleSuggestion{status: :pending_generation}), do: "Queued for generation"
def status_label(%ArticleSuggestion{status: :ready}), do: "Ready for review"
def status_label(%ArticleSuggestion{status: :failed}), do: "Generation blocked"
def status_label(%ArticleSuggestion{status: :dismissed}), do: "Dismissed"

def action_labels(%ArticleSuggestion{status: :ready}), do: ["regenerate", "dismiss", "open for manual edit"]
def action_labels(%ArticleSuggestion{status: :failed}), do: ["regenerate", "inspect failure"]
```

**Evidence path/trust reuse** (`lib/cairnloop/web/article_suggestion_presenter.ex:26-32`, `lib/cairnloop/web/search_result_presenter.ex:62-79`)
```elixir
def source_label(evidence), do: evidence |> to_result() |> SearchResultPresenter.source_label()
def trust_label(evidence), do: evidence |> to_result() |> SearchResultPresenter.trust_label()

def evidence_path(evidence) do
  result = to_result(evidence)
  SearchResultPresenter.open_path(result)
end
```

**Reason-label pattern** (`lib/cairnloop/web/gap_candidate_presenter.ex:1-27`, `61-79`)
```elixir
@reason_labels %{
  no_hit: "No hit",
  weak_grounding: "Weak grounding",
  manual_handling: "Manual handling",
  mixed: "Mixed evidence"
}
```

**Planner guidance**
- Keep presenter logic thin and deterministic. Task states, decision reasons, publish states, and retry-needed copy should live in a presenter, not inline in the LiveView template.
- Reuse `SearchResultPresenter` for evidence navigation and trust badges so review tasks keep the same source-language as retrieval and suggestion screens.
- Add task-centric labels such as `Pending review`, `Approved, ready to publish`, `Deferred`, `Published`, `Publish follow-through failed`.
- Put bounded reason taxonomy display helpers here rather than in the schema module.

---

### `test/cairnloop/knowledge_automation/review_task_test.exs` and migration tests (test, unit/request-response)

**Primary analogs:** `test/cairnloop/knowledge_automation/article_suggestion_test.exs`, `test/cairnloop/knowledge_automation/gap_candidate_test.exs`, `test/cairnloop/knowledge_base_test.exs`

**Changeset and migration assertion pattern** (`test/cairnloop/knowledge_automation/article_suggestion_test.exs:72-106`, `149-162`)
```elixir
changeset = ArticleSuggestion.changeset(%ArticleSuggestion{}, valid_article_attrs())
assert changeset.valid?

[migration] = Path.wildcard("priv/repo/migrations/*_add_article_suggestions.exs")
content = File.read!(migration)

assert content =~ "create table(:cairnloop_article_suggestions)"
assert content =~ "unique_index(:cairnloop_article_suggestions, [:stable_key])"
assert content =~ "index(:cairnloop_article_suggestions, [:base_revision_id])"
```

**Scoped query assertion pattern** (`test/cairnloop/knowledge_automation/gap_candidate_test.exs:108-118`, `120-172`)
```elixir
candidates = KnowledgeAutomation.list_gap_candidates()
assert Enum.map(candidates, & &1.title) == ["Top score", "Newest same score", "Older higher"]

loaded = KnowledgeAutomation.get_gap_candidate!(10, host_user_id: "user-1")
assert length(loaded.retrieval_gap_events) == 1
assert_raise Ecto.NoResultsError, fn ->
  KnowledgeAutomation.get_gap_candidate!(10, host_user_id: "other-user")
end
```

**Publish seam assertion pattern** (`test/cairnloop/knowledge_base_test.exs:93-109`)
```elixir
assert {:ok, _published_revision} = KnowledgeBase.publish_revision(revision)
assert_received {:multi_insert, :chunk_job, chunk_job}
assert chunk_job.worker == "Cairnloop.KnowledgeBase.Workers.ChunkRevision"
assert chunk_job.args == %{revision_id: 1}
```

**Planner guidance**
- Mirror the repo’s current test style: mock repo or mock context module via `Application.put_env`, then assert on durable structs and multi ops.
- Add review-task tests for:
  - state/decision validation
  - one-task-per-suggestion constraint
  - approval creating or updating draft revisions
  - stale base revision rejection before publish
  - publish command recording chunk follow-through linkage
  - event-history append on every transition

---

### `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` and editor/live tests (test, request-response)

**Primary analogs:** `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`, `test/cairnloop/web/knowledge_base_live_test.exs`, `test/cairnloop/web/knowledge_base_live/gaps_test.exs`

**Mocked context-module LiveView style** (`test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs:7-29`, `98-132`)
```elixir
defmodule MockKnowledgeAutomation do
  def list_article_suggestions(_opts) do
    Process.get(:mock_suggestions, [])
  end

  def get_article_suggestion!(id, _opts \\ []) do
    Process.get(:mock_suggestion_lookup).(id)
  end
end

{:ok, socket} = SuggestionReview.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
{:noreply, socket} = SuggestionReview.handle_params(%{"suggestion" => "11"}, "", socket)
html = render_html(socket.assigns)

assert html =~ "Suggestion review"
assert html =~ "Derived diff summary"
```

**Redirect assertion pattern** (`test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs:119-132`, `test/cairnloop/web/knowledge_base_live/gaps_test.exs:152-162`)
```elixir
assert {:live, :redirect, %{to: "/knowledge-base/77/edit?suggestion_id=11"}} =
         revision_socket.redirected
```

```elixir
assert {:live, :redirect, %{to: "/knowledge-base/suggestions?suggestion=88"}} = socket.redirected
```

**Editor preload test pattern** (`test/cairnloop/web/knowledge_base_live_test.exs:103-117`)
```elixir
{:ok, socket} =
  Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
    %{"id" => "42", "suggestion_id" => "15"},
    %{},
    %Phoenix.LiveView.Socket{}
  )

assert socket.assigns.content == "# Suggested copy\n\nPrepared from review."
```

**Planner guidance**
- Keep this direct function-call LiveView test style. The repo is not using full router-mounted LiveView integration tests here.
- Update the existing suggestion review test file rather than creating a completely separate task inbox test unless the module name changes.
- Add explicit assertions for queue-state rendering, task detail rendering, approve/reject/defer events, editor handoff with return params, and publish-state updates.

## Shared Patterns

### Scoped host-owned context access
**Source:** `lib/cairnloop/knowledge_automation.ex:53-67`, `733-760`
**Apply to:** Review task list/detail commands and queries
```elixir
ArticleSuggestion
|> apply_scope(opts)
|> where([suggestion], suggestion.id == ^id)
|> repo().one!()
|> enforce_scope!(opts, ArticleSuggestion)
```

### Publish boundary remains in `KnowledgeBase`
**Source:** `lib/cairnloop/knowledge_base.ex:64-73`
**Apply to:** Review task publish command
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
|> Ecto.Multi.update(:article, fn %{revision: rev} ->
  Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
end)
|> Ecto.Multi.insert(:chunk_job, Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id}))
|> repo().transaction()
```

### Evidence-first presentation
**Source:** `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:122-148`, `lib/cairnloop/web/article_suggestion_presenter.ex:26-42`
**Apply to:** Review inbox detail pane and editor context sidebar
```elixir
<%= for evidence <- @selected_suggestion.evidence_snapshot do %>
  <li>
    <strong><%= ArticleSuggestionPresenter.source_label(evidence) %></strong>
    ·
    <strong><%= ArticleSuggestionPresenter.trust_label(evidence) %></strong>
    <div><%= evidence.title %></div>
    <div><%= evidence.excerpt %></div>
  </li>
<% end %>
```

### Deep-link handoff between surfaces
**Source:** `lib/cairnloop/web/knowledge_base_live/gaps.ex:39-45`, `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:70-74`
**Apply to:** Gap/article launch points, review inbox, editor return path
```elixir
{:noreply, push_navigate(socket, to: "/knowledge-base/suggestions?suggestion=#{suggestion.id}")}
```

```elixir
{:noreply,
 push_navigate(
   socket,
   to: "/knowledge-base/#{target_article_id}/edit?suggestion_id=#{suggestion_id}"
 )}
```

### Worker uniqueness and explicit durable args
**Source:** `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:1-11`
**Apply to:** Any publish/reindex follow-through worker
```elixir
use Oban.Worker,
  queue: :default,
  unique: [period: 60, fields: [:worker, :args], keys: [...]]
```

## No Exact Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/cairnloop/knowledge_automation/review_task_event.ex` | model | event-driven/audit | Repo has no existing workflow-history table; `GapCandidateMembership` is only a structural analog. |
| `lib/cairnloop/knowledge_automation/workers/review_task_follow_through.ex` | worker | event-driven | Repo has workers for suggestion generation and chunking, but no worker yet that reconciles publish/reindex outcomes back into a task row. |

## Metadata

**Analog search scope:** `lib/cairnloop/knowledge_automation`, `lib/cairnloop/knowledge_base`, `lib/cairnloop/web`, `test/cairnloop`, `priv/repo/migrations`
**Files scanned:** 24
**Pattern extraction date:** 2026-05-21
