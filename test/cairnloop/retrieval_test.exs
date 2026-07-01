defmodule Cairnloop.RetrievalTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Retrieval
  alias Cairnloop.Retrieval.Providers
  alias Cairnloop.Retrieval.Result

  defmodule KnowledgeBaseProviderMock do
    def search("billing export", _opts) do
      [
        %Result{
          id: 1,
          title: "Billing export policy",
          content: "Canonical article on billing exports",
          source_type: :knowledge_base,
          trust_level: :canonical,
          visibility: :host,
          citation_target: %{revision_id: 10, chunk_index: 0},
          keyword_rank: 1,
          semantic_rank: 2
        }
      ]
    end
  end

  defmodule ResolvedCasesProviderMock do
    def search("billing export", _opts) do
      [
        %Result{
          id: 2,
          title: "Resolved billing export case",
          content: "Assistive case with a similar failure mode",
          source_type: :resolved_case,
          trust_level: :assistive,
          visibility: :host,
          citation_target: %{conversation_id: 20, chunk_index: 0},
          keyword_rank: 1,
          semantic_rank: 1,
          can_ground_reply?: false
        }
      ]
    end
  end

  defmodule WeakKnowledgeBaseProviderMock do
    def search("billing export", _opts) do
      [
        %Result{
          id: 3,
          title: "Billing export troubleshooting",
          content:
            "Canonical guidance exists but the customer-specific failure detail is missing.",
          source_type: :knowledge_base,
          trust_level: :canonical,
          visibility: :host,
          citation_target: %{revision_id: 11, chunk_index: 0},
          keyword_rank: 1,
          semantic_rank: 1,
          can_ground_reply?: false
        }
      ]
    end
  end

  defmodule AssistiveOnlyProviderMock do
    def search("billing export", _opts), do: []
  end

  defmodule EmptyProviderMock do
    def search("billing export", _opts), do: []
  end

  defmodule TimeoutProviderMock do
    def search(_query, _opts),
      do: raise(RuntimeError, "provider timeout while retrieving results")
  end

  defmodule RankerMock do
    def merge(_knowledge_base_results, _resolved_case_results, _opts) do
      send(self(), :ranker_merge_called)
      []
    end
  end

  defmodule PrefixRepoMock do
    def all(%Ecto.Query{} = query) do
      send(self(), {:repo_all_query, query})
      []
    end
  end

  defp use_repo(repo) do
    original = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, repo)

    on_exit(fn ->
      if original do
        Application.put_env(:cairnloop, :repo, original)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)
  end

  defp join_source_prefixes(%Ecto.Query{} = query) do
    Enum.map(query.joins, fn
      %{source: %Ecto.Query{prefix: prefix}} -> prefix
      %{prefix: prefix} -> prefix
    end)
  end

  test "search/2 normalizes result labeling and prefers knowledge-base truth" do
    results =
      Retrieval.search("billing export",
        providers: %{
          knowledge_base: KnowledgeBaseProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert [%Result{} = first, %Result{} = second] = results
    assert first.source_type == :knowledge_base
    assert first.trust_level == :canonical
    assert first.can_ground_reply? == true
    assert :keyword_match in first.match_reasons
    assert :semantic_match in first.match_reasons
    assert :kb_source_boost in first.match_reasons

    assert second.source_type == :resolved_case
    assert second.trust_level == :assistive
    assert second.can_ground_reply? == false
    assert :resolved_case_similarity in second.match_reasons
  end

  test "ranker ordering stays deterministic for mixed-source ties" do
    [first, second] =
      Retrieval.search("billing export",
        providers: %{
          knowledge_base: KnowledgeBaseProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert first.score > second.score
    assert first.citation_target == %{revision_id: 10, chunk_index: 0}
    assert second.citation_target == %{conversation_id: 20, chunk_index: 0}
  end

  test "ground_for_draft/2 returns strong canonical grounding when Knowledge Base evidence can answer safely" do
    grounding =
      Retrieval.ground_for_draft("billing export",
        providers: %{
          knowledge_base: KnowledgeBaseProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert grounding.grounding_assessment.status == :strong
    assert grounding.grounding_assessment.reason == :canonical_results
    assert grounding.grounding_assessment.diagnostic_class == :grounded

    assert grounding.diagnostic == %{
             class: :grounded,
             reason: :canonical_results,
             canonical_hit_count: 1,
             assistive_hit_count: 1
           }

    assert grounding.ranking_summary.source_mix == :mixed
    assert [%{source_type: :knowledge_base, trust_level: :canonical} | _] = grounding.evidence
    assert Enum.any?(grounding.evidence, &(&1.match_reasons != []))
  end

  test "ground_for_draft/2 escalates after the clarification limit is reached" do
    grounding =
      Retrieval.ground_for_draft(
        %{query: "billing export", clarification_attempts: 1},
        providers: %{
          knowledge_base: WeakKnowledgeBaseProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert grounding.grounding_assessment.status == :escalation
    assert grounding.grounding_assessment.reason == :clarification_limit_reached
    assert grounding.grounding_assessment.diagnostic_class == :policy_limit
    assert grounding.clarification_attempts == 1
  end

  test "ground_for_draft/2 keeps clarification as the coarse state while exposing weak grounding diagnostics" do
    grounding =
      Retrieval.ground_for_draft(
        %{query: "billing export", clarification_attempts: 0},
        providers: %{
          knowledge_base: WeakKnowledgeBaseProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert grounding.grounding_assessment.status == :clarification
    assert grounding.grounding_assessment.reason == :canonical_insufficient_detail
    assert grounding.grounding_assessment.diagnostic_class == :weak_grounding
    assert grounding.diagnostic.reason == :canonical_insufficient_detail
  end

  test "ground_for_draft/2 distinguishes assistive-only results from empty recall" do
    assistive_only =
      Retrieval.ground_for_draft("billing export",
        providers: %{
          knowledge_base: AssistiveOnlyProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    empty_recall =
      Retrieval.ground_for_draft("billing export",
        providers: %{
          knowledge_base: EmptyProviderMock,
          resolved_cases: EmptyProviderMock
        }
      )

    assert assistive_only.grounding_assessment.status == :escalation
    assert assistive_only.grounding_assessment.reason == :assistive_only_results
    assert assistive_only.grounding_assessment.diagnostic_class == :weak_grounding
    assert assistive_only.diagnostic.assistive_hit_count == 1

    assert empty_recall.grounding_assessment.status == :escalation
    assert empty_recall.grounding_assessment.reason == :no_canonical_results
    assert empty_recall.grounding_assessment.diagnostic_class == :empty_recall

    assert empty_recall.diagnostic == %{
             class: :empty_recall,
             reason: :no_canonical_results,
             canonical_hit_count: 0,
             assistive_hit_count: 0
           }
  end

  test "ground_for_draft/2 classifies retrieval exceptions before the rescue fallback" do
    grounding =
      Retrieval.ground_for_draft("billing export",
        providers: %{
          knowledge_base: TimeoutProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert grounding.grounding_assessment.status == :escalation
    assert grounding.grounding_assessment.reason == :provider_timeout
    assert grounding.grounding_assessment.diagnostic_class == :retrieval_error
    assert grounding.diagnostic.reason == :provider_timeout
  end

  test "search/2 rejects unscoped dashboard search before provider ranking" do
    assert {:error, :scope_unavailable} =
             Retrieval.search("billing export",
               surface: :search_modal,
               host_surface: "inbox",
               host_user_id: nil,
               providers: %{
                 knowledge_base: KnowledgeBaseProviderMock,
                 resolved_cases: ResolvedCasesProviderMock
               },
               ranker: RankerMock
             )

    refute_received :ranker_merge_called
  end

  test "knowledge-base provider queries use the configured support prefix" do
    use_repo(PrefixRepoMock)

    assert [] = Providers.KnowledgeBase.keyword_candidates("billing export", 2)
    assert_received {:repo_all_query, query}
    assert query.prefix == "cairnloop"
    assert join_source_prefixes(query) == ["cairnloop", "cairnloop"]
  end

  test "resolved-case provider queries use the configured support prefix" do
    use_repo(PrefixRepoMock)

    assert [] =
             Providers.ResolvedCases.keyword_candidates("billing export", 2,
               host_user_id: "operator_1"
             )

    assert_received {:repo_all_query, query}
    assert query.prefix == "cairnloop"
    assert join_source_prefixes(query) == ["cairnloop"]
  end

  test "system health qualifies support tables while keeping Oban host-owned" do
    source = File.read!("lib/cairnloop/retrieval.ex")

    assert source =~ ~s|SchemaPrefix.quoted_table("cairnloop_chunks")|
    assert source =~ "FROM oban_jobs"
    assert source =~ "from(job in Oban.Job"
    refute source =~ ~s|SchemaPrefix.quoted_table("oban_jobs")|
    refute source =~ "prefixed(Oban.Job)"
  end
end
