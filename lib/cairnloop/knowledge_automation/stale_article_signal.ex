defmodule Cairnloop.KnowledgeAutomation.StaleArticleSignal do
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestionEvidence

  defstruct ready?: false,
            reason: :insufficient_signals,
            signal_count: 0,
            fresh_canonical_snapshot?: false,
            matching_events: []

  @window_days 30
  @minimum_signals 2
  @eligible_reasons [:canonical_insufficient_detail, :clarification_limit_reached]
  @eligible_outcomes [:weak_grounding, :policy_limit]

  def build_revision_gate(article_id, base_revision_id, opts \\ []) do
    now = Keyword.get(opts, :now_fn, &DateTime.utc_now/0).()
    gap_events = Keyword.get(opts, :gap_events, [])
    grounding_bundle = Keyword.get(opts, :grounding_bundle, %{})

    matching_events =
      gap_events
      |> List.wrap()
      |> Enum.filter(&recent_enough?(&1, now))
      |> Enum.filter(&eligible_failure_signal?/1)
      |> Enum.filter(&article_linked?(&1, article_id, base_revision_id))

    fresh_canonical_snapshot? =
      grounding_bundle
      |> canonical_results()
      |> Enum.any?(&article_linked_result?(&1, article_id, base_revision_id))

    signal_count = length(matching_events)

    {ready?, reason} =
      cond do
        signal_count < @minimum_signals -> {false, :insufficient_signals}
        not fresh_canonical_snapshot? -> {false, :missing_fresh_canonical_snapshot}
        true -> {true, :ready}
      end

    %__MODULE__{
      ready?: ready?,
      reason: reason,
      signal_count: signal_count,
      fresh_canonical_snapshot?: fresh_canonical_snapshot?,
      matching_events: matching_events
    }
  end

  defp recent_enough?(event, now) do
    occurred_at = map_value(event, :occurred_at)

    case occurred_at do
      %DateTime{} = value ->
        DateTime.diff(now, value, :day) <= @window_days

      %NaiveDateTime{} = value ->
        DateTime.diff(now, DateTime.from_naive!(value, "Etc/UTC"), :day) <= @window_days

      _ ->
        false
    end
  end

  defp eligible_failure_signal?(event) do
    reason = map_value(event, :reason)
    outcome_class = map_value(event, :outcome_class)
    clarification_attempts = map_value(event, :clarification_attempts) || 0

    outcome_class in @eligible_outcomes or reason in @eligible_reasons or
      clarification_attempts > 0
  end

  defp article_linked?(event, article_id, base_revision_id) do
    event
    |> map_value(:attempted_evidence_snapshots)
    |> List.wrap()
    |> Enum.any?(fn snapshot ->
      canonical_anchor_snapshot?(snapshot) and
        article_linked_result?(snapshot, article_id, base_revision_id)
    end)
  end

  defp canonical_results(nil), do: []

  defp canonical_results(bundle) do
    Map.get(bundle, :canonical_results) || Map.get(bundle, "canonical_results") || []
  end

  defp article_linked_result?(result, article_id, base_revision_id) do
    citation_target =
      map_value(result, :citation_target) ||
        %{
          article_id: map_value(result, :article_id),
          revision_id: map_value(result, :revision_id)
        }

    map_value(citation_target, :article_id) == article_id and
      map_value(citation_target, :revision_id) == base_revision_id
  end

  defp canonical_anchor_snapshot?(%ArticleSuggestionEvidence{} = evidence) do
    evidence.source_type == :knowledge_base and evidence.trust_level == :canonical and
      article_linked_result?(
        evidence,
        map_value(evidence.citation_target, :article_id),
        map_value(evidence.citation_target, :revision_id)
      )
  end

  defp canonical_anchor_snapshot?(snapshot) do
    source_type = map_value(snapshot, :source_type)
    trust_level = map_value(snapshot, :trust_level)
    citation_target = map_value(snapshot, :citation_target)

    source_type in [:knowledge_base, "knowledge_base"] and
      trust_level in [:canonical, "canonical"] and is_map(citation_target) and
      not is_nil(map_value(citation_target, :article_id)) and
      not is_nil(map_value(citation_target, :revision_id))
  end

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_value(_, _), do: nil
end
