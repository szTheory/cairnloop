defmodule Cairnloop.KnowledgeAutomation.ArticleSuggestionTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation

  alias Cairnloop.KnowledgeAutomation.{
    ArticleSuggestion,
    ArticleSuggestionEvidence,
    GapCandidate,
    GapCandidateMembership,
    StaleArticleSignal
  }

  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.Retrieval.{GapEvent, ResolvedCaseEvidence}

  defmodule MockRetrieval do
    def ground_for_draft(request, opts) do
      Process.put(:last_retrieval_request, request)
      Process.put(:last_retrieval_opts, opts)

      query = Map.get(request, :query) || Map.get(request, "query")

      Process.get(:retrieval_ground_for_draft, fn _query, _request, _opts ->
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
      Process.get(:latest_active_revision_fn, fn _article_id -> nil end).(article_id)
    end

    def get_article(article_id) do
      Process.get(:knowledge_base_article_fn, fn _article_id -> nil end).(article_id)
    end

    def create_article(attrs) do
      Process.put(:created_article_attrs, attrs)

      {:ok,
       %Cairnloop.KnowledgeBase.Article{
         id: 700 + System.unique_integer([:positive]),
         title: attrs.title,
         status: attrs.status
       }}
    end
  end

  defmodule MockRepo do
    def all(Cairnloop.KnowledgeBase.Article) do
      Process.get(:articles, [])
    end

    def all(module) when is_atom(module) do
      case module do
        _ -> []
      end
    end

    def all(%Ecto.Query{} = query) do
      Process.put(:last_all_query, query)

      query
      |> query_source()
      |> all_for_source(query)
    end

    def all(queryable, _opts), do: all(queryable)

    def one!(%Ecto.Query{} = query) do
      Process.put(:last_one_query, query)

      query
      |> query_source()
      |> one_for_source(query, true)
    end

    def one!(query, _opts), do: one!(query)

    def one(%Ecto.Query{} = query) do
      Process.put(:last_one_query, query)

      query
      |> query_source()
      |> one_for_source(query, false)
    end

    def one(query, _opts), do: one(query)

    def insert(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        suggestion =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> maybe_put_id()
          |> Map.put_new(:inserted_at, DateTime.utc_now())
          |> Map.put_new(:updated_at, DateTime.utc_now())

        Process.put(:last_inserted_suggestion, suggestion)
        Process.put(:article_suggestions, [suggestion | Process.get(:article_suggestions, [])])
        {:ok, suggestion}
      else
        {:error, changeset}
      end
    end

    def insert(changeset, _opts), do: insert(changeset)

    def update(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        suggestion =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:updated_at, DateTime.utc_now())

        Process.put(:last_updated_suggestion, suggestion)
        {:ok, suggestion}
      else
        {:error, changeset}
      end
    end

    def update(changeset, _opts), do: update(changeset)

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    defp query_source(%Ecto.Query{from: %{source: {_table, module}}}), do: module
    defp query_source(_), do: nil

    defp all_for_source(ArticleSuggestion, query) do
      Process.get(:article_suggestions, [])
      |> filter_scope(query)
      |> Enum.sort_by(
        fn suggestion ->
          {suggestion.inserted_at || ~U[1970-01-01 00:00:00Z], suggestion.id || 0}
        end,
        :desc
      )
    end

    defp all_for_source(GapEvent, query) do
      Process.get(:gap_events, [])
      |> filter_scope(query)
      |> Enum.sort_by(
        fn event -> {Map.get(event, :occurred_at), Map.get(event, :id, 0)} end,
        :desc
      )
    end

    defp all_for_source(ResolvedCaseEvidence, query) do
      Process.get(:resolved_case_evidence, [])
      |> filter_scope(query)
      |> Enum.sort_by(
        fn evidence -> {Map.get(evidence, :resolved_at), Map.get(evidence, :id, 0)} end,
        :desc
      )
    end

    defp all_for_source(_module, _query), do: []

    defp one_for_source(ArticleSuggestion, query, true) do
      Process.get(:article_suggestion_detail_lookup).(query)
    end

    defp one_for_source(ArticleSuggestion, query, false) do
      Process.get(:article_suggestion_detail_lookup, fn _query -> nil end).(query)
    end

    defp one_for_source(GapCandidate, query, true) do
      Process.get(:gap_candidate_lookup).(query)
    end

    defp one_for_source(GapCandidate, query, false) do
      Process.get(:gap_candidate_lookup, fn _query -> nil end).(query)
    end

    defp one_for_source(Revision, query, false) do
      Process.get(:revision_lookup, fn _query -> nil end).(query)
    end

    defp one_for_source(_module, _query, true) do
      raise Ecto.NoResultsError, queryable: "mock query"
    end

    defp one_for_source(_module, _query, false), do: nil

    defp filter_scope(suggestions, query) do
      conditions = List.wrap(query.wheres)

      Enum.filter(suggestions, fn suggestion ->
        Enum.all?(conditions, fn %{expr: expr, params: params} ->
          eval_condition(suggestion, expr, params)
        end)
      end)
    end

    defp eval_condition(
           record,
           {:==, [], [{{:., [], [{:&, [], [0]}, field]}, [], []}, {:^, [], [index]}]},
           params
         ) do
      {value, _} = Enum.at(params, index)
      Map.get(record, field) == value
    end

    defp eval_condition(
           record,
           {:in, [], [{{:., [], [{:&, [], [0]}, field]}, [], []}, {:^, [], [index]}]},
           params
         ) do
      {values, _} = Enum.at(params, index)
      Map.get(record, field) in values
    end

    defp eval_condition(_record, _expr, _params), do: true
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      [
        :article_suggestions,
        :article_suggestion_detail_lookup,
        :last_all_query,
        :last_one_query,
        :last_inserted_suggestion,
        :last_updated_suggestion,
        :last_retrieval_request,
        :last_retrieval_opts,
        :retrieval_ground_for_draft,
        :gap_candidate_lookup,
        :gap_events,
        :resolved_case_evidence,
        :latest_active_revision_fn,
        :knowledge_base_article_fn,
        :revision_lookup,
        :created_article_attrs,
        :authoring_target_suggestion
      ]
      |> Enum.each(&Process.delete/1)

      if original_repo do
        Application.put_env(:cairnloop, :repo, original_repo)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)

    :ok
  end

  test "article suggestion changeset accepts shared identity fields and rejects missing required durable fields" do
    changeset = ArticleSuggestion.changeset(%ArticleSuggestion{}, valid_article_attrs())

    assert changeset.valid?

    invalid =
      ArticleSuggestion.changeset(%ArticleSuggestion{}, %{
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1"
      })

    refute invalid.valid?
    assert "can't be blank" in errors_on(invalid).stable_key
    assert "can't be blank" in errors_on(invalid).suggestion_type
    assert "can't be blank" in errors_on(invalid).entrypoint_type
    assert "can't be blank" in errors_on(invalid).proposed_markdown
    assert "can't be blank" in errors_on(invalid).grounding_metadata
  end

  test "revision suggestions require article and revision anchors while gap-driven article suggestions reject them" do
    revision_missing_anchor =
      %ArticleSuggestion{}
      |> ArticleSuggestion.changeset(
        valid_revision_attrs(%{article_id: nil, base_revision_id: nil})
      )

    refute revision_missing_anchor.valid?

    assert "must be present for revision suggestions" in errors_on(revision_missing_anchor).article_id

    assert "must be present for revision suggestions" in errors_on(revision_missing_anchor).base_revision_id

    gap_with_anchor =
      %ArticleSuggestion{}
      |> ArticleSuggestion.changeset(valid_article_attrs(%{article_id: 12, base_revision_id: 44}))

    refute gap_with_anchor.valid?

    assert "must be blank for gap-driven article suggestions" in errors_on(gap_with_anchor).article_id

    assert "must be blank for gap-driven article suggestions" in errors_on(gap_with_anchor).base_revision_id
  end

  test "embedded evidence preserves retrieval-shaped fields and rejects malformed citation anchors" do
    changeset =
      ArticleSuggestionEvidence.changeset(%ArticleSuggestionEvidence{}, valid_evidence_attrs())

    assert changeset.valid?
    evidence = Ecto.Changeset.apply_changes(changeset)
    assert evidence.source_type == :knowledge_base
    assert evidence.trust_level == :canonical
    assert evidence.title == "Billing export reference"
    assert evidence.excerpt == "Use the export endpoint with a date range."
    assert evidence.citation_target == %{article_id: 7, revision_id: 11, chunk_index: 2}
    assert evidence.metadata.destination == %{article_id: 7, revision_id: 11}

    missing_anchor =
      ArticleSuggestionEvidence.changeset(%ArticleSuggestionEvidence{}, %{
        source_type: :knowledge_base,
        trust_level: :canonical,
        title: "Billing export reference",
        excerpt: "Use the export endpoint with a date range.",
        citation_target: %{article_id: 7},
        metadata: %{destination: %{article_id: 7}}
      })

    refute missing_anchor.valid?

    assert "must include article_id, revision_id, and chunk_index" in errors_on(missing_anchor).citation_target

    oversize_anchor =
      ArticleSuggestionEvidence.changeset(%ArticleSuggestionEvidence{}, %{
        source_type: :knowledge_base,
        trust_level: :canonical,
        title: "Billing export reference",
        excerpt: "Use the export endpoint with a date range.",
        citation_target: %{
          article_id: 7,
          revision_id: 11,
          chunk_index: 2,
          slug: "billing-export",
          section: "exports",
          extra: "too-much"
        },
        metadata: %{
          destination: %{
            article_id: 7,
            revision_id: 11,
            tab: "knowledge",
            mode: "preview",
            extra: "too-much"
          }
        }
      })

    refute oversize_anchor.valid?
    assert "must contain at most 5 keys" in errors_on(oversize_anchor).citation_target
    assert "must contain at most 4 keys" in errors_on(oversize_anchor).metadata
  end

  test "migration creates durable suggestion indexes for lookup and anchor reuse" do
    [migration] = Path.wildcard("priv/repo/migrations/*_add_article_suggestions.exs")
    content = File.read!(migration)

    assert content =~ "create table(:cairnloop_article_suggestions, prefix: prefix)"

    assert content =~
             "unique_index(:cairnloop_article_suggestions, [:stable_key], prefix: prefix)"

    assert content =~ "index(:cairnloop_article_suggestions, [:status], prefix: prefix)"

    assert content =~
             "index(:cairnloop_article_suggestions, [:entrypoint_type, :entrypoint_id], prefix: prefix)"

    assert content =~ "index(:cairnloop_article_suggestions, [:evidence_digest], prefix: prefix)"
    assert content =~ "index(:cairnloop_article_suggestions, [:base_revision_id], prefix: prefix)"
  end

  test "list_article_suggestions scopes by tenant and host, filters status, and orders deterministically" do
    Process.put(:article_suggestions, [
      suggestion_fixture(%{
        id: 1,
        stable_key: "public-1",
        tenant_scope: :public_only,
        host_user_id: nil,
        status: :ready,
        inserted_at: ~U[2026-05-20 10:00:00Z]
      }),
      suggestion_fixture(%{
        id: 2,
        stable_key: "host-older",
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        status: :ready,
        inserted_at: ~U[2026-05-20 09:00:00Z]
      }),
      suggestion_fixture(%{
        id: 3,
        stable_key: "host-newest",
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        status: :ready,
        inserted_at: ~U[2026-05-21 09:00:00Z]
      }),
      suggestion_fixture(%{
        id: 4,
        stable_key: "host-dismissed",
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        status: :dismissed,
        inserted_at: ~U[2026-05-22 09:00:00Z]
      })
    ])

    suggestions =
      KnowledgeAutomation.list_article_suggestions(
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        status: :ready
      )

    assert Enum.map(suggestions, & &1.id) == [3, 2]

    query_text = inspect(Process.get(:last_all_query))
    assert query_text =~ "tenant_scope"
    assert query_text =~ "host_user_id"
    assert query_text =~ "status"
    assert query_text =~ "inserted_at"
  end

  test "get_article_suggestion! hydrates evidence and rejects cross-scope fetches" do
    suggestion =
      suggestion_fixture(%{
        id: 8,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        evidence_snapshot: [
          struct(ArticleSuggestionEvidence, valid_evidence_attrs())
        ]
      })

    Process.put(:article_suggestion_detail_lookup, fn _query -> suggestion end)

    loaded = KnowledgeAutomation.get_article_suggestion!(8, host_user_id: "user-1")
    assert length(loaded.evidence_snapshot) == 1
    assert hd(loaded.evidence_snapshot).citation_target.revision_id == 11

    assert_raise Ecto.NoResultsError, fn ->
      KnowledgeAutomation.get_article_suggestion!(8, host_user_id: "other-user")
    end
  end

  test "suggest_article and suggest_revision persist pending suggestions and revision generation uses current published anchor" do
    Process.put(:gap_candidate_lookup, fn _query ->
      gap_candidate_fixture()
    end)

    Process.put(:gap_events, [
      %GapEvent{
        id: 12,
        occurred_at: ~U[2026-06-21 10:00:00Z],
        surface: :draft_generation,
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        query_fingerprint: String.duplicate("a", 64),
        sanitized_query_excerpt: "billing export missing from knowledge base",
        canonical_hit_count: 0,
        assistive_hit_count: 2,
        clarification_attempts: 1
      }
    ])

    Process.put(:resolved_case_evidence, [
      %ResolvedCaseEvidence{
        id: 81,
        conversation_id: 123,
        subject: "Billing export gap",
        issue_summary: "Customers cannot find the export guidance.",
        resolution_note: "Agent walked through the export flow manually.",
        actions_taken: ["shared steps"],
        outcome: "resolved",
        resolved_at: ~U[2026-05-21 11:00:00Z]
      }
    ])

    Process.put(:retrieval_ground_for_draft, fn
      "billing export missing from knowledge base", request, _opts ->
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
          evidence: [valid_evidence_attrs()],
          grounding_assessment: %{status: :strong}
        }

      "Billing export", request, _opts ->
        %{
          query: request.query,
          canonical_results: [
            %{
              source_type: :knowledge_base,
              trust_level: :canonical,
              title: "Billing export",
              content: "Canonical chunk",
              citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
            }
          ],
          assistive_results: [],
          evidence: [valid_evidence_attrs()],
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

    {:ok, article_suggestion} =
      KnowledgeAutomation.suggest_article(valid_article_request(),
        retrieval_module: MockRetrieval,
        enqueue_fn: fn _job -> {:ok, %{id: "job-article"}} end,
        now_fn: fn -> ~U[2026-05-21 12:00:00Z] end
      )

    assert article_suggestion.status == :pending_generation
    assert article_suggestion.generated_at == nil
    assert article_suggestion.entrypoint_type == :gap_candidate

    Process.put(:gap_events, [
      %{
        occurred_at: ~U[2026-05-20 10:00:00Z],
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        clarification_attempts: 1,
        attempted_evidence_snapshots: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            citation_target: %{article_id: 77, revision_id: 44, chunk_index: 1}
          }
        ]
      },
      %{
        occurred_at: ~U[2026-06-21 10:00:00Z],
        outcome_class: :policy_limit,
        reason: :clarification_limit_reached,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
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

    Process.put(:knowledge_base_article_fn, fn 77 ->
      %Cairnloop.KnowledgeBase.Article{id: 77, title: "Billing export", status: :published}
    end)

    Process.put(:retrieval_ground_for_draft, fn
      "Billing export", request, _opts ->
        %{
          query: request.query,
          canonical_results: [
            %{
              source_type: :knowledge_base,
              trust_level: :canonical,
              title: "Billing export",
              content: "Canonical chunk",
              citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
            }
          ],
          assistive_results: [],
          evidence: [valid_evidence_attrs()],
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

    {:ok, revision_suggestion} =
      KnowledgeAutomation.suggest_revision(
        valid_revision_request(),
        latest_revision_fn: fn 77 -> %Revision{id: 44, article_id: 77, state: :published} end,
        knowledge_base_module: MockKnowledgeBase,
        retrieval_module: MockRetrieval,
        enqueue_fn: fn _job -> {:ok, %{id: "job-revision"}} end,
        now_fn: fn -> ~U[2026-05-21 13:00:00Z] end
      )

    assert revision_suggestion.status == :pending_generation
    assert revision_suggestion.article_id == 77
    assert revision_suggestion.base_revision_id == 44

    assert {:error, :missing_published_revision} =
             KnowledgeAutomation.suggest_revision(
               valid_revision_request(),
               latest_revision_fn: fn _article_id -> nil end
             )
  end

  test "suggest_article uses hydrated gap-candidate evidence instead of generic retrieval fallback" do
    Process.put(:gap_candidate_lookup, fn _query ->
      gap_candidate_fixture()
    end)

    Process.put(:gap_events, [
      %GapEvent{
        id: 12,
        occurred_at: ~U[2026-05-21 10:00:00Z],
        surface: :draft_generation,
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        query_fingerprint: String.duplicate("a", 64),
        sanitized_query_excerpt: "billing export missing from knowledge base",
        canonical_hit_count: 0,
        assistive_hit_count: 2,
        clarification_attempts: 1
      }
    ])

    Process.put(:resolved_case_evidence, [
      %ResolvedCaseEvidence{
        id: 81,
        conversation_id: 123,
        subject: "Billing export gap",
        issue_summary: "Customers cannot find the export guidance.",
        resolution_note: "Agent walked through the export flow manually.",
        actions_taken: ["shared steps"],
        outcome: "resolved",
        resolved_at: ~U[2026-05-21 11:00:00Z]
      }
    ])

    Process.put(:retrieval_ground_for_draft, fn
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
              title: "Billing export gap",
              content: "Agent walked through the export flow manually."
            }
          ],
          evidence: [valid_evidence_attrs()],
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

    assert {:ok, suggestion} =
             KnowledgeAutomation.suggest_article(
               %{
                 gap_candidate_id: 101,
                 entrypoint_id: 101,
                 tenant_scope: :host_user_scoped,
                 host_user_id: "user-1"
               },
               retrieval_module: MockRetrieval,
               enqueue_fn: fn _job -> {:ok, %{id: "job-gap-hydrated"}} end
             )

    assert Process.get(:last_retrieval_request).query ==
             "billing export missing from knowledge base"

    assert suggestion.status == :pending_generation
    assert suggestion.grounding_metadata["query"] == "billing export missing from knowledge base"
    assert suggestion.grounding_metadata["canonical_evidence_count"] == 1
    assert suggestion.grounding_metadata["assistive_evidence_count"] == 2
  end

  test "suggest_article fails closed when the hydrated gap candidate has no citation-ready canonical evidence" do
    Process.put(:gap_candidate_lookup, fn _query ->
      gap_candidate_fixture(%{
        id: 202,
        title: "Billing export fallback",
        memberships: [
          %GapCandidateMembership{source_type: :retrieval_gap_event, source_id: 91}
        ]
      })
    end)

    Process.put(:gap_events, [
      %GapEvent{
        id: 91,
        occurred_at: ~U[2026-05-21 10:00:00Z],
        surface: :draft_generation,
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        query_fingerprint: String.duplicate("b", 64),
        sanitized_query_excerpt: "",
        canonical_hit_count: 0,
        assistive_hit_count: 1,
        clarification_attempts: 1
      }
    ])

    Process.put(:resolved_case_evidence, [])

    Process.put(:retrieval_ground_for_draft, fn
      "Billing export fallback", request, _opts ->
        %{
          query: request.query,
          canonical_results: [],
          assistive_results: [],
          evidence: [],
          grounding_assessment: %{status: :weak}
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

    assert {:ok, suggestion} =
             KnowledgeAutomation.suggest_article(
               %{
                 gap_candidate_id: 202,
                 entrypoint_id: 202,
                 tenant_scope: :host_user_scoped,
                 host_user_id: "user-1"
               },
               retrieval_module: MockRetrieval
             )

    assert suggestion.status == :failed
    assert suggestion.grounding_metadata["query"] == "Billing export fallback"
    assert suggestion.grounding_metadata["failure_reason"] == "weak_grounding"
    refute Process.get(:last_retrieval_request).query == "Knowledge Base maintenance"
  end

  test "suggest_revision loads article-linked gap evidence and fresh canonical grounding on the shipped path" do
    Process.put(:latest_active_revision_fn, fn 77 ->
      %Revision{id: 44, article_id: 77, state: :published, version: 3}
    end)

    Process.put(:knowledge_base_article_fn, fn 77 ->
      %Cairnloop.KnowledgeBase.Article{id: 77, title: "Billing Export", status: :published}
    end)

    Process.put(:gap_events, [
      %GapEvent{
        id: 301,
        occurred_at: ~U[2026-06-21 10:00:00Z],
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
        occurred_at: ~U[2026-06-22 10:00:00Z],
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

    Process.put(:retrieval_ground_for_draft, fn
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
          evidence: [valid_evidence_attrs()],
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

    assert {:ok, suggestion} =
             KnowledgeAutomation.suggest_revision(
               %{
                 article_id: 77,
                 tenant_scope: :host_user_scoped,
                 host_user_id: "user-1"
               },
               knowledge_base_module: MockKnowledgeBase,
               retrieval_module: MockRetrieval,
               enqueue_fn: fn _job -> {:ok, %{id: "job-revision-domain"}} end
             )

    assert Process.get(:last_retrieval_request).query == "Billing Export"
    assert suggestion.base_revision_id == 44
    assert suggestion.grounding_metadata["canonical_evidence_count"] == 1
    assert suggestion.grounding_metadata["stale_signal"][:signal_count] == 2
  end

  test "conversation quick fix uses conversation-scoped identity and preserves typed package boundaries" do
    Process.put(:article_suggestions, [])

    attrs = %{
      conversation_id: 321,
      host_user_id: "user-1",
      tenant_scope: :host_user_scoped,
      title: "Weekend export fix",
      thread_context: %{
        conversation_id: 321,
        subject: "Weekend export fails",
        message_excerpt: "The export stalls every Saturday morning.",
        message_count: 4
      },
      canonical_retrieval: %{
        evidence: [valid_evidence_attrs()],
        citation_ready: true
      },
      resolved_case_assists: %{
        case_count: 1,
        summaries: ["Prior export timeout resolved by retry guidance."]
      }
    }

    {:ok, %{suggestion: suggestion, reused?: false, quick_fix: quick_fix}} =
      KnowledgeAutomation.create_or_reuse_conversation_quick_fix(attrs,
        enqueue_fn: fn _job -> {:ok, %{id: "job-quick-fix"}} end
      )

    assert suggestion.entrypoint_type == :conversation_quick_fix
    assert suggestion.entrypoint_id == 321
    assert suggestion.suggestion_type == :article
    assert suggestion.status == :pending_generation
    assert length(suggestion.evidence_snapshot) == 1
    assert hd(suggestion.evidence_snapshot).citation_target.revision_id == 11

    assert quick_fix["thread_context"]["conversation_id"] == 321
    assert quick_fix["canonical_retrieval"]["citation_ready"] == true

    assert quick_fix["resolved_case_assists"]["summaries"] == [
             "Prior export timeout resolved by retry guidance."
           ]

    assert suggestion.grounding_metadata["quick_fix_package"] == quick_fix

    {:ok, %{suggestion: reused_suggestion, reused?: true}} =
      KnowledgeAutomation.create_or_reuse_conversation_quick_fix(attrs,
        enqueue_fn: fn _job -> {:ok, %{id: "job-quick-fix"}} end
      )

    assert reused_suggestion.id == suggestion.id
  end

  test "conversation quick fix creates a reviewable shell when the maintenance need is real but canonical grounding is incomplete" do
    Process.put(:article_suggestions, [])

    attrs = %{
      conversation_id: 654,
      host_user_id: "user-1",
      tenant_scope: :host_user_scoped,
      title: "Missing weekend export article",
      thread_context: %{
        conversation_id: 654,
        subject: "Weekend export fails",
        message_excerpt: "Customers hit the same export gap every weekend.",
        message_count: 6
      },
      canonical_retrieval: %{
        evidence: [],
        citation_ready: false,
        failure_reason: :missing_canonical_grounding
      },
      resolved_case_assists: %{
        case_count: 2,
        summaries: ["Two recent threads needed the same workaround."]
      }
    }

    assert {:ok, %{suggestion: suggestion, reused?: false}} =
             KnowledgeAutomation.create_or_reuse_conversation_quick_fix(attrs)

    assert suggestion.entrypoint_type == :conversation_quick_fix
    assert suggestion.status == :ready
    assert suggestion.proposed_markdown =~ "Draft shell"
    assert suggestion.grounding_metadata["quick_fix_outcome"] == "shell_created"
    assert suggestion.grounding_metadata["quick_fix_reason"] == "missing_canonical_grounding"
    assert suggestion.grounding_metadata["failure_reason"] == "missing_canonical_grounding"
  end

  test "conversation quick fix persists blocked manual-required outcomes with bounded reasons" do
    Process.put(:article_suggestions, [])

    attrs = %{
      conversation_id: 655,
      host_user_id: "user-1",
      tenant_scope: :host_user_scoped,
      title: "Policy-blocked export fix",
      thread_context: %{
        conversation_id: 655,
        subject: "Refund policy export request",
        message_excerpt: "The operator wants to encode an unsupported refund promise.",
        message_count: 3
      },
      canonical_retrieval: %{
        evidence: [],
        citation_ready: false,
        failure_reason: :policy_guard_blocked
      },
      resolved_case_assists: %{
        case_count: 1,
        summaries: ["Prior thread required manual KB authoring."]
      }
    }

    assert {:ok, %{suggestion: suggestion, reused?: false}} =
             KnowledgeAutomation.create_or_reuse_conversation_quick_fix(attrs)

    assert suggestion.entrypoint_type == :conversation_quick_fix
    assert suggestion.status == :failed
    assert suggestion.grounding_metadata["quick_fix_outcome"] == "blocked_manual_required"
    assert suggestion.grounding_metadata["quick_fix_reason"] == "policy_guard_blocked"
    assert suggestion.grounding_metadata["failure_reason"] == "policy_guard_blocked"
    assert suggestion.operator_summary =~ "blocked"
  end

  test "conversation quick fix shell and blocked outcomes require a bounded quick-fix reason" do
    shell_missing_reason =
      %ArticleSuggestion{}
      |> ArticleSuggestion.changeset(
        valid_article_attrs(%{
          entrypoint_type: :conversation_quick_fix,
          entrypoint_id: 321,
          grounding_metadata: %{"quick_fix_outcome" => "shell_created"}
        })
      )

    blocked_missing_reason =
      %ArticleSuggestion{}
      |> ArticleSuggestion.changeset(
        valid_article_attrs(%{
          entrypoint_type: :conversation_quick_fix,
          entrypoint_id: 321,
          status: :failed,
          grounding_metadata: %{"quick_fix_outcome" => "blocked_manual_required"}
        })
      )

    refute shell_missing_reason.valid?
    refute blocked_missing_reason.valid?

    assert "must include a bounded quick-fix reason" in errors_on(shell_missing_reason).grounding_metadata

    assert "must include a bounded quick-fix reason" in errors_on(blocked_missing_reason).grounding_metadata
  end

  test "dismiss and regenerate seams update suggestion-safe status without review or publish semantics" do
    suggestion =
      suggestion_fixture(%{
        id: 12,
        status: :ready,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1"
      })

    Process.put(:article_suggestion_detail_lookup, fn _query -> suggestion end)

    {:ok, dismissed} =
      KnowledgeAutomation.dismiss_article_suggestion(
        12,
        host_user_id: "user-1",
        now_fn: fn -> ~U[2026-05-21 14:00:00Z] end
      )

    assert dismissed.status == :dismissed
    assert DateTime.compare(dismissed.dismissed_at, ~U[2026-05-21 14:00:00Z]) == :eq

    Process.put(:article_suggestion_detail_lookup, fn _query -> dismissed end)

    {:ok, regenerated} =
      KnowledgeAutomation.regenerate_article_suggestion(
        12,
        host_user_id: "user-1",
        enqueue_fn: fn _job -> {:ok, %{id: "job-1"}} end,
        now_fn: fn -> ~U[2026-05-21 15:00:00Z] end
      )

    assert regenerated.status == :pending_generation
    assert regenerated.dismissed_at == nil
  end

  test "suggest_revision rejects age-only requests and requires repeated article-linked failures plus fresh canonical evidence" do
    gap_events = [
      %{
        occurred_at: ~U[2026-06-20 10:00:00Z],
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        clarification_attempts: 1,
        attempted_evidence_snapshots: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            citation_target: %{article_id: 77, revision_id: 44, chunk_index: 1}
          }
        ]
      },
      %{
        occurred_at: ~U[2026-06-21 10:00:00Z],
        outcome_class: :policy_limit,
        reason: :clarification_limit_reached,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        clarification_attempts: 1,
        attempted_evidence_snapshots: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            citation_target: %{article_id: 77, revision_id: 44, chunk_index: 2}
          }
        ]
      }
    ]

    Process.put(:gap_events, [])

    Process.put(:knowledge_base_article_fn, fn 77 ->
      %Cairnloop.KnowledgeBase.Article{id: 77, title: "Billing export", status: :published}
    end)

    Process.put(:retrieval_ground_for_draft, fn _query, request, _opts ->
      %{
        query: request.query,
        canonical_results: [],
        assistive_results: [],
        evidence: [],
        grounding_assessment: %{status: :strong}
      }
    end)

    assert {:error, {:stale_gate_blocked, %StaleArticleSignal{reason: :insufficient_signals}}} =
             KnowledgeAutomation.suggest_revision(
               valid_revision_request(),
               latest_revision_fn: fn 77 ->
                 %Revision{id: 44, article_id: 77, state: :published}
               end,
               knowledge_base_module: MockKnowledgeBase,
               retrieval_module: MockRetrieval
             )

    Process.put(:gap_events, gap_events)

    Process.put(:retrieval_ground_for_draft, fn _query, request, _opts ->
      %{
        query: request.query,
        canonical_results: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            title: "Billing export",
            content: "Canonical chunk",
            citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
          }
        ],
        assistive_results: [],
        evidence: [valid_evidence_attrs()],
        grounding_assessment: %{status: :strong}
      }
    end)

    {:ok, suggestion} =
      KnowledgeAutomation.suggest_revision(
        valid_revision_request(),
        latest_revision_fn: fn 77 -> %Revision{id: 44, article_id: 77, state: :published} end,
        knowledge_base_module: MockKnowledgeBase,
        retrieval_module: MockRetrieval,
        enqueue_fn: fn _job -> {:ok, %{id: "job-stale"}} end
      )

    assert suggestion.status == :pending_generation
    assert suggestion.base_revision_id == 44
  end

  test "stale signal only counts article-linked canonical anchors and ignores title-only matches" do
    signal =
      StaleArticleSignal.build_revision_gate(
        77,
        44,
        gap_events: [
          %{
            occurred_at: ~U[2026-05-20 10:00:00Z],
            outcome_class: :weak_grounding,
            reason: :canonical_insufficient_detail,
            attempted_evidence_snapshots: [
              %{
                source_type: :knowledge_base,
                trust_level: :canonical,
                title: "Billing export",
                citation_target: %{article_id: 77, revision_id: 44, chunk_index: 1}
              },
              %{
                source_type: :knowledge_base,
                trust_level: :canonical,
                title: "Billing export",
                citation_target: %{}
              }
            ]
          }
        ],
        grounding_bundle: %{
          canonical_results: [
            %{citation_target: %{article_id: 77, revision_id: 44, chunk_index: 1}}
          ]
        },
        now_fn: fn -> ~U[2026-05-22 10:00:00Z] end
      )

    assert signal.signal_count == 1
    refute signal.ready?
  end

  test "create_or_reuse_authoring_article_for_suggestion creates an article target once and then reuses it" do
    suggestion = suggestion_fixture(%{id: 41, suggestion_type: :article, article_id: nil})

    Process.put(:article_suggestion_detail_lookup, fn
      _query ->
        Process.get(:authoring_target_suggestion, suggestion)
    end)

    Process.put(:knowledge_base_article_fn, fn _id -> nil end)

    {:ok, article_id} =
      KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(
        41,
        knowledge_base_module: MockKnowledgeBase
      )

    assert is_integer(article_id)

    updated = Process.get(:last_updated_suggestion)
    Process.put(:authoring_target_suggestion, updated)

    Process.put(:knowledge_base_article_fn, fn ^article_id ->
      %Cairnloop.KnowledgeBase.Article{id: article_id, status: :draft}
    end)

    assert {:ok, ^article_id} =
             KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(
               41,
               knowledge_base_module: MockKnowledgeBase
             )

    assert updated.grounding_metadata["authoring_article_id"] == article_id
  end

  test "create_or_reuse_authoring_article_for_suggestion replaces published authoring targets" do
    suggestion =
      suggestion_fixture(%{
        id: 42,
        suggestion_type: :article,
        article_id: nil,
        grounding_metadata: %{"authoring_article_id" => 91, "status" => "strong"}
      })

    Process.put(:article_suggestion_detail_lookup, fn _query ->
      Process.get(:authoring_target_suggestion, suggestion)
    end)

    Process.put(:authoring_target_suggestion, suggestion)

    Process.put(:knowledge_base_article_fn, fn 91 ->
      %Cairnloop.KnowledgeBase.Article{id: 91, status: :published}
    end)

    {:ok, replacement_id} =
      KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(
        42,
        knowledge_base_module: MockKnowledgeBase
      )

    assert replacement_id != 91
    assert Process.get(:created_article_attrs).status == :draft

    assert Process.get(:last_updated_suggestion).grounding_metadata["authoring_article_id"] ==
             replacement_id
  end

  defp valid_article_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        stable_key: "gap:tenant:user-1:101",
        suggestion_type: :article,
        status: :pending_generation,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        entrypoint_type: :gap_candidate,
        entrypoint_id: 101,
        title: "Billing export guide",
        operator_summary: "Grounded from repeated gap evidence.",
        proposed_markdown: "# Billing export\n\nUse the export endpoint.",
        evidence_snapshot: [valid_evidence_attrs()],
        grounding_metadata: %{"status" => "strong"},
        evidence_digest: "digest-1"
      },
      overrides
    )
  end

  defp valid_revision_attrs(overrides) do
    Map.merge(
      %{
        stable_key: "article:77:revision",
        suggestion_type: :revision,
        status: :pending_generation,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        entrypoint_type: :article_revision,
        entrypoint_id: 77,
        article_id: 77,
        base_revision_id: 33,
        title: "Billing export guide",
        change_summary: "Clarify export date handling.",
        operator_summary: "Recent failures indicate the article is stale.",
        proposed_markdown: "# Billing export\n\nClarified date handling.",
        evidence_snapshot: [valid_evidence_attrs()],
        grounding_metadata: %{"status" => "strong"},
        evidence_digest: "digest-2"
      },
      overrides
    )
  end

  defp valid_article_request do
    %{
      gap_candidate_id: 101,
      entrypoint_id: 101,
      tenant_scope: :host_user_scoped,
      host_user_id: "user-1"
    }
  end

  defp valid_revision_request do
    %{
      article_id: 77,
      tenant_scope: :host_user_scoped,
      host_user_id: "user-1"
    }
  end

  defp valid_evidence_attrs do
    %{
      source_type: :knowledge_base,
      trust_level: :canonical,
      title: "Billing export reference",
      excerpt: "Use the export endpoint with a date range.",
      citation_target: %{article_id: 7, revision_id: 11, chunk_index: 2},
      metadata: %{destination: %{article_id: 7, revision_id: 11}},
      match_reasons: ["matched export settings"]
    }
  end

  defp suggestion_fixture(overrides) do
    base =
      valid_article_attrs()
      |> Map.merge(%{
        id: 1,
        status: :ready,
        inserted_at: ~U[2026-05-21 10:00:00Z],
        updated_at: ~U[2026-05-21 10:00:00Z],
        evidence_snapshot: [struct(ArticleSuggestionEvidence, valid_evidence_attrs())]
      })

    struct(ArticleSuggestion, Map.merge(base, overrides))
  end

  defp gap_candidate_fixture(overrides \\ %{}) do
    base = %GapCandidate{
      id: 101,
      stable_key: "gap:tenant:user-1:101",
      status: :open,
      candidate_type: :mixed,
      title: "Billing export guide",
      seed_excerpt: "Billing export missing from knowledge base",
      tenant_scope: :host_user_scoped,
      host_user_id: "user-1",
      ui_surface: :conversation,
      first_seen_at: ~U[2026-05-20 09:00:00Z],
      last_seen_at: ~U[2026-05-21 10:00:00Z],
      evidence_count: 2,
      manual_case_count: 1,
      weak_grounding_count: 1,
      no_hit_count: 0,
      score: 4.5,
      score_components: %{"weak_grounding" => 1.4},
      memberships: [
        %GapCandidateMembership{source_type: :retrieval_gap_event, source_id: 12},
        %GapCandidateMembership{source_type: :manual_handling_case, source_id: 81}
      ]
    }

    struct(base, overrides)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
