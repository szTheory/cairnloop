# Phase 10: Citation-Backed Draft Suggestions - Pattern Map

**Mapped:** 2026-05-21
**Files analyzed:** 10 likely phase files + supporting analogs
**Analogs found:** 9 / 10 likely phase files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/knowledge_automation.ex` | service | request-response | `lib/cairnloop/knowledge_automation.ex` | exact |
| `lib/cairnloop/knowledge_automation/article_suggestion.ex` | model | CRUD/read-model | `lib/cairnloop/automation/draft.ex`, `lib/cairnloop/knowledge_automation/gap_candidate.ex` | role-match |
| `lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex` or embedded evidence schema | model | transform | `lib/cairnloop/retrieval/gap_event_snapshot.ex` | exact |
| `priv/repo/migrations/*_add_article_suggestions*.exs` | migration | CRUD/read-model | `priv/repo/migrations/*_add_gap_candidates_and_memberships.exs`, `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs` | role-match |
| `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex` | worker | event-driven | `lib/cairnloop/automation/workers/draft_worker.ex` | exact |
| `lib/cairnloop/knowledge_automation/stale_article_signal.ex` or helper inside context | utility/model | transform | `lib/cairnloop/retrieval/resolved_case_evidence.ex`, `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` | partial |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | LiveView | request-response | `lib/cairnloop/web/conversation_live.ex` | role-match |
| `lib/cairnloop/web/knowledge_base_live/gaps.ex` | LiveView | request-response | `lib/cairnloop/web/knowledge_base_live/gaps.ex` | exact |
| `lib/cairnloop/web/article_suggestion_presenter.ex` | utility | transform | `lib/cairnloop/web/search_result_presenter.ex`, `lib/cairnloop/web/gap_candidate_presenter.ex` | exact |
| `test/cairnloop/knowledge_automation/**`, `test/cairnloop/web/knowledge_base_live/*suggestion*_test.exs` | test | unit + LiveView | existing knowledge automation, worker, KB, and LiveView tests | exact/role-match |

## Pattern Assignments

### `lib/cairnloop/knowledge_automation.ex` (service, request-response)

**Primary analog:** `lib/cairnloop/knowledge_automation.ex`

**Facade and query composition** (`lib/cairnloop/knowledge_automation.ex:1-23`)
```elixir
defmodule Cairnloop.KnowledgeAutomation do
  import Ecto.Query

  alias Cairnloop.KnowledgeAutomation.{
    CandidateBuilder,
    GapCandidate,
    Workers.BackfillGapCandidates,
    Workers.RefreshGapCandidates
  }

  alias Cairnloop.Retrieval.{GapEvent, ResolvedCaseEvidence}

  def list_gap_candidates(opts \\ []) do
    GapCandidate
    |> apply_scope(opts)
    |> maybe_filter_status(opts)
    |> order_by([candidate], desc: candidate.score, desc: candidate.last_seen_at, desc: candidate.id)
    |> repo().all()
  end
end
```

**Scoped detail loading with durable evidence hydration** (`lib/cairnloop/knowledge_automation.ex:25-35`, `92-157`)
```elixir
def get_gap_candidate!(id, opts \\ []) do
  candidate =
    GapCandidate
    |> apply_scope(opts)
    |> where([candidate], candidate.id == ^id)
    |> preload(:memberships)
    |> repo().one!()
    |> enforce_scope!(opts)

  hydrate_memberships(candidate)
end

defp hydrate_memberships(%GapCandidate{} = candidate) do
  retrieval_ids =
    candidate.memberships
    |> Enum.filter(&(&1.source_type == :retrieval_gap_event))
    |> Enum.map(& &1.source_id)

  manual_ids =
    candidate.memberships
    |> Enum.filter(&(&1.source_type == :manual_handling_case))
    |> Enum.map(& &1.source_id)
  ...
end
```

**Planner guidance**
- Keep Phase 10 behind the same host-owned context boundary.
- Add public seams such as `suggest_article/2`, `suggest_revision/2`, `get_article_suggestion!/2`, `list_article_suggestions/1`, `dismiss_article_suggestion/2`, `regenerate_article_suggestion/2`.
- Reuse `apply_scope/2` and `enforce_scope!/2` posture for any suggestion tied to `host_user_id` or tenant scope.
- Keep evidence hydration explicit instead of hiding it in generic preload chains.

---

### `lib/cairnloop/knowledge_automation/article_suggestion.ex` (model, CRUD/read-model)

**Primary analogs:** `lib/cairnloop/automation/draft.ex`, `lib/cairnloop/knowledge_automation/gap_candidate.ex`, `lib/cairnloop/knowledge_base/revision.ex`

**Enum-backed durable artifact shape** (`lib/cairnloop/automation/draft.ex:5-27`)
```elixir
schema "cairnloop_drafts" do
  field(:content, :string)

  field(:proposal_type, Ecto.Enum,
    values: [:reply, :clarification, :escalation],
    default: :reply
  )

  field(:operator_summary, :string)
  field(:evidence_snapshot, :map, default: %{})
  field(:grounding_metadata, :map, default: %{})

  field(:status, Ecto.Enum,
    values: [:pending, :approved, :edited, :discarded],
    default: :pending
  )
end
```

**Host-owned state + virtual evidence payloads** (`lib/cairnloop/knowledge_automation/gap_candidate.ex:12-35`)
```elixir
schema "cairnloop_gap_candidates" do
  field :stable_key, :string
  field :status, Ecto.Enum, values: @status_values, default: :open
  field :tenant_scope, Ecto.Enum, values: @tenant_scope_values
  field :host_user_id, :string
  field :score_components, :map, default: %{}

  field :retrieval_gap_events, {:array, :map}, virtual: true, default: []
  field :manual_handling_evidence, {:array, :map}, virtual: true, default: []

  has_many :memberships, GapCandidateMembership

  timestamps(type: :utc_datetime_usec)
end
```

**Revision anchor immutability boundary** (`lib/cairnloop/knowledge_base/revision.ex:16-34`)
```elixir
def changeset(revision, attrs) do
  revision
  |> cast(attrs, [:content, :version, :state, :article_id])
  |> validate_required([:content, :version, :state, :article_id])
  |> enforce_immutability()
end

defp enforce_immutability(changeset) do
  if changeset.data.id && changeset.data.state == :published do
    if get_change(changeset, :content) do
      add_error(changeset, :content, "cannot be modified after publication")
    else
      changeset
    end
  else
    changeset
  end
end
```

**Recommended fields for Phase 10**
- Identity: `stable_key`, `suggestion_type`, `status`, `tenant_scope`, `host_user_id`
- Draft artifact: `title`, `operator_summary`, `proposed_markdown`
- Provenance: `entrypoint_type`, `entrypoint_id`, `evidence_snapshot`, `grounding_metadata`
- Revision linkage: `article_id`, `base_revision_id`
- Review state: `dismissed_at`, `generated_at`, `last_error`, `regeneration_count`

**Planner guidance**
- Model this as a separate table from `cairnloop_drafts`; do not overload conversation draft rows.
- Persist full markdown as canonical suggestion truth and compute diff from `base_revision_id` at read time.
- Keep `status` suggestion-safe for Phase 10, closer to `:pending | :ready | :failed | :dismissed` than publish workflow states.

---

### `lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex` or embedded evidence schema (model, transform)

**Primary analogs:** `lib/cairnloop/retrieval/gap_event_snapshot.ex`, `lib/cairnloop/retrieval/result.ex`

**Embedded evidence snapshot schema** (`lib/cairnloop/retrieval/gap_event_snapshot.ex:12-42`)
```elixir
embedded_schema do
  field(:source_type, Ecto.Enum, values: @source_types, default: :unknown)
  field(:trust_level, Ecto.Enum, values: @trust_levels, default: :unknown)
  field(:title, :string)
  field(:content_excerpt, :string)
  field(:citation_target, :map, default: %{})
  field(:match_reasons, {:array, :string}, default: [])
  field(:score, :float)
end
```

**Normalized evidence contract** (`lib/cairnloop/retrieval/result.ex:6-22`)
```elixir
defstruct [
  :id,
  :title,
  :content,
  :source_type,
  :trust_level,
  :visibility,
  :citation_target,
  :article_id,
  :revision_id,
  :conversation_id,
  :chunk_index,
  :updated_at,
  :resolved_at,
  ...
  metadata: %{},
  match_reasons: []
]
```

**Planner guidance**
- Keep suggestion evidence `Result`-shaped so presenter and LiveView seams can reuse existing source/trust wording.
- Prefer an embedded schema over an unbounded opaque map if Phase 10 needs validation on citation anchors.
- Preserve `citation_target`, `trust_level`, and `metadata.destination`; those are already the app’s navigation and trust contract.

---

### `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex` (worker, event-driven)

**Primary analogs:** `lib/cairnloop/automation/workers/draft_worker.ex`, `lib/cairnloop/knowledge_automation/workers/refresh_gap_candidates.ex`

**Oban uniqueness + lightweight `new_job/2` seam** (`lib/cairnloop/automation/workers/draft_worker.ex:1-5`, `lib/cairnloop/knowledge_automation/workers/refresh_gap_candidates.ex:1-8`)
```elixir
use Oban.Worker,
  queue: :default,
  unique: [period: 60, states: [:scheduled]],
  replace: [scheduled: [:scheduled_at]]

def new_job(args \\ %{}, opts \\ []) do
  new(args, opts)
end
```

**Async generation with retrieval, fail-closed capture, and durable write** (`lib/cairnloop/automation/workers/draft_worker.ex:33-68`, `88-112`)
```elixir
grounding_bundle = retrieval.ground_for_draft(draft_context, retrieval_opts)
_ = maybe_record_grounding_gap(grounding_bundle, draft_context)

case Cairnloop.Automation.ScoriaEngine.generate_draft(conversation_id, grounding_bundle) do
  {:ok, proposal} ->
    case proposal.proposal_type do
      :reply -> apply_policy_and_create_draft(conversation_id, proposal)
      :clarification -> handle_create_draft(conversation_id, proposal, :pending)
      :escalation -> handle_create_draft(conversation_id, proposal, :pending)
    end

  _error ->
    :error
end
```

**Telemetry wrapper pattern** (`lib/cairnloop/automation/workers/draft_worker.ex:9-30`)
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
- Key uniqueness to suggestion identity plus evidence digest, not just the source record id.
- Copy the “do work off-request, return `:ok`/`:error`, persist durable artifact, then broadcast” pattern.
- Keep stale-signal or citation-validation failures durable in the suggestion record, not just in logs.

---

### Stale-article evidence and citation contract (service/utility, transform)

**Primary analogs:** `lib/cairnloop/retrieval/providers/resolved_cases.ex`, `lib/cairnloop/retrieval/resolved_case_evidence.ex`, `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`

**Article-linked support evidence with citation backreferences** (`lib/cairnloop/retrieval/resolved_case_evidence.ex:5-18`, `22-47`)
```elixir
schema "cairnloop_resolved_case_evidences" do
  field :subject, :string
  field :issue_summary, :string
  field :resolution_note, :string
  field :actions_taken, {:array, :string}, default: []
  field :outcome, :string
  field :resolved_at, :utc_datetime_usec
  field :host_user_id, :string
  field :metadata, :map, default: %{}
  field :citation_backreferences, {:array, :map}, default: []
end
```

**Resolved-case retrieval preserves backreferences in metadata** (`lib/cairnloop/retrieval/providers/resolved_cases.ex:49-76`)
```elixir
select([chunk, evidence], %{
  source_type: :resolved_case,
  trust_level: :assistive,
  conversation_id: evidence.conversation_id,
  citation_target: %{
    conversation_id: evidence.conversation_id,
    chunk_index: chunk.chunk_index
  },
  metadata: %{
    destination: %{
      type: :resolved_case,
      conversation_id: evidence.conversation_id,
      chunk_index: chunk.chunk_index
    },
    action_label: "Open resolved case",
    citation_backreferences: evidence.citation_backreferences
  }
})
```

**Backreference construction pattern** (`lib/cairnloop/retrieval/workers/index_resolved_conversation.ex:99-114`, `155-163`)
```elixir
%{
  conversation_id: conversation.id,
  subject: conversation.subject || "Conversation ##{conversation.id}",
  issue_summary: summarize_issue(user_messages, conversation.subject),
  resolution_note: summarize_resolution(agent_messages),
  actions_taken: summarize_actions(agent_messages),
  outcome: "resolved",
  resolved_at: conversation.resolved_at || DateTime.utc_now(),
  host_user_id: to_string(conversation.host_user_id || ""),
  metadata: metadata,
  citation_backreferences: citation_backreferences
}

defp build_citation_backreferences(messages) do
  Enum.map(messages || [], fn message ->
    %{
      "message_id" => message.id,
      "role" => message.role,
      "inserted_at" => message.inserted_at
    }
  end)
end
```

**Planner guidance**
- Reuse this “store small backreferences beside assistive evidence” pattern for stale article signals.
- For revision suggestions, require both `base_revision_id` and valid KB `citation_target`s; do not infer revision lineage from title text.
- Keep stale triggers deterministic and inspectable, likely from repeated article-linked failures plus recent evidence rows.

---

### `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` (LiveView, request-response)

**Primary analogs:** `lib/cairnloop/web/conversation_live.ex`, `lib/cairnloop/web/knowledge_base_live/gaps.ex`

**Entry from maintenance queue + selected detail pane** (`lib/cairnloop/web/knowledge_base_live/gaps.ex:6-23`, `62-100`)
```elixir
def mount(_params, session, socket) do
  candidates = knowledge_automation().list_gap_candidates(scope_filters(session))

  {:ok,
   assign(socket,
     candidates: candidates,
     selected_candidate: nil,
     scope_filters: scope_filters(session)
   )}
end

def handle_params(%{"candidate" => candidate_id}, _uri, socket) do
  candidate =
    candidate_id
    |> String.to_integer()
    |> knowledge_automation().get_gap_candidate!(socket.assigns.scope_filters)

  {:noreply, assign(socket, selected_candidate: candidate)}
end
```

**Evidence-adjacent audit rail** (`lib/cairnloop/web/conversation_live.ex:374-449`)
```elixir
<div class="rail-card draft">
  <h3>AI Draft / Audit</h3>
  <p><strong>Proposal state:</strong> <%= @proposal_state_label %></p>
  ...
  <div class="context-field">
    <strong>Supporting evidence</strong>
    <%= if @evidence == [] do %>
      <p>No supporting evidence captured for this proposal.</p>
    <% else %>
      <div>
        <%= for evidence <- @evidence do %>
          <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #e5e7eb;">
            <p>
              <strong><%= SearchResultPresenter.source_label(evidence) %></strong>
              ·
              <strong><%= SearchResultPresenter.trust_label(evidence) %></strong>
            </p>
            <p><strong><%= SearchResultPresenter.title(evidence) %></strong></p>
            <p><%= SearchResultPresenter.row_snippet(evidence) %></p>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

**Grounding/trust copy seam** (`lib/cairnloop/web/conversation_live.ex:505-516`)
```elixir
defp grounding_reason_label(%Draft{} = draft) do
  case draft_grounding_reason(draft) do
    nil -> nil
    reason -> SearchResultPresenter.diagnostic_reason_label(reason)
  end
end

defp grounding_reason_copy(%Draft{} = draft) do
  case draft_grounding_reason(draft) do
    nil -> nil
    reason -> SearchResultPresenter.diagnostic_reason_copy(reason)
  end
end
```

**Planner guidance**
- Build the Phase 10 review surface as an audit-first LiveView: provenance, evidence, trust, proposed markdown/diff, then actions.
- Reuse `patch`/`handle_params` selection flow from `Gaps` for list/detail navigation.
- Keep “Open article” and “Open resolved case” navigation on evidence cards.
- Do not route operators directly into `KnowledgeBaseLive.Editor` before they inspect provenance.

---

### `lib/cairnloop/web/article_suggestion_presenter.ex` (utility, transform)

**Primary analogs:** `lib/cairnloop/web/search_result_presenter.ex`, `lib/cairnloop/web/gap_candidate_presenter.ex`

**Trust/source wording** (`lib/cairnloop/web/search_result_presenter.ex:4-12`, `96-145`)
```elixir
def section_name(%Result{source_type: :knowledge_base}), do: "Knowledge Base"
def section_name(%Result{source_type: :resolved_case}), do: "Similar resolved cases"

def trust_label(%Result{trust_level: :canonical}), do: "Canonical guidance"
def trust_label(%Result{trust_level: :assistive}), do: "Supporting evidence"

def diagnostic_reason_label(:canonical_results), do: "Canonical guidance matched"
def diagnostic_reason_label(:mixed_results), do: "Canonical and supporting evidence matched"
def diagnostic_reason_label(_reason), do: "Grounding needs review"
```

**Queue/detail summary phrasing** (`lib/cairnloop/web/gap_candidate_presenter.ex:31-59`)
```elixir
def freshness_label(%{last_seen_at: %DateTime{} = last_seen_at}) do
  case max(DateTime.diff(DateTime.utc_now(), last_seen_at, :day), 0) do
    0 -> "Seen today"
    1 -> "Seen yesterday"
    days -> "Seen #{days} days ago"
  end
end

def why_raised(candidate) do
  components = Map.get(candidate, :score_components, %{})

  [
    count_phrase(candidate.evidence_count, "signal"),
    count_phrase(candidate.manual_case_count, "manual case"),
    component_phrase("Weak grounding", components["weak_grounding"]),
    component_phrase("No-hit pressure", components["no_hit"])
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.join(" • ")
end
```

**Navigation/action wording** (`lib/cairnloop/web/search_result_presenter.ex:59-80`)
```elixir
def open_action_label(%Result{source_type: :knowledge_base}), do: "Open article"
def open_action_label(%Result{source_type: :resolved_case}), do: "Open resolved case"

def open_path(%Result{source_type: :knowledge_base} = result) do
  case destination(result) do
    %{article_id: article_id} when not is_nil(article_id) ->
      "/knowledge-base/#{article_id}/edit"
    _ ->
      nil
  end
end
```

**Planner guidance**
- Put trust/citation wording in a presenter, not inline inside the LiveView template.
- Reuse current terms: `Canonical guidance`, `Supporting evidence`, `Grounding needs review`.
- Add suggestion-specific copy like base revision labels and diff summaries here, not in the context module.

---

### Handoff into `Cairnloop.KnowledgeBase` and editor (service + LiveView boundary)

**Primary analogs:** `lib/cairnloop/knowledge_base.ex`, `lib/cairnloop/web/knowledge_base_live/editor.ex`

**Draft persistence and version bump** (`lib/cairnloop/knowledge_base.ex:25-48`)
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
```

**Publish remains a later boundary** (`lib/cairnloop/knowledge_base.ex:51-62`)
```elixir
def publish_revision(revision) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
  |> Ecto.Multi.update(:article, fn %{revision: rev} ->
    Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
  end)
  |> Ecto.Multi.insert(:chunk_job, Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id}))
end
```

**Current editor semantics to avoid overloading** (`lib/cairnloop/web/knowledge_base_live/editor.ex:32-52`, `58-80`)
```elixir
def handle_event("save_draft", _, socket) do
  case KnowledgeBase.save_draft(socket.assigns.article, %{content: socket.assigns.content}) do
    {:ok, revision} ->
      {:noreply, assign(socket, revision: revision) |> put_flash(:info, "Draft saved")}
    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to save draft")}
  end
end

def handle_event("publish", _, socket) do
  case KnowledgeBase.save_draft(socket.assigns.article, %{content: socket.assigns.content}) do
    {:ok, revision} ->
      case KnowledgeBase.publish_revision(revision) do
        {:ok, published_rev} ->
          {:noreply, assign(socket, revision: published_rev) |> put_flash(:info, "Published successfully")}
```

**Planner guidance**
- Phase 10 should hand off into this context only after operator chooses manual editing.
- `base_revision_id` should point at a published revision fetched via `get_latest_active_revision/1`, not a draft.
- Keep publish actions out of the new review surface in Phase 10.

## Shared Patterns

### Host-Owned Durable State
**Source:** `lib/cairnloop/knowledge_automation/gap_candidate.ex:12-35`, `lib/cairnloop/automation/draft.ex:5-27`
```elixir
field :status, Ecto.Enum, values: ...
field :grounding_metadata, :map, default: %{}
field :evidence_snapshot, :map, default: %{}
timestamps(type: :utc_datetime_usec)
```
Apply to all Phase 10 persisted suggestion artifacts. Use enums, bounded maps, and explicit timestamps.

### Suggestion Scope Enforcement
**Source:** `lib/cairnloop/knowledge_automation.ex:55-89`
```elixir
query
|> maybe_where_equal(:tenant_scope, Keyword.get(opts, :tenant_scope))
|> maybe_where_equal(:host_user_id, Keyword.get(opts, :host_user_id))
...
raise Ecto.NoResultsError, queryable: GapCandidate
```
Apply to list/detail APIs for suggestion review so host-scoped artifacts cannot be fetched cross-scope.

### Citation Snapshot Validation
**Source:** `lib/cairnloop/retrieval/gap_event_snapshot.ex:22-42`, `lib/cairnloop/retrieval/gap_recorder.ex:158-230`
```elixir
|> validate_change(:citation_target, fn :citation_target, citation_target ->
  if map_size(citation_target || %{}) <= 5 do
    []
  else
    [citation_target: "must contain at most 5 keys"]
  end
end)
```
Apply to embedded suggestion evidence rows so citation anchors stay small, explicit, and serializable.

### Async Generation Boundary
**Source:** `lib/cairnloop/automation/workers/draft_worker.ex:33-68`, `lib/cairnloop/knowledge_automation/workers/refresh_gap_candidates.ex:1-21`
```elixir
grounding_bundle = retrieval.ground_for_draft(...)
case ...generate_draft(...) do
  {:ok, proposal} -> ...
  _error -> :error
end
```
Apply to Phase 10 generation jobs. Perform retrieval, validate grounding, persist durable result, return worker-safe status.

### Evidence-Adjacent Review UI
**Source:** `lib/cairnloop/web/conversation_live.ex:374-449`
```elixir
<strong>Supporting evidence</strong>
...
<strong><%= SearchResultPresenter.source_label(evidence) %></strong>
·
<strong><%= SearchResultPresenter.trust_label(evidence) %></strong>
```
Apply to the suggestion review LiveView. Evidence stays beside editable content or diff, not hidden behind a second screen.

### Trust and Grounding Copy
**Source:** `lib/cairnloop/web/search_result_presenter.ex:96-145`
```elixir
def diagnostic_reason_label(:canonical_results), do: "Canonical guidance matched"
def diagnostic_reason_copy(:mixed_results) do
  "Canonical Knowledge Base guidance matched, with supporting resolved-case context alongside it."
end
```
Apply to review-surface wording and fail-closed states.

## Test Organization Patterns

### Context and schema unit tests
**Sources:** `test/cairnloop/knowledge_automation/gap_candidate_test.exs:52-178`, `test/cairnloop/knowledge_base_test.exs:72-109`
- Use `ExUnit.Case` with repo swapping through `Application.put_env/3`.
- Assert changeset acceptance and rejection directly.
- Test list ordering, scope enforcement, and public seam existence.
- For revision handoff, assert version bump and transactional job enqueue.

### Worker tests
**Source:** `test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs:45-132`
- Keep worker tests thin: verify delegation, idempotence, and secondary scheduling.
- Prefer injectable `persist_fn`, `schedule_*_fn`, and `now_fn` seams over starting Oban.

### LiveView render tests
**Sources:** `test/cairnloop/web/knowledge_base_live/gaps_test.exs:47-137`, `test/cairnloop/web/conversation_live_test.exs:312-410`
- Render via `mount/3` or direct assigns, then assert on HTML strings.
- Cover calm empty states, evidence grouping, trust labels, and inline action visibility.
- For the suggestion review screen, mirror these tests for both create and revision suggestions.

## Anti-Patterns To Avoid

- Do not reuse `Cairnloop.Automation.Draft` for KB maintenance suggestions. That schema is conversation-owned and keyed to reply workflows, not article lifecycle.
- Do not make `KnowledgeBaseLive.Editor` the first stop for AI suggestions. Its semantics are direct authoring plus publish, which Phase 10 explicitly avoids.
- Do not persist AI-authored diffs as canonical truth. Current KB revision flow treats full markdown content as the durable unit.
- Do not inline citations into markdown by default. Existing review patterns keep evidence adjacent and navigable through `citation_target` and presenter labels.
- Do not trigger revision suggestions from age alone. Current evidence patterns are based on bounded, inspectable signals.
- Do not store unbounded raw retrieval payloads in suggestion rows. Existing contracts truncate excerpts, cap map keys, and dedupe snapshots.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/cairnloop/knowledge_automation/stale_article_signal.ex` or equivalent stale-trigger projection | model/utility | transform | No current module aggregates repeated article-linked failures into a durable stale signal; planner should compose this from `ResolvedCaseEvidence`, retrieval diagnostics, and suggestion context patterns rather than copying a direct analog. |

## Recommended Phase 10 Module Set

- Add `lib/cairnloop/knowledge_automation/article_suggestion.ex` as the durable host-owned artifact.
- Add `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex` as the async generation boundary with uniqueness keyed by entrypoint identity plus evidence digest.
- Extend `lib/cairnloop/knowledge_automation.ex` with suggestion list/detail/create/regenerate/dismiss seams and explicit scope filtering.
- Add `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` as the dedicated review surface, launched from gaps and stale-article entrypoints.
- Add `lib/cairnloop/web/article_suggestion_presenter.ex` for trust, citation, diff-summary, and stale-reason wording.
- Add unit tests beside current knowledge automation tests and LiveView tests beside current gaps/conversation tests; keep the same mock-env style.

## Metadata

**Analog search scope:** `lib/cairnloop/**`, `test/cairnloop/**`, `priv/repo/migrations/**`, nearby milestone pattern docs
**Files scanned:** 22
**Pattern extraction date:** 2026-05-21
