defmodule Cairnloop.KnowledgeAutomation.Telemetry do
  @moduledoc """
  Stable telemetry helpers for knowledge-maintenance workflow events.

  Metadata is bounded to low-cardinality workflow enums and small counts so telemetry
  remains safe for observability and never becomes the durable workflow record.
  """

  alias Cairnloop.Telemetry

  @events [:gap_candidate, :suggestion_outcome, :review_decision, :publish_outcome, :reindex_outcome]
  @allowed_surfaces [:conversation_thread, :review_lane, :worker, :api, :unspecified]
  @allowed_entrypoint_types [:gap_candidate, :article_revision, :conversation_quick_fix, :manual, :unspecified]
  @allowed_outcomes [
    :created,
    :reused,
    :queued,
    :ready,
    :failed,
    :shell_created,
    :blocked_manual_required,
    :approved,
    :rejected,
    :deferred,
    :review_needed,
    :published,
    :running,
    :publish_blocked,
    :completed
  ]
  @allowed_reasons [
    :unspecified,
    :ready_to_publish,
    :rejected,
    :deferred,
    :needs_manual_edit,
    :draft_conflict,
    :freshness_invalidated,
    :missing_canonical_grounding,
    :canonical_snapshot_unavailable,
    :citation_anchors_unavailable,
    :policy_guard_blocked,
    :weak_grounding,
    :missing_canonical_citations,
    :generation_failed,
    :no_hit,
    :weak_grounding_gap,
    :manual_handling,
    :mixed
  ]
  @allowed_publish_statuses [:not_started, :queued, :published, :failed, :not_applicable]
  @allowed_reindex_statuses [:not_started, :queued, :running, :completed, :failed, :not_applicable]

  def event_name(event) when event in @events, do: [:cairnloop, :knowledge_automation, event]

  def emit(event, measurements, metadata) when event in @events do
    Telemetry.execute(
      [:knowledge_automation, event],
      normalize_measurements(measurements),
      metadata(event, metadata)
    )
  end

  def metadata(_event, metadata) when is_map(metadata) do
    %{
      surface: normalize_surface(Map.get(metadata, :surface)),
      entrypoint_type: normalize_entrypoint_type(Map.get(metadata, :entrypoint_type)),
      outcome: normalize_outcome(Map.get(metadata, :outcome)),
      reason: normalize_reason(Map.get(metadata, :reason)),
      publish_status: normalize_publish_status(Map.get(metadata, :publish_status)),
      reindex_status: normalize_reindex_status(Map.get(metadata, :reindex_status)),
      canonical_evidence_count: normalize_count(Map.get(metadata, :canonical_evidence_count)),
      assistive_evidence_count: normalize_count(Map.get(metadata, :assistive_evidence_count))
    }
  end

  def metadata(event, metadata) when is_list(metadata), do: metadata(event, Map.new(metadata))
  def metadata(_event, _metadata), do: metadata(nil, %{})

  defp normalize_measurements(measurements) do
    %{
      duration_ms: measurements[:duration_ms] || 0,
      count: measurements[:count] || 1
    }
  end

  defp normalize_surface(value) when value in @allowed_surfaces, do: value
  defp normalize_surface(_), do: :unspecified

  defp normalize_entrypoint_type(value) when value in @allowed_entrypoint_types, do: value
  defp normalize_entrypoint_type(_), do: :unspecified

  defp normalize_outcome(value) when value in @allowed_outcomes, do: value
  defp normalize_outcome(_), do: :failed

  defp normalize_reason(value) when value in @allowed_reasons, do: value
  defp normalize_reason(_), do: :unspecified

  defp normalize_publish_status(value) when value in @allowed_publish_statuses, do: value
  defp normalize_publish_status(_), do: :not_applicable

  defp normalize_reindex_status(value) when value in @allowed_reindex_statuses, do: value
  defp normalize_reindex_status(_), do: :not_applicable

  defp normalize_count(value) when is_integer(value) and value >= 0, do: min(value, 99)
  defp normalize_count(_), do: 0
end
