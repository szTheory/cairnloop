defmodule Cairnloop.Retrieval.Ranker do
  alias Cairnloop.Retrieval.Result

  @rrf_k 60.0
  @kb_source_boost 0.015
  @resolved_case_source_boost 0.0

  def merge(knowledge_base_results, resolved_case_results, _opts \\ []) do
    (knowledge_base_results ++ resolved_case_results)
    |> Enum.map(&normalize_result/1)
    |> Enum.sort_by(&sort_key/1, :desc)
  end

  def summarize(results) when is_list(results) do
    canonical_hit_count =
      Enum.count(results, &(&1.source_type in [:knowledge_base, "knowledge_base"]))

    assistive_hit_count =
      Enum.count(results, &(&1.source_type in [:resolved_case, "resolved_case"]))

    groundable_count = Enum.count(results, &(&1.can_ground_reply? != false))

    %{
      canonical_hit_count: canonical_hit_count,
      assistive_hit_count: assistive_hit_count,
      result_bucket: result_bucket(length(results)),
      source_mix: source_mix(canonical_hit_count, assistive_hit_count),
      ranking_outcome:
        ranking_outcome(
          List.first(results),
          canonical_hit_count,
          assistive_hit_count,
          groundable_count
        )
    }
  end

  defp normalize_result(%Result{} = result) do
    score = fused_score(result)

    %Result{
      result
      | score: score,
        can_ground_reply?: result.can_ground_reply? != false,
        match_reasons: build_match_reasons(result)
    }
  end

  defp normalize_result(result) when is_map(result) do
    result
    |> struct(Result)
    |> normalize_result()
  end

  defp fused_score(result) do
    source_boost(result.source_type) +
      reciprocal_rank(result.keyword_rank) +
      reciprocal_rank(result.semantic_rank)
  end

  defp reciprocal_rank(nil), do: 0.0
  defp reciprocal_rank(rank), do: 1.0 / (@rrf_k + rank)

  defp source_boost(:knowledge_base), do: @kb_source_boost
  defp source_boost("knowledge_base"), do: @kb_source_boost
  defp source_boost(:resolved_case), do: @resolved_case_source_boost
  defp source_boost("resolved_case"), do: @resolved_case_source_boost
  defp source_boost(_), do: 0.0

  defp build_match_reasons(result) do
    []
    |> maybe_add_reason(not is_nil(result.keyword_rank), :keyword_match)
    |> maybe_add_reason(not is_nil(result.semantic_rank), :semantic_match)
    |> maybe_add_reason(
      result.source_type in [:knowledge_base, "knowledge_base"],
      :kb_source_boost
    )
    |> maybe_add_reason(
      result.source_type in [:resolved_case, "resolved_case"],
      :resolved_case_similarity
    )
  end

  defp maybe_add_reason(reasons, true, reason), do: reasons ++ [reason]
  defp maybe_add_reason(reasons, false, _reason), do: reasons

  defp sort_key(result) do
    {
      result.score || 0.0,
      source_priority(result.source_type),
      keyword_priority(result.keyword_rank),
      semantic_priority(result.semantic_rank),
      result.title || "",
      inspect(result.citation_target)
    }
  end

  defp result_bucket(0), do: :empty
  defp result_bucket(1), do: :single
  defp result_bucket(count) when count <= 3, do: :few
  defp result_bucket(_count), do: :many

  defp source_mix(0, 0), do: :none
  defp source_mix(canonical, 0) when canonical > 0, do: :canonical_only
  defp source_mix(0, assistive) when assistive > 0, do: :assistive_only
  defp source_mix(_canonical, _assistive), do: :mixed

  defp ranking_outcome(nil, _canonical, _assistive, _groundable), do: :empty

  defp ranking_outcome(first, canonical, assistive, groundable) do
    cond do
      canonical > 0 and assistive > 0 and first.source_type in [:knowledge_base, "knowledge_base"] ->
        :canonical_first

      canonical > 0 and assistive > 0 ->
        :assistive_first

      canonical > 0 and groundable > 0 ->
        :groundable_canonical_only

      canonical > 0 ->
        :canonical_only

      assistive > 0 ->
        :assistive_only

      true ->
        :empty
    end
  end

  defp source_priority(:knowledge_base), do: 1
  defp source_priority("knowledge_base"), do: 1
  defp source_priority(_), do: 0

  defp keyword_priority(nil), do: 0
  defp keyword_priority(rank), do: -rank

  defp semantic_priority(nil), do: 0
  defp semantic_priority(rank), do: -rank
end
