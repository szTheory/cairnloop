defmodule Cairnloop.Outbound.Telemetry.Traces do
  @moduledoc """
  Optional OpenInference-conformant trace event module for the Cairnloop outbound lane
  (Phase 26, D-03).

  Mirrors `Cairnloop.Governance.Telemetry.Traces` (Phase 17, D17-01 / D17-03) — same
  architectural posture, swapped namespace + event vocabulary + attribution refs.

  ## Namespace separation (D-03)

  This module is SEPARATE from the bounded-metrics outbound paths emitted via
  `Cairnloop.Telemetry.span/3` + `.execute/3`. It emits to a disjoint 4-segment event
  namespace:

      [:cairnloop, :outbound, :trace, <event_atom>]

  The bounded-metrics outbound paths live at:

      [:cairnloop, :outbound, :triggered, :start | :stop | :exception]
      [:cairnloop, :outbound, :bulk, :triggered, :start | :stop | :exception]
      [:cairnloop, :outbound, :bulk, :triggered]
      [:cairnloop, :outbound, :delivery, :sent | :failed]

  No handler attached to any bounded-metrics path will receive trace events, and vice
  versa. The two namespaces are disjoint by the `:trace` segment in position 3. This
  isolation is proven in `Cairnloop.Outbound.Telemetry.TracesTest`.

  ## Purpose

  Hosts (and OI-aware consumers like Scoria, Phoenix.Tracer, OpenTelemetry exporters)
  can attach to `[:cairnloop, :outbound, :trace, ...]` to reconstruct an outbound-lane
  span tree (trigger lifecycle, bulk submit/refused, per-recipient delivery) without
  duplicating durable record content.

  Trace events are emitted **alongside** existing bounded-metrics events — they are
  observability only, never workflow truth (CLAUDE.md "telemetry is observability only").

  ## Zero Scoria dependency

  This module calls `:telemetry.execute/3` directly. It imports no Scoria-owned
  modules and does not route through `Cairnloop.Telemetry` (the bounded-metrics
  centralizer). If no handler is attached, the event is silently dropped by the
  `:telemetry` library — fail-closed.

  ## OI span kinds (D-03 — execution-events-are-TOOL)

  Trace events carry `"openinference.span.kind"` (string key per OI spec) in metadata:

  - Execution events (`:delivery_sent`, `:delivery_failed`): `"TOOL"`
  - All other outbound lifecycle events (trigger lifecycle, bulk lanes): `"GUARDRAIL"`

  Delivery IS the execution of an outbound message; lifecycle events (trigger started,
  trigger completed, bulk submitted, bulk refused, etc.) are guardrails around it.

  ## Payload content exclusion (D-03 / mirrors D17-02)

  Metadata carries only attribution references (IDs, atom enums). No rendered body,
  no message content, no refused-reason free-text ever crosses the telemetry boundary
  through this module.

  Metadata SHAPE (always present):

  - `"openinference.span.kind"` — string key per OI spec
  - `:bulk_envelope_id` — attribution ref (UUID string) or `nil`
  - `:conversation_id` — attribution ref (integer) or `nil` (bulk-envelope-scoped events)
  - `:template_id` — attribution ref (string)
  - `:actor_id` — attribution ref (string) or `nil` (system-initiated events)
  - `:outcome` — atom enum

  Metadata SHAPE (`:bulk_refused` only, per RESEARCH OQ3):

  - `:effective_cap` — integer (the cap-of-the-moment) for OI consumers correlating
    refusals against policy changes. Low cardinality, useful attribution detail.

  ## Fail-closed guard clause

  Unknown event atoms (anything not in `@events`) return `:ok` silently — `emit/2`
  does not call `:telemetry.execute/3`. The caller is never penalised for passing
  an atom not in the whitelist.
  """

  @events [
    :trigger_started,
    :trigger_completed,
    :trigger_failed,
    :bulk_submitted,
    :bulk_refused,
    :delivery_sent,
    :delivery_failed
  ]

  # OI span kind string constants (string keys per OpenInference spec).
  @span_kind_tool "TOOL"
  @span_kind_guardrail "GUARDRAIL"

  @doc """
  Emits an OI-conformant trace telemetry event for the outbound lane.

  Only accepts events in `@events` (the 7-atom whitelist enumerated in the moduledoc).
  Unknown events are silently dropped (fail-closed guard clause).

  Event path: `[:cairnloop, :outbound, :trace, event]` — 4 segments with `:trace` in
  position 3, disjoint from the bounded-metrics outbound paths (D-03).

  Measurements are always `%{count: 1}` — callers do not supply measurements.

  Metadata is built by `build_metadata/2`: attribution refs only, no payload content.
  """
  def emit(event, attrs) when event in @events do
    :telemetry.execute(
      [:cairnloop, :outbound, :trace, event],
      %{count: 1},
      build_metadata(event, attrs)
    )
  end

  # Guard-clause no-op: unknown events are silently dropped (D-03 fail-closed).
  def emit(_event, _attrs), do: :ok

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # build_metadata/2 — OI-conformant metadata shape.
  #
  # Always contains the attribution-ref shape. For `:bulk_refused` events, also
  # includes `:effective_cap` per RESEARCH OQ3 (cap-of-the-moment is a useful
  # low-cardinality attribution detail for OI consumers).
  #
  # Specifically excluded under all events: :content, :rendered_body, :refused_reason.
  defp build_metadata(event, attrs) do
    base = %{
      "openinference.span.kind" => span_kind_for(event),
      bulk_envelope_id: attrs[:bulk_envelope_id],
      conversation_id: attrs[:conversation_id],
      template_id: attrs[:template_id],
      actor_id: attrs[:actor_id],
      outcome: attrs[:outcome]
    }

    case event do
      :bulk_refused -> Map.put(base, :effective_cap, attrs[:effective_cap])
      _ -> base
    end
  end

  # span_kind_for/1 — maps event atom to OI span kind string.
  # Delivery events are TOOL spans (the actual execution of an outbound); all other
  # outbound lifecycle events are GUARDRAIL spans.
  defp span_kind_for(event)
       when event in [:delivery_sent, :delivery_failed],
       do: @span_kind_tool

  defp span_kind_for(_event), do: @span_kind_guardrail
end
