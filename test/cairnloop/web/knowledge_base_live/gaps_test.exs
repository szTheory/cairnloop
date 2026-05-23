defmodule Cairnloop.Web.KnowledgeBaseLive.GapsTest do
  use ExUnit.Case, async: false
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, GapCandidate, GapCandidateMembership}
  alias Cairnloop.KnowledgeBase.{Article, Revision}
  alias Cairnloop.Retrieval.{GapEvent, ResolvedCaseEvidence}
  alias Cairnloop.Web.KnowledgeBaseLive.{Gaps, Index}

  defmodule MockKnowledgeAutomation do
    def list_gap_candidates(_opts) do
      Process.get(:mock_gap_candidates, [])
    end

    def get_gap_candidate!(id, _opts) do
      Process.get(:mock_gap_candidate_detail).(id)
    end

    def suggest_article(attrs) do
      Process.put(:suggest_article_attrs, attrs)
      {:ok, %{id: 88}}
    end

    def suggest_revision(attrs) do
      Process.put(:suggest_revision_attrs, attrs)
      {:ok, %{id: 99}}
    end

    def ensure_review_task_for_suggestion(id, _opts \\ []) do
      {:ok, %{id: id + 1000}}
    end
  end

  defmodule MockRetrieval do
    def ground_for_draft(request, opts) do
      Process.put(:live_last_retrieval_request, request)
      Process.put(:live_last_retrieval_opts, opts)

      query = Map.get(request, :query) || Map.get(request, "query")

      Process.get(:live_retrieval_ground_for_draft, fn _query, _request, _opts ->
        %{
          query: query,
          canonical_results: [],
          assistive_results: [],
          evidence: [],
          grounding_assessment: %{status: :weak}
        }
      end).(query, request, opts)
    end
  end

  defmodule MockKnowledgeBase do
    def get_latest_active_revision(article_id) do
      Process.get(:index_latest_active_revision_fn, fn _article_id -> nil end).(article_id)
    end

    def get_article(article_id) do
      Process.get(:index_article_lookup_fn, fn _article_id -> nil end).(article_id)
    end
  end

  defmodule MockRepo do
    def all(Article), do: Process.get(:index_articles, [])

    def all(%Ecto.Query{} = query) do
      Process.put(:live_last_all_query, query)

      case query_source(query) do
        GapEvent ->
          Process.get(:live_gap_events, [])
          |> filter(query)
          |> Enum.sort_by(fn event -> {Map.get(event, :occurred_at), Map.get(event, :id, 0)} end, :desc)

        ResolvedCaseEvidence ->
          Process.get(:live_resolved_case_evidence, [])
          |> filter(query)
          |> Enum.sort_by(fn evidence -> {Map.get(evidence, :resolved_at), Map.get(evidence, :id, 0)} end, :desc)

        ArticleSuggestion ->
          Process.get(:live_article_suggestions, [])
          |> filter(query)
          |> Enum.sort_by(
            fn suggestion ->
              {suggestion.inserted_at || ~U[1970-01-01 00:00:00Z], suggestion.id || 0}
            end,
            :desc
          )

        _ ->
          []
      end
    end

    def one!(%Ecto.Query{} = query) do
      Process.put(:live_last_one_query, query)

      case query_source(query) do
        GapCandidate ->
          Process.get(:live_gap_candidate_lookup).(query)

        ArticleSuggestion ->
          Process.get(:live_last_inserted_suggestion)

        _ ->
          raise Ecto.NoResultsError, queryable: "mock query"
      end
    end

    def one(%Ecto.Query{} = query) do
      Process.put(:live_last_one_query, query)

      case query_source(query) do
        Revision ->
          Process.get(:index_revision_lookup_fn, fn _query -> nil end).(query)

        _ ->
          nil
      end
    end

    def insert(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        struct =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> maybe_put_id()
          |> Map.put_new(:inserted_at, DateTime.utc_now())
          |> Map.put_new(:updated_at, DateTime.utc_now())

        Process.put(:live_last_inserted, struct)
        store_inserted(struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def preload(record, _fields), do: record

    defp store_inserted(%ArticleSuggestion{} = suggestion) do
      Process.put(:live_last_inserted_suggestion, suggestion)
      Process.put(:live_article_suggestions, [suggestion | Process.get(:live_article_suggestions, [])])
    end

    defp store_inserted(%KnowledgeAutomation.ReviewTask{} = task) do
      Process.put(:live_last_inserted_review_task, task)
    end

    defp store_inserted(%KnowledgeAutomation.ReviewTaskEvent{} = event) do
      Process.put(:live_last_inserted_review_task_event, event)
    end

    defp store_inserted(_struct), do: :ok

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    defp query_source(%Ecto.Query{from: %{source: {_table, module}}}), do: module

    defp filter(records, query) do
      Enum.filter(records, fn record ->
        Enum.all?(List.wrap(query.wheres), fn %{expr: expr, params: params} ->
          match_where?(record, expr, params)
        end)
      end)
    end

    defp match_where?(
           record,
           {:==, [], [{{:., [], [{:&, [], [0]}, field]}, [], []}, {:^, [], [index]}]},
           params
         ) do
      {value, _} = Enum.at(params, index)
      Map.get(record, field) == value
    end

    defp match_where?(
           record,
           {:in, [], [{{:., [], [{:&, [], [0]}, field]}, [], []}, {:^, [], [index]}]},
           params
         ) do
      {values, _} = Enum.at(params, index)
      Map.get(record, field) in values
    end

    defp match_where?(_record, _expr, _params), do: true
  end

  setup do
    Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Process.delete(:mock_gap_candidates)
      Process.delete(:mock_gap_candidate_detail)
      Process.delete(:suggest_article_attrs)
      Process.delete(:suggest_revision_attrs)
      Process.delete(:live_last_retrieval_request)
      Process.delete(:live_last_retrieval_opts)
      Process.delete(:live_retrieval_ground_for_draft)
      Process.delete(:live_gap_candidate_lookup)
      Process.delete(:live_gap_events)
      Process.delete(:live_resolved_case_evidence)
      Process.delete(:live_article_suggestions)
      Process.delete(:live_last_inserted)
      Process.delete(:live_last_inserted_suggestion)
      Process.delete(:live_last_inserted_review_task)
      Process.delete(:live_last_inserted_review_task_event)
      Process.delete(:live_last_all_query)
      Process.delete(:live_last_one_query)
      Process.delete(:index_articles)
      Process.delete(:index_latest_active_revision_fn)
      Process.delete(:index_article_lookup_fn)
      Process.delete(:index_revision_lookup_fn)
      Application.delete_env(:cairnloop, :knowledge_automation)
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :retrieval_module)
    end)

    :ok
  end

  test "operators can navigate to /knowledge-base/gaps from the dashboard shell" do
    {:ok, socket} = Index.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    html =
      socket.assigns
      |> Index.render()
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    assert html =~ "/knowledge-base/gaps"
    assert html =~ "Review KB gap candidates"
  end

  test "page renders ranked candidates with title, reasons, counts, and freshness labels" do
    Process.put(:mock_gap_candidates, [
      %GapCandidate{
        id: 5,
        title: "Billing Export",
        candidate_type: :mixed,
        evidence_count: 4,
        manual_case_count: 2,
        weak_grounding_count: 1,
        no_hit_count: 1,
        last_seen_at: ~U[2026-05-21 09:00:00Z],
        score_components: %{"weak_grounding" => 1.4}
      }
    ])

    {:ok, socket} = Gaps.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    html = render_html(socket.assigns)

    assert html =~ "Billing Export"
    assert html =~ "Mixed evidence"
    assert html =~ "4 signals"
    assert html =~ "2 manual cases"
    assert html =~ "Seen"
  end

  test "empty state stays calm when there are no candidates" do
    Process.put(:mock_gap_candidates, [])

    {:ok, socket} = Gaps.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    html = render_html(socket.assigns)

    assert html =~ "No gap candidates yet."
    assert html =~ "this queue will show it here"
  end

  test "selecting a candidate shows grouped retrieval and manual-handling evidence plus why-raised copy" do
    Process.put(:mock_gap_candidates, [
      %GapCandidate{
        id: 5,
        title: "Billing Export",
        candidate_type: :mixed,
        evidence_count: 4,
        manual_case_count: 2,
        weak_grounding_count: 1,
        no_hit_count: 1,
        last_seen_at: ~U[2026-05-21 09:00:00Z]
      }
    ])

    Process.put(:mock_gap_candidate_detail, fn 5 ->
      %GapCandidate{
        id: 5,
        title: "Billing Export",
        candidate_type: :mixed,
        evidence_count: 4,
        manual_case_count: 2,
        weak_grounding_count: 1,
        no_hit_count: 1,
        last_seen_at: ~U[2026-05-21 09:00:00Z],
        score_components: %{"weak_grounding" => 1.4, "no_hit" => 1.0},
        retrieval_gap_events: [
          %{
            id: 10,
            surface: :conversation,
            reason: :assistive_only_results,
            canonical_hit_count: 0,
            assistive_hit_count: 2,
            sanitized_query_excerpt: "billing export missing"
          }
        ],
        manual_handling_evidence: [
          %{
            id: 99,
            conversation_id: 123,
            issue_summary: "Billing export missing",
            resolution_note: "Agent rebuilt the export.",
            actions_taken: ["rebuilt export"]
          }
        ]
      }
    end)

    {:ok, socket} = Gaps.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    {:noreply, socket} = Gaps.handle_params(%{"candidate" => "5"}, "", socket)
    html = render_html(socket.assigns)

    assert html =~ "Weak grounding"
    assert html =~ "billing export missing"
    assert html =~ "Agent rebuilt the export."
    assert html =~ "Open conversation"
    assert html =~ "Generate article suggestion"
  end

  test "selected gap candidates queue article suggestion generation with candidate-scoped evidence" do
    Application.put_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
    Application.put_env(:cairnloop, :retrieval_module, MockRetrieval)

    Process.put(:mock_gap_candidates, [%GapCandidate{id: 5, title: "Billing Export"}])

    Process.put(:live_gap_candidate_lookup, fn _query ->
      %GapCandidate{
        id: 5,
        stable_key: "gap:tenant:user-1:5",
        status: :open,
        candidate_type: :mixed,
        title: "Billing Export",
        seed_excerpt: "Billing export missing from KB",
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        first_seen_at: ~U[2026-05-20 09:00:00Z],
        last_seen_at: ~U[2026-05-21 09:00:00Z],
        evidence_count: 2,
        manual_case_count: 1,
        weak_grounding_count: 1,
        no_hit_count: 0,
        score: 4.2,
        score_components: %{"weak_grounding" => 1.3},
        memberships: [
          %GapCandidateMembership{source_type: :retrieval_gap_event, source_id: 10},
          %GapCandidateMembership{source_type: :manual_handling_case, source_id: 99}
        ]
      }
    end)

    Process.put(:live_gap_events, [
      %GapEvent{
        id: 10,
        occurred_at: ~U[2026-05-21 08:00:00Z],
        surface: :draft_generation,
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        query_fingerprint: String.duplicate("c", 64),
        sanitized_query_excerpt: "billing export missing from knowledge base",
        canonical_hit_count: 0,
        assistive_hit_count: 2,
        clarification_attempts: 1
      }
    ])

    Process.put(:live_resolved_case_evidence, [
      %ResolvedCaseEvidence{
        id: 99,
        conversation_id: 123,
        subject: "Billing export issue",
        issue_summary: "Customers cannot find the export article.",
        resolution_note: "Agent walked through the export manually.",
        actions_taken: ["shared export steps"],
        outcome: "resolved",
        resolved_at: ~U[2026-05-21 07:30:00Z]
      }
    ])

    Process.put(:live_retrieval_ground_for_draft, fn
      "billing export missing from knowledge base", request, _opts ->
        %{
          query: request.query,
          canonical_results: [
            %{
              source_type: :knowledge_base,
              trust_level: :canonical,
              title: "Billing export reference",
              content: "Open Settings and choose Export.",
              citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
            }
          ],
          assistive_results: [
            %{
              source_type: :resolved_case,
              trust_level: :assistive,
              title: "Billing export issue",
              content: "Agent walked through the export manually."
            }
          ],
          evidence: [],
          grounding_assessment: %{status: :strong}
        }

      _query, request, _opts ->
        %{
          query: request.query,
          canonical_results: [],
          assistive_results: [],
          evidence: [],
          grounding_assessment: %{status: :weak}
        }
    end)

    {:ok, socket} = Gaps.mount(%{}, %{"host_user_id" => "user-1"}, %Phoenix.LiveView.Socket{})
    {:noreply, socket} = Gaps.handle_params(%{"candidate" => "5"}, "", socket)
    {:noreply, socket} = Gaps.handle_event("suggest_article", %{"candidate_id" => "5"}, socket)

    suggestion = Process.get(:live_last_inserted_suggestion)

    assert Process.get(:live_last_retrieval_request).query ==
             "billing export missing from knowledge base"

    assert suggestion.entrypoint_id == 5
    assert suggestion.grounding_metadata["query"] == "billing export missing from knowledge base"
    assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=" <> _task_id}} = socket.redirected
  end

  test "knowledge base index queues revision suggestions from domain-loaded stale evidence" do
    Application.put_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
    Application.put_env(:cairnloop, :retrieval_module, MockRetrieval)

    Process.put(:index_articles, [%Article{id: 77, title: "Billing Export", status: :published}])
    Process.put(:index_article_lookup_fn, fn 77 -> %Article{id: 77, title: "Billing Export", status: :published} end)
    Process.put(:index_latest_active_revision_fn, fn 77 -> %Revision{id: 44, article_id: 77, state: :published, version: 3} end)

    Process.put(:live_gap_events, [
      %GapEvent{
        id: 301,
        occurred_at: ~U[2026-05-21 10:00:00Z],
        surface: :draft_generation,
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        query_fingerprint: String.duplicate("d", 64),
        sanitized_query_excerpt: "billing export edge case",
        canonical_hit_count: 0,
        assistive_hit_count: 1,
        clarification_attempts: 1,
        attempted_evidence_snapshots: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            citation_target: %{article_id: 77, revision_id: 44, chunk_index: 1}
          }
        ]
      },
      %GapEvent{
        id: 302,
        occurred_at: ~U[2026-05-22 10:00:00Z],
        surface: :draft_generation,
        outcome_class: :policy_limit,
        reason: :clarification_limit_reached,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        query_fingerprint: String.duplicate("e", 64),
        sanitized_query_excerpt: "billing export limits",
        canonical_hit_count: 0,
        assistive_hit_count: 1,
        clarification_attempts: 1,
        attempted_evidence_snapshots: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            citation_target: %{article_id: 77, revision_id: 44, chunk_index: 2}
          }
        ]
      }
    ])

    Process.put(:live_retrieval_ground_for_draft, fn
      "Billing Export", request, _opts ->
        %{
          query: request.query,
          canonical_results: [
            %{
              source_type: :knowledge_base,
              trust_level: :canonical,
              title: "Billing export reference",
              content: "Canonical chunk",
              citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
            }
          ],
          assistive_results: [],
          evidence: [],
          grounding_assessment: %{status: :strong}
        }
    end)

    {:ok, mounted_socket} = Index.mount(%{}, %{"host_user_id" => "user-1"}, %Phoenix.LiveView.Socket{})
    socket = %{mounted_socket | assigns: Map.put(mounted_socket.assigns, :flash, %{})}
    {:noreply, socket} = Index.handle_event("suggest_revision", %{"article_id" => "77"}, socket)

    suggestion = Process.get(:live_last_inserted_suggestion)

    assert suggestion.base_revision_id == 44
    assert suggestion.grounding_metadata["canonical_evidence_count"] == 1
    assert suggestion.grounding_metadata["stale_signal"]["signal_count"] == 2
    assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=" <> _task_id}} = socket.redirected
  end

  defp render_html(assigns) do
    assigns
    |> Gaps.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
