# Phase 33: Security Domain Closure - Pattern Map

**Mapped:** 2024-05-29
**Files analyzed:** 2
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/cairnloop/knowledge_automation.ex` | service/domain | request-response | `lib/cairnloop/knowledge_automation.ex` | exact (self) |
| `test/cairnloop/knowledge_automation_test.exs` | test | request-response | `test/cairnloop/knowledge_automation_test.exs` | exact (self) |

## Pattern Assignments

### `lib/cairnloop/knowledge_automation.ex` (service/domain, request-response)

**Analog:** `lib/cairnloop/knowledge_automation.ex`

**Imports pattern** (lines 1-17):
```elixir
defmodule Cairnloop.KnowledgeAutomation do
  import Ecto.Query

  alias Cairnloop.KnowledgeAutomation.{
    ArticleSuggestion,
    ArticleSuggestionEvidence,
    CandidateBuilder,
    GapCandidate,
    Telemetry,
    ReviewTask,
    ReviewTaskEvent,
    StaleArticleSignal,
    Workers.BackfillGapCandidates,
    Workers.GenerateArticleSuggestion,
    Workers.RefreshGapCandidates
  }
```

**Authoring Article Reuse Pattern** (lines 576-589, `create_or_reuse_authoring_article_for_suggestion/2`):
```elixir
  def create_or_reuse_authoring_article_for_suggestion(id, opts \\ []) do
    suggestion = get_article_suggestion!(id, opts)
    kb_module = knowledge_base_module(opts)

    existing_authoring_article_id =
      suggestion.grounding_metadata
      |> map_value(:authoring_article_id)

    cond do
      suggestion.suggestion_type == :revision and suggestion.article_id ->
        {:ok, suggestion.article_id}

      reusable_authoring_article?(kb_module.get_article(existing_authoring_article_id)) ->
        {:ok, existing_authoring_article_id}
```
Helper `reusable_authoring_article?` (lines 1612-1615):
```elixir
  defp reusable_authoring_article?(nil), do: false

  defp reusable_authoring_article?(article) do
    map_value(article, :status) not in [:published, "published"]
  end
```

**Gap Candidate Hydration Pattern** (lines 1414-1442, `hydrate_gap_candidate_request/2`):
```elixir
  defp hydrate_gap_candidate_request(attrs, opts) do
    candidate_id = entrypoint_id_for(:article, attrs)

    cond do
      is_nil(candidate_id) ->
        {attrs, opts}

      true ->
        scope_opts = scope_opts_from_attrs(attrs)
        candidate = get_gap_candidate!(candidate_id, scope_opts)
        query = gap_candidate_query(candidate)
        grounding_bundle = gap_candidate_grounding_bundle(candidate, query, opts)
```

**Revision Gate Hydration Pattern** (lines 1519-1526, `build_revision_gate_inputs/3`):
```elixir
  defp build_revision_gate_inputs(revision, attrs, opts) do
    gap_events = article_linked_gap_events(revision.article_id, revision.id, attrs)

    grounding_bundle =
      fresh_revision_grounding_bundle(revision.article_id, revision.id, attrs, opts)

    {gap_events, grounding_bundle}
  end
```

**Fresh Revision Grounding Pattern** (lines 1551-1562, `fresh_revision_grounding_bundle/4`):
```elixir
  defp fresh_revision_grounding_bundle(article_id, base_revision_id, attrs, opts) do
    host_user_id = anchor_id(attrs, :host_user_id)
    query = revision_grounding_query(article_id, attrs, opts)

    retrieval_module(opts).ground_for_draft(
      %{query: query, host_user_id: host_user_id, clarification_attempts: 0},
      surface: :draft_generation,
      host_user_id: host_user_id
    )
    |> Map.put(:query, query)
    |> Map.put(:diagnostic, %{article_id: article_id, base_revision_id: base_revision_id})
  end
```

---

### `test/cairnloop/knowledge_automation_test.exs` (test, request-response)

**Analog:** `test/cairnloop/knowledge_automation_test.exs`

**Testing Setup / Mock Pattern** (lines 1-27):
```elixir
defmodule Cairnloop.KnowledgeAutomationTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, GapCandidate}

  defmodule MockRepo do
    def one!(%Ecto.Query{}) do
      case Process.get(:gap_lookup) do
        :raise -> raise Ecto.NoResultsError, queryable: GapCandidate
        record -> record
      end
    end
    # ...
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)
```

## Shared Patterns

### Error Handling
**Source:** `lib/cairnloop/knowledge_automation.ex`
**Apply to:** Core logic where state blocks operations
```elixir
        {:error, {:stale_gate_blocked, stale_signal}}
```
```elixir
      latest_revision ->
        {:error, {:stale_base, latest_revision}}
```

## No Analog Found

None. Existing files serve as their own analogs for targeted modifications.

## Metadata

**Analog search scope:** `lib/cairnloop/knowledge_automation.ex`, `test/cairnloop/knowledge_automation_test.exs`
**Files scanned:** 2
**Pattern extraction date:** 2024-05-29
