defmodule Cairnloop.KnowledgeAutomation.ArticleSuggestionTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, ArticleSuggestionEvidence, StaleArticleSignal}
  alias Cairnloop.KnowledgeBase.Revision

  defmodule MockRepo do
    def all(%Ecto.Query{} = query) do
      Process.put(:last_all_query, query)

      Process.get(:article_suggestions, [])
      |> filter_scope(query)
      |> Enum.sort_by(
        fn suggestion ->
          {suggestion.inserted_at || ~U[1970-01-01 00:00:00Z], suggestion.id || 0}
        end,
        :desc
      )
    end

    def one!(%Ecto.Query{} = query) do
      Process.put(:last_one_query, query)
      Process.get(:article_suggestion_detail_lookup).(query)
    end

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

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

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
        :last_updated_suggestion
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

    assert content =~ "create table(:cairnloop_article_suggestions)"
    assert content =~ "unique_index(:cairnloop_article_suggestions, [:stable_key])"
    assert content =~ "index(:cairnloop_article_suggestions, [:status])"
    assert content =~ "index(:cairnloop_article_suggestions, [:entrypoint_type, :entrypoint_id])"
    assert content =~ "index(:cairnloop_article_suggestions, [:evidence_digest])"
    assert content =~ "index(:cairnloop_article_suggestions, [:base_revision_id])"
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
    {:ok, article_suggestion} =
      KnowledgeAutomation.suggest_article(valid_article_attrs(),
        enqueue_fn: fn _job -> {:ok, %{id: "job-article"}} end,
        now_fn: fn -> ~U[2026-05-21 12:00:00Z] end
      )

    assert article_suggestion.status == :pending_generation
    assert article_suggestion.generated_at == nil
    assert article_suggestion.entrypoint_type == :gap_candidate

    revision_gap_events = [
      %{
        occurred_at: ~U[2026-05-20 10:00:00Z],
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
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
        occurred_at: ~U[2026-05-21 10:00:00Z],
        outcome_class: :policy_limit,
        reason: :clarification_limit_reached,
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

    revision_grounding_bundle = %{
      canonical_results: [
        %{
          source_type: :knowledge_base,
          trust_level: :canonical,
          title: "Billing export",
          content: "Canonical chunk",
          citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
        }
      ],
      evidence: [valid_evidence_attrs()],
      grounding_assessment: %{status: :strong}
    }

    {:ok, revision_suggestion} =
      KnowledgeAutomation.suggest_revision(
        valid_revision_attrs(%{base_revision_id: 999}),
        latest_revision_fn: fn 77 -> %Revision{id: 44, article_id: 77, state: :published} end,
        gap_events: revision_gap_events,
        grounding_bundle: revision_grounding_bundle,
        enqueue_fn: fn _job -> {:ok, %{id: "job-revision"}} end,
        now_fn: fn -> ~U[2026-05-21 13:00:00Z] end
      )

    assert revision_suggestion.status == :pending_generation
    assert revision_suggestion.article_id == 77
    assert revision_suggestion.base_revision_id == 44

    assert {:error, :missing_published_revision} =
             KnowledgeAutomation.suggest_revision(
               valid_revision_attrs(),
               latest_revision_fn: fn _article_id -> nil end
             )
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
        occurred_at: ~U[2026-05-20 10:00:00Z],
        outcome_class: :weak_grounding,
        reason: :canonical_insufficient_detail,
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
        occurred_at: ~U[2026-05-21 10:00:00Z],
        outcome_class: :policy_limit,
        reason: :clarification_limit_reached,
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

    age_only_grounding_bundle = %{
      canonical_results: [],
      evidence: [],
      grounding_assessment: %{status: :strong}
    }

    assert {:error, {:stale_gate_blocked, %StaleArticleSignal{reason: :insufficient_signals}}} =
             KnowledgeAutomation.suggest_revision(
               valid_revision_attrs(),
               latest_revision_fn: fn 77 -> %Revision{id: 44, article_id: 77, state: :published} end,
               gap_events: [],
               grounding_bundle: age_only_grounding_bundle
             )

    grounding_bundle = %{
      canonical_results: [
        %{
          source_type: :knowledge_base,
          trust_level: :canonical,
          title: "Billing export",
          content: "Canonical chunk",
          citation_target: %{article_id: 77, revision_id: 44, chunk_index: 3}
        }
      ],
      evidence: [valid_evidence_attrs()],
      grounding_assessment: %{status: :strong}
    }

    {:ok, suggestion} =
      KnowledgeAutomation.suggest_revision(
        valid_revision_attrs(),
        latest_revision_fn: fn 77 -> %Revision{id: 44, article_id: 77, state: :published} end,
        gap_events: gap_events,
        grounding_bundle: grounding_bundle,
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
        grounding_bundle: %{canonical_results: [%{citation_target: %{article_id: 77, revision_id: 44, chunk_index: 1}}]},
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

    {:ok, article_id} = KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(41)
    assert is_integer(article_id)

    updated = Process.get(:last_updated_suggestion)
    Process.put(:authoring_target_suggestion, updated)

    assert {:ok, ^article_id} =
             KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(41)

    assert updated.grounding_metadata["authoring_article_id"] == article_id
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

  defp valid_revision_attrs(overrides \\ %{}) do
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

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
