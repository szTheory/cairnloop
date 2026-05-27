defmodule Cairnloop.Telemetry do
  @moduledoc """
  Centralizes telemetry event execution and documentation for Cairnloop.

  Cairnloop emits telemetry events for all major operations. You can attach to these
  events to capture metrics, logs, and traces.

  ## Conversation Events

  The following events are emitted using `:telemetry.span/3`:

  * `[:cairnloop, :conversation, :resolve, :start]`
  * `[:cairnloop, :conversation, :resolve, :stop]` - Metadata includes `:business_duration_seconds`
  * `[:cairnloop, :conversation, :resolve, :exception]`

  * `[:cairnloop, :conversation, :reply, :start]`
  * `[:cairnloop, :conversation, :reply, :stop]`
  * `[:cairnloop, :conversation, :reply, :exception]`

  ## Feedback Events

  * `[:cairnloop, :feedback, :csat, :start]`
  * `[:cairnloop, :feedback, :csat, :stop]` - Metadata includes `:rating`
  * `[:cairnloop, :feedback, :csat, :exception]`

  ## Retrieval Events

  * `[:cairnloop, :retrieval, :search]`
  * `[:cairnloop, :retrieval, :draft_grounding]`

  Retrieval metadata is bounded to low-cardinality fields such as `:surface`,
  `:source_mix`, `:result_bucket`, `:grounding_status`, `:diagnostic_class`,
  `:reason`, `:canonical_hit_count`, `:assistive_hit_count`, and `:ranking_outcome`.

  ## Knowledge-Maintenance Events

  * `[:cairnloop, :knowledge_automation, :gap_candidate]`
  * `[:cairnloop, :knowledge_automation, :suggestion_outcome]`
  * `[:cairnloop, :knowledge_automation, :review_decision]`
  * `[:cairnloop, :knowledge_automation, :publish_outcome]`
  * `[:cairnloop, :knowledge_automation, :reindex_outcome]`

  Knowledge-maintenance metadata is bounded to coarse workflow fields such as
  `:surface`, `:entrypoint_type`, `:outcome`, `:reason`, `:publish_status`,
  `:reindex_status`, `:canonical_evidence_count`, and `:assistive_evidence_count`.

  ## Outbound Events

  The outbound lane emits TWO disjoint vocabularies — bounded-metrics events on
  the `[:cairnloop, :outbound, ...]` namespace (low-cardinality, cardinality- and
  PII-safe — attach Prometheus / StatsD / Datadog here) AND OpenInference-conformant
  trace events on the disjoint `[:cairnloop, :outbound, :trace, ...]` namespace
  (sampled span-tree observability with attribution refs — attach Scoria /
  Phoenix.Tracer / OpenTelemetry exporters here).

  Bounded-metrics events (D-B / Phase 26 D-01 — enum-only labels):

  * `[:cairnloop, :outbound, :triggered, :start | :stop | :exception]` — single-recipient
    trigger lifecycle via `:telemetry.span/3`. Metadata: `:outcome` only.
  * `[:cairnloop, :outbound, :bulk, :triggered, :start | :stop | :exception]` —
    bulk-fan-out submit lifecycle via `:telemetry.span/3`. Metadata: `:outcome` and `:count`.
  * `[:cairnloop, :outbound, :bulk, :triggered]` — point-in-time refusal event from
    the cap-exceedance lane (`bulk_trigger_refused/6`). Metadata: `:outcome`
    (`:refused_cap_exceeded` | `:refused_cap_exceeded_audit_failed`) and `:count`.
  * `[:cairnloop, :outbound, :delivery, :sent | :failed]` — point-in-time delivery
    outcome from `Cairnloop.Workers.OutboundWorker.perform/1` (Phase 26 D-02).
    Metadata: `:outcome` (`:sent | :failed`) and `:reason` (`:notifier_ok |
    :notifier_returned_error | :no_notifier_configured`).

  OI trace lane events (Phase 26 D-03 — emitted by
  `Cairnloop.Outbound.Telemetry.Traces`):

  * `[:cairnloop, :outbound, :trace, :trigger_started]` — GUARDRAIL span around
    `Outbound.trigger/2` start.
  * `[:cairnloop, :outbound, :trace, :trigger_completed]` — GUARDRAIL span after
    the sealed `:telemetry.span/3` returns `{:ok, _}`.
  * `[:cairnloop, :outbound, :trace, :trigger_failed]` — GUARDRAIL span after the
    sealed span returns `{:error, _}`; also fires from the rescue path with
    `outcome: :exception` before reraising.
  * `[:cairnloop, :outbound, :trace, :bulk_submitted]` — GUARDRAIL span inside
    `bulk_trigger_submit/6`'s sealed span after `repo().transaction/1`.
  * `[:cairnloop, :outbound, :trace, :bulk_refused]` — GUARDRAIL span on all three
    arms of `bulk_trigger_refused/6`'s `case repo().insert(...)` block; carries
    `:effective_cap` (the cap-of-the-moment).
  * `[:cairnloop, :outbound, :trace, :delivery_sent | :delivery_failed]` — TOOL
    spans (delivery IS the execution of an outbound) from `OutboundWorker.perform/1`'s
    four delivery arms.

  Cardinality note: outbound bounded-metrics metadata is enum-only (`:outcome`,
  `:count`, optional `:reason`) per Phase 25 D-B / Phase 26 D-01. Attribution refs
  (`:bulk_envelope_id`, `:conversation_id`, `:template_id`, `:actor_id`) live in
  the OI trace lane (sampled span-tree observability) and in the durable
  `BulkEnvelope` / `Message` rows + host auditor metadata — never in the
  bounded-metrics aggregator labels.
  """

  @doc """
  Executes a telemetry span around the given function.
  """
  def span(event_suffix, metadata, fun) when is_list(event_suffix) do
    :telemetry.span([:cairnloop | event_suffix], metadata, fun)
  end

  @doc """
  Executes a point-in-time telemetry event.
  """
  def execute(event_suffix, measurements, metadata) when is_list(event_suffix) do
    :telemetry.execute([:cairnloop | event_suffix], measurements, metadata)
  end
end
