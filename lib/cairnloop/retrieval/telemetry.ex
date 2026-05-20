defmodule Cairnloop.Retrieval.Telemetry do
  @moduledoc """
  Stable Cairnloop-native telemetry helpers for retrieval search and draft grounding.

  Metadata is intentionally bounded and low-cardinality so it can be safely projected
  into host-owned metrics without leaking raw query text, result identifiers, or
  citation payloads.
  """

  alias Cairnloop.Retrieval.Ranker
  alias Cairnloop.Telemetry

  @search_event [:retrieval, :search]
  @draft_grounding_event [:retrieval, :draft_grounding]
  @allowed_surfaces [:draft_generation, :search_modal, :api, :unspecified]
  @allowed_grounding_statuses [:strong, :clarification, :escalation, :not_applicable]
  @allowed_diagnostic_classes [
    :grounded,
    :search_results,
    :weak_grounding,
    :empty_recall,
    :retrieval_error,
    :policy_limit
  ]
  @allowed_reasons [
    :canonical_results,
    :mixed_results,
    :assistive_only_results,
    :no_canonical_results,
    :canonical_insufficient_detail,
    :clarification_limit_reached,
    :provider_timeout,
    :index_unavailable,
    :unexpected_error
  ]

  def search_event_name, do: [:cairnloop | @search_event]
  def draft_grounding_event_name, do: [:cairnloop | @draft_grounding_event]

  def emit_search(measurements, metadata) do
    Telemetry.execute(
      @search_event,
      normalize_measurements(measurements),
      normalize_metadata(metadata)
    )
  end

  def emit_draft_grounding(measurements, metadata) do
    Telemetry.execute(
      @draft_grounding_event,
      normalize_measurements(measurements),
      normalize_metadata(metadata)
    )
  end

  def search_metadata(results, opts \\ []) when is_list(results) do
    summary = Ranker.summarize(results)

    %{
      surface: surface(opts),
      source_mix: summary.source_mix,
      result_bucket: summary.result_bucket,
      grounding_status: :not_applicable,
      diagnostic_class: search_diagnostic_class(summary),
      reason: search_reason(summary),
      canonical_hit_count: summary.canonical_hit_count,
      assistive_hit_count: summary.assistive_hit_count,
      ranking_outcome: summary.ranking_outcome
    }
  end

  def grounding_metadata(%{} = bundle, opts \\ []) do
    diagnostic = Map.fetch!(bundle, :diagnostic)
    assessment = Map.fetch!(bundle, :grounding_assessment)
    ranking_summary = Map.fetch!(bundle, :ranking_summary)

    %{
      surface: surface(opts),
      source_mix: ranking_summary.source_mix,
      result_bucket: ranking_summary.result_bucket,
      grounding_status: assessment.status,
      diagnostic_class: diagnostic.class,
      reason: diagnostic.reason,
      canonical_hit_count: diagnostic.canonical_hit_count,
      assistive_hit_count: diagnostic.assistive_hit_count,
      ranking_outcome: ranking_summary.ranking_outcome
    }
  end

  def error_metadata(opts, diagnostic_class, reason) do
    %{
      surface: surface(opts),
      source_mix: :none,
      result_bucket: :empty,
      grounding_status: :not_applicable,
      diagnostic_class: normalize_diagnostic_class(diagnostic_class),
      reason: normalize_reason(reason),
      canonical_hit_count: 0,
      assistive_hit_count: 0,
      ranking_outcome: :empty
    }
  end

  def surface(opts) when is_list(opts) do
    opts
    |> Keyword.get(:surface, :unspecified)
    |> normalize_surface()
  end

  def normalize_diagnostic_class(class) when class in @allowed_diagnostic_classes, do: class
  def normalize_diagnostic_class(_), do: :retrieval_error

  def normalize_reason(reason) when reason in @allowed_reasons, do: reason
  def normalize_reason(_), do: :unexpected_error

  def classify_exception(%{} = error) do
    message =
      error
      |> Exception.message()
      |> String.downcase()

    cond do
      String.contains?(message, "timeout") -> :provider_timeout
      String.contains?(message, "index unavailable") -> :index_unavailable
      String.contains?(message, "index_unavailable") -> :index_unavailable
      true -> :unexpected_error
    end
  end

  def classify_exception(_), do: :unexpected_error

  defp normalize_measurements(measurements) do
    %{
      duration_ms: measurements[:duration_ms] || 0,
      count: measurements[:count] || 1
    }
  end

  defp normalize_metadata(metadata) do
    %{
      surface: normalize_surface(metadata[:surface]),
      source_mix: metadata[:source_mix] || :none,
      result_bucket: metadata[:result_bucket] || :empty,
      grounding_status: normalize_grounding_status(metadata[:grounding_status]),
      diagnostic_class: normalize_diagnostic_class(metadata[:diagnostic_class]),
      reason: normalize_reason(metadata[:reason]),
      canonical_hit_count: metadata[:canonical_hit_count] || 0,
      assistive_hit_count: metadata[:assistive_hit_count] || 0,
      ranking_outcome: metadata[:ranking_outcome] || :empty
    }
  end

  defp normalize_surface(surface) when surface in @allowed_surfaces, do: surface
  defp normalize_surface(_), do: :unspecified

  defp normalize_grounding_status(status) when status in @allowed_grounding_statuses, do: status
  defp normalize_grounding_status(_), do: :not_applicable

  defp search_diagnostic_class(%{canonical_hit_count: count}) when count > 0, do: :search_results
  defp search_diagnostic_class(%{assistive_hit_count: count}) when count > 0, do: :weak_grounding
  defp search_diagnostic_class(_), do: :empty_recall

  defp search_reason(%{canonical_hit_count: count, assistive_hit_count: assistive})
       when count > 0 and assistive > 0,
       do: :mixed_results

  defp search_reason(%{canonical_hit_count: count}) when count > 0, do: :canonical_results
  defp search_reason(%{assistive_hit_count: count}) when count > 0, do: :assistive_only_results
  defp search_reason(_), do: :no_canonical_results
end
