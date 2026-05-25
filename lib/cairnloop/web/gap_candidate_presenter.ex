defmodule Cairnloop.Web.GapCandidatePresenter do
  @reason_labels %{
    no_hit: "No hit",
    weak_grounding: "Weak grounding",
    manual_handling: "Manual handling",
    mixed: "Mixed evidence"
  }

  @surface_labels %{
    conversation: "Conversation",
    inbox: "Inbox",
    settings: "Settings",
    unspecified: "Unspecified surface"
  }

  @event_reason_labels %{
    no_canonical_results: "No canonical results",
    assistive_only_results: "Assistive-only results",
    canonical_insufficient_detail: "Canonical detail was too weak",
    provider_timeout: "Provider timeout",
    index_unavailable: "Index unavailable",
    unexpected_error: "Unexpected error"
  }

  def reason_label(candidate_or_reason) when is_atom(candidate_or_reason) do
    Map.get(@reason_labels, candidate_or_reason, "Gap candidate")
  end

  def reason_label(%{candidate_type: candidate_type}), do: reason_label(candidate_type)

  def freshness_label(%{last_seen_at: %DateTime{} = last_seen_at}) do
    case max(DateTime.diff(DateTime.utc_now(), last_seen_at, :day), 0) do
      0 -> "Seen today"
      1 -> "Seen yesterday"
      days -> "Seen #{days} days ago"
    end
  end

  def dominant_source_label(%{
        manual_case_count: manual_case_count,
        weak_grounding_count: weak_grounding_count,
        no_hit_count: no_hit_count
      }) do
    cond do
      manual_case_count > max(weak_grounding_count, no_hit_count) ->
        "Dominant source: similar resolved cases"

      weak_grounding_count >= no_hit_count and weak_grounding_count > 0 ->
        "Dominant source: weak grounding"

      no_hit_count > 0 ->
        "Dominant source: retrieval no-hits"

      true ->
        "Dominant source: mixed evidence"
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

  def event_reason_label(reason), do: Map.get(@event_reason_labels, reason, humanize_atom(reason))
  def surface_label(surface), do: Map.get(@surface_labels, surface, humanize_atom(surface))

  def conversation_target(%{conversation_id: id}) when not is_nil(id), do: "/#{id}"
  def conversation_target(_evidence), do: nil

  defp count_phrase(0, _label), do: nil
  defp count_phrase(1, label), do: "1 #{label}"
  defp count_phrase(count, label), do: "#{count} #{label}s"

  defp component_phrase(_label, nil), do: nil
  defp component_phrase(_label, value) when value <= 0, do: nil
  defp component_phrase(label, value), do: "#{label} #{Float.round(value, 1)}"

  defp humanize_atom(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
